import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ChatViewModel {
    let project: Project
    private var llmService: any LLMServiceProtocol
    private var extractor: any StructuredExtractorProtocol
    private let analyzer = ProgressAnalyzer()
    @ObservationIgnored private nonisolated(unsafe) var fallbackObserver: NSObjectProtocol?
    @ObservationIgnored private nonisolated(unsafe) var configurationObserver: NSObjectProtocol?

    var currentStreamingText: String = ""
    var isStreaming: Bool = false
    var errorMessage: String?

    init(project: Project,
         llmService: any LLMServiceProtocol,
         extractor: any StructuredExtractorProtocol) {
        self.project = project
        self.llmService = llmService
        self.extractor = extractor
        observeServiceFallbacks()
    }

    deinit {
        if let fallbackObserver {
            NotificationCenter.default.removeObserver(fallbackObserver)
        }
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
    }

    func updateServices(
        llmService: any LLMServiceProtocol,
        extractor: any StructuredExtractorProtocol
    ) {
        self.llmService = llmService
        self.extractor = extractor
    }

    func refreshStageProgress() {
        guard let brief = project.brief else { return }
        updateStageProgress(brief: brief.toSnapshot())
        try? project.modelContext?.save()
    }

    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let context = project.modelContext else { return }

        // ① 保存用户消息
        let userMsg = ChatMessage(role: "user", content: text)
        context.insert(userMsg)
        project.messages.append(userMsg)
        project.updatedAt = Date()
        let clarificationMode = ClarificationMode.detect(from: text)

        // ② 快照当前状态（用于后续 diff）
        let previousBrief = project.brief?.toSnapshot() ?? DesignBriefSnapshot()

        // ③ 记录用户回答对应的过程片段
        let activeStage = currentActiveStage()
        let activeStageOrder = activeStage?.order ?? project.currentStageOrder

        if shouldRecordFormalAnswer(text: text, mode: clarificationMode) {
            recordThinkingMoment(
                momType: "answer",
                content: truncatedMomentText(text),
                stageOrder: activeStageOrder,
                relatedField: nil,
                parentMomentID: parentForNewMoment(stageOrder: activeStageOrder, momType: "answer"),
                context: context
            )
        }
        try? context.save()

        // ④ 先抽取并更新状态，再生成下一问。
        // 这样 Agent 问出的不是“更多细节”，而是当前 DesignBrief 中最值得推进的设计判断。
        let rawExtractionMessages = project.messages
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.toPayload() }
        let extractionMessages = messagesWithTrustedImportContext(
            rawExtractionMessages,
            existing: previousBrief
        )

        await applyStructuredExtraction(
            messages: extractionMessages,
            existing: previousBrief,
            context: context
        )

        let updatedBriefSnapshot = project.brief?.toSnapshot() ?? DesignBriefSnapshot()
        recordBriefDecisionMoments(
            previous: previousBrief,
            current: updatedBriefSnapshot,
            context: context
        )
        updateStageProgress(brief: updatedBriefSnapshot)

        let nextActiveStage = currentActiveStage()
        appendLearningTraces(
            previousBrief: previousBrief,
            currentBrief: updatedBriefSnapshot,
            activeStageOrder: nextActiveStage?.order ?? activeStageOrder,
            context: context
        )
        try? context.save()

        // ⑤ 基于更新后的状态流式调用 LLM
        let payloadMessages = project.messages
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.toPayload() }
        let stageSnapshot = nextActiveStage?.toSnapshot()
        let selectedResourceCards = ResourceRecommendationService().recommend(
            currentStageOrder: stageSnapshot?.order ?? nextActiveStage?.order ?? activeStageOrder,
            briefSnapshot: updatedBriefSnapshot,
            recentMessage: text,
            limit: clarificationMode == .stuckScaffold ? 2 : 5,
            mode: clarificationMode
        )
        let selectedMethodCard = selectedResourceCards.first

        isStreaming = true
        currentStreamingText = ""
        errorMessage = nil

        do {
            let stream = llmService.streamChat(
                messages: payloadMessages,
                briefSnapshot: updatedBriefSnapshot,
                currentStage: stageSnapshot,
                mode: clarificationMode,
                resourceCards: selectedResourceCards
            )
            for try await token in stream {
                currentStreamingText += token
            }
        } catch {
            // v0.1: 简单错误提示
            errorMessage = "回复生成失败，请重试"
            isStreaming = false
            return
        }

        // ⑥ 保存 AI 回复
        let assistantMsg = ChatMessage(role: "assistant", content: currentStreamingText)
        context.insert(assistantMsg)
        project.messages.append(assistantMsg)
        if let selectedMethodCard {
            recordMethodInvocation(
                card: selectedMethodCard,
                generatedQuestion: assistantMsg.content,
                stageOrder: nextActiveStage?.order ?? activeStageOrder,
                mode: clarificationMode,
                context: context
            )
            appendMethodLearningTrace(
                card: selectedMethodCard,
                stageOrder: nextActiveStage?.order ?? activeStageOrder,
                context: context
            )
        }
        if shouldRecordFormalQuestion(mode: clarificationMode, assistantText: assistantMsg.content) {
            let questionStageOrder = nextActiveStage?.order ?? activeStageOrder
            recordThinkingMoment(
                momType: "question",
                content: questionMomentText(from: assistantMsg.content),
                stageOrder: questionStageOrder,
                relatedField: nil,
                parentMomentID: parentForNewMoment(stageOrder: questionStageOrder, momType: "question"),
                context: context
            )
        }
        currentStreamingText = ""
        isStreaming = false

        // ⑦ 保存
        try? context.save()
    }

    private func observeServiceFallbacks() {
        fallbackObserver = NotificationCenter.default.addObserver(
            forName: LLMRuntimeNotification.serviceFallback,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let service = notification.userInfo?[LLMRuntimeNotification.serviceKey] as? String ?? "Live API"
            let message = notification.userInfo?[LLMRuntimeNotification.messageKey] as? String ?? "未知错误"
            Task { @MainActor [weak self] in
                self?.errorMessage = "\(service)失败，已临时使用本地内置追问：\(message)"
            }
        }

        configurationObserver = NotificationCenter.default.addObserver(
            forName: LLMRuntimeNotification.configurationChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.errorMessage = nil
            }
        }
    }

    // MARK: - Conversation State Updates

    private func applyStructuredExtraction(
        messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot,
        context: ModelContext
    ) async {
        do {
            let outcome = try await extractor.extract(
                from: messages,
                existing: existing
            )
            if let brief = project.brief {
                brief.applyValidatedExtraction(outcome: outcome, context: context)
            }
        } catch {
            if let brief = project.brief {
                let outcome = ExtractionOutcome.failed(
                    source: .live,
                    message: "Structured extraction threw an error: \(error)",
                    attemptCount: 1
                )
                brief.applyValidatedExtraction(outcome: outcome, context: context)
            }
        }
    }

    private func messagesWithTrustedImportContext(
        _ messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot
    ) -> [ChatPayloadMessage] {
        guard messages.count <= 3,
              let importSummary = trustedImportSummary(from: existing)
        else {
            return messages
        }

        return [.user(importSummary)] + messages
    }

    private func trustedImportSummary(from brief: DesignBriefSnapshot) -> String? {
        var lines: [String] = []

        appendBriefLine("目标用户", brief.targetUser, to: &lines)
        appendBriefLine("核心痛点", brief.painPoint, to: &lines)
        appendBriefLine("使用场景", brief.useScenario, to: &lines)
        appendBriefLine("核心价值", brief.coreValue, to: &lines)
        appendBriefLine("差异化价值", brief.differentiation, to: &lines)
        appendBriefLine("MVP 功能", brief.mvpFeatures, to: &lines)
        appendBriefLine("技术模块", brief.technicalModules, to: &lines)
        appendBriefLine("交互流程", brief.interactionFlow, to: &lines)
        appendBriefLine("运行逻辑", brief.operationLogic, to: &lines)
        appendBriefLine("硬性约束", brief.hardConstraints, to: &lines)
        appendBriefLine("里程碑", brief.milestones, to: &lines)

        for item in brief.boundaryItems {
            appendBriefLine(item.isIncluded ? "做的边界" : "不做的边界", item.content, to: &lines)
        }
        for metric in brief.successMetrics {
            appendBriefLine("验收指标", "\(metric.metric)：\(metric.target)", to: &lines)
            appendBriefLine("指标测量方式", metric.measurement, to: &lines)
        }
        for risk in brief.risks {
            appendBriefLine("风险", risk.desc, to: &lines)
            appendBriefLine("风险缓解", risk.mitigation, to: &lines)
        }

        guard !lines.isEmpty else { return nil }
        return """
        【导入的 .codesign 项目包摘要，仅用于延续结构化抽取证据】
        \(lines.joined(separator: "\n"))
        """
    }

    private func appendBriefLine(_ title: String, _ value: String?, to lines: inout [String]) {
        guard let value else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lines.append("- \(title)：\(trimmed)")
    }

    private func recordBriefDecisionMoments(
        previous: DesignBriefSnapshot,
        current: DesignBriefSnapshot,
        context: ModelContext
    ) {
        for field in BriefField.allCases {
            let wasEmpty = !field.isFilled(in: previous)
            let isNowFilled = field.isFilled(in: current)
            let changedMeaningfully = fieldFingerprint(field, in: previous) != fieldFingerprint(field, in: current)
            if isNowFilled && (wasEmpty || changedMeaningfully) {
                let stageOrder = StageDefinition.all
                    .first { $0.briefFields.contains(field) }?.order ?? 1
                recordThinkingMoment(
                    momType: "decision",
                    content: "确认：\(field.displayName)",
                    stageOrder: stageOrder,
                    relatedField: field.rawValue,
                    parentMomentID: parentForNewMoment(stageOrder: stageOrder, momType: "decision"),
                    context: context
                )
            }
        }
    }

    private func updateStageProgress(brief currentBriefSnapshot: DesignBriefSnapshot) {
        let sortedStages = project.stages.sorted { $0.order < $1.order }
        let stageSnapshots = sortedStages.map { $0.toSnapshot() }
        let updatedStages = analyzer.analyze(
            brief: currentBriefSnapshot,
            stages: stageSnapshots
        )
        for (i, updated) in updatedStages.enumerated() {
            if i < sortedStages.count {
                let stage = sortedStages[i]
                stage.status = updated.status.rawValue
                stage.completionRatio = updated.completionRatio
                stage.lastUpdated = Date()
            }
        }
    }

    private func appendLearningTraces(
        previousBrief: DesignBriefSnapshot,
        currentBrief: DesignBriefSnapshot,
        activeStageOrder: Int,
        context: ModelContext
    ) {
        let traces = analyzer.detectLearningTraces(
            previousBrief: previousBrief,
            currentBrief: currentBrief,
            activeStageOrder: activeStageOrder
        )
        for traceDTO in traces {
            let isDuplicate = project.learningTraces.contains { trace in
                trace.stageOrder == traceDTO.stageOrder &&
                trace.actionType == traceDTO.actionType &&
                trace.title == traceDTO.title
            }
            guard !isDuplicate else { continue }

            let trace = LearningTrace(
                stageOrder: traceDTO.stageOrder,
                actionType: traceDTO.actionType,
                title: traceDTO.title,
                detail: traceDTO.detail
            )
            context.insert(trace)
            project.learningTraces.append(trace)
        }
    }

    private func currentActiveStage() -> ProgressStage? {
        let sortedStages = project.stages.sorted { $0.order < $1.order }
        return sortedStages.first { $0.stageStatusValue == .needsReview }
            ?? sortedStages.first { $0.stageStatusValue == .active }
            ?? sortedStages.first { $0.stageStatusValue == .notStarted }
    }

    private func shouldRecordFormalAnswer(text: String, mode: ClarificationMode) -> Bool {
        guard mode == .normal else { return false }
        return !ThinkingTreeMomentProjector.isStuckAnswer(text)
    }

    private func shouldRecordFormalQuestion(mode: ClarificationMode, assistantText: String) -> Bool {
        guard mode != .stuckScaffold else { return false }
        let question = questionMomentText(from: assistantText)
        return !ThinkingTreeMomentProjector.isScaffoldQuestion(question)
    }

    private func parentForNewMoment(stageOrder: Int, momType: String) -> UUID? {
        switch momType {
        case "answer", "decision", "deepen", "method", "evidence":
            return lastActiveQuestionMoment(stageOrder: stageOrder)?.id
        default:
            return nil
        }
    }

    private func lastActiveQuestionMoment(stageOrder: Int) -> ThinkingMoment? {
        project.thinkingMoments
            .filter {
                $0.stageOrder == stageOrder &&
                $0.momType == "question" &&
                $0.isActiveBranch &&
                ThinkingTreeMomentProjector.isVisibleInTree($0)
            }
            .sorted { $0.timestamp < $1.timestamp }
            .last
    }

    // MARK: - Thinking Moment Recording

    @discardableResult
    private func recordThinkingMoment(
        momType: String,
        content: String,
        stageOrder: Int,
        relatedField: String?,
        parentMomentID: UUID? = nil,
        context: ModelContext
    ) -> ThinkingMoment? {
        let normalized = truncatedMomentText(content)
        guard !normalized.isEmpty else { return nil }

        let now = Date()
        let isDuplicate = project.thinkingMoments.contains { moment in
            moment.momType == momType &&
            moment.content == normalized &&
            moment.stageOrder == stageOrder &&
            moment.relatedField == relatedField &&
            abs(moment.timestamp.timeIntervalSince(now)) < 4
        }
        guard !isDuplicate else { return nil }

        let moment = ThinkingMoment(
            momType: momType,
            content: normalized,
            stageOrder: stageOrder,
            relatedField: relatedField,
            parentMomentID: parentMomentID,
            timestamp: now,
            isActiveBranch: true
        )
        context.insert(moment)
        project.thinkingMoments.append(moment)
        return moment
    }

    private func recordMethodInvocation(
        card: ResourceCard,
        generatedQuestion: String,
        stageOrder: Int,
        mode: ClarificationMode,
        context: ModelContext
    ) {
        let fields = card.relatedFields.map(\.displayName).joined(separator: "、")
        let question = questionMomentText(from: generatedQuestion)
        let triggerReason = mode == .stuckScaffold
            ? "用户不确定 / 当前字段缺失 / 当前阶段卡住"
            : card.promptTriggerProblem
        let scaffoldRole = mode == .stuckScaffold
            ? "帮助用户从 \(card.processActionText) 角度重新理解当前问题"
            : card.processActionText
        let content = [
            "调用依据：\(card.title)",
            "触发原因：\(triggerReason)",
            "依据作用：\(scaffoldRole)",
            "生成问题：\(question)",
            fields.isEmpty ? nil : "期望字段：\(fields)",
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        let isDuplicate = project.thinkingMoments.contains { moment in
            moment.momType == "method" &&
            moment.stageOrder == stageOrder &&
            moment.content.contains(card.title) &&
            abs(moment.timestamp.timeIntervalSince(Date())) < 8
        }
        guard !isDuplicate else { return }

        let moment = ThinkingMoment(
            momType: "method",
            content: content,
            stageOrder: stageOrder,
            relatedField: card.relatedFields.first?.rawValue,
            parentMomentID: parentForNewMoment(stageOrder: stageOrder, momType: "method"),
            timestamp: Date(),
            isActiveBranch: true
        )
        context.insert(moment)
        project.thinkingMoments.append(moment)
    }

    private func appendMethodLearningTrace(
        card: ResourceCard,
        stageOrder: Int,
        context: ModelContext
    ) {
        let isDuplicate = project.learningTraces.contains { trace in
            trace.stageOrder == stageOrder &&
            trace.actionType == "methodCard" &&
            trace.title.contains(card.title)
        }
        guard !isDuplicate else { return }

        let trace = LearningTrace(
            stageOrder: stageOrder,
            actionType: "methodCard",
            title: "使用 \(card.title)",
            detail: "本轮 Agent 使用「\(card.title)」作为本轮设计依据：\(card.userDisplayText) 这帮助你完成「\(card.processActionText)」。"
        )
        context.insert(trace)
        project.learningTraces.append(trace)
    }

    private func truncatedMomentText(_ text: String, limit: Int = 60) -> String {
        let flattened = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        guard flattened.count > limit else { return flattened }
        return String(flattened.prefix(limit)) + "..."
    }

    private func questionMomentText(from text: String) -> String {
        if let followUpRange = text.range(of: "追问：") {
            let followUp = text[followUpRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !followUp.isEmpty {
                if let question = lastQuestionSentence(in: String(followUp)) {
                    return truncatedMomentText(question)
                }
                return truncatedMomentText(String(followUp))
            }
        }

        if let question = lastQuestionSentence(in: text) {
            return truncatedMomentText(question)
        }

        if let sentence = lastSentence(in: text) {
            return truncatedMomentText(sentence)
        }

        return truncatedMomentText(text)
    }

    private func lastQuestionSentence(in text: String) -> String? {
        sentenceFragments(in: text)
            .filter { fragment in
                fragment.hasSuffix("？") || fragment.hasSuffix("?")
            }
            .last
    }

    private func lastSentence(in text: String) -> String? {
        sentenceFragments(in: text).last
    }

    private func sentenceFragments(in text: String) -> [String] {
        let terminators: Set<Character> = ["。", "！", "？", "!", "?", "\n"]
        var fragments: [String] = []
        var current = ""

        for character in text {
            current.append(character)
            if terminators.contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    fragments.append(trimmed)
                }
                current = ""
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            fragments.append(tail)
        }
        return fragments
    }

    private func fieldFingerprint(_ field: BriefField, in snapshot: DesignBriefSnapshot) -> String {
        switch field {
        case .targetUser:
            return normalizedFingerprint(snapshot.targetUser)
        case .painPoint:
            return normalizedFingerprint(snapshot.painPoint)
        case .useScenario:
            return normalizedFingerprint(snapshot.useScenario)
        case .coreValue:
            return normalizedFingerprint(snapshot.coreValue)
        case .differentiation:
            return normalizedFingerprint(snapshot.differentiation)
        case .mvpFeatures:
            return normalizedFingerprint(snapshot.mvpFeatures)
        case .technicalModules:
            return normalizedFingerprint(snapshot.technicalModules)
        case .interactionFlow:
            return normalizedFingerprint(snapshot.interactionFlow)
        case .operationLogic:
            return normalizedFingerprint(snapshot.operationLogic)
        case .hardConstraints:
            return normalizedFingerprint(snapshot.hardConstraints)
        case .milestones:
            return normalizedFingerprint(snapshot.milestones)
        case .boundaryItems:
            return snapshot.boundaryItems
                .map { "\($0.isIncluded ? "in" : "out"):\(normalizedFingerprint($0.content))" }
                .sorted()
                .joined(separator: "|")
        case .successMetrics:
            return snapshot.successMetrics
                .map {
                    [
                        normalizedFingerprint($0.metric),
                        normalizedFingerprint($0.target),
                        normalizedFingerprint($0.measurement)
                    ].joined(separator: ":")
                }
                .sorted()
                .joined(separator: "|")
        case .risks:
            return snapshot.risks
                .map {
                    [
                        normalizedFingerprint($0.desc),
                        "\($0.probability)",
                        "\($0.impact)",
                        normalizedFingerprint($0.mitigation)
                    ].joined(separator: ":")
                }
                .sorted()
                .joined(separator: "|")
        }
    }

    private func normalizedFingerprint(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
}
