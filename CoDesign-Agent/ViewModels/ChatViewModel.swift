import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ChatViewModel {
    let project: Project
    private let llmService: any LLMServiceProtocol
    private let extractor: any StructuredExtractorProtocol
    private let analyzer = ProgressAnalyzer()

    var currentStreamingText: String = ""
    var isStreaming: Bool = false
    var errorMessage: String?

    init(project: Project,
         llmService: any LLMServiceProtocol,
         extractor: any StructuredExtractorProtocol) {
        self.project = project
        self.llmService = llmService
        self.extractor = extractor
    }

    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let context = project.modelContext else { return }

        // ① 保存用户消息
        let userMsg = ChatMessage(role: "user", content: text)
        context.insert(userMsg)
        project.messages.append(userMsg)
        project.updatedAt = Date()

        // ② 快照当前状态（用于后续 diff）
        let previousBrief = project.brief?.toSnapshot() ?? DesignBriefSnapshot()

        // ③ 构造 DTO
        let payloadMessages = project.messages
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.toPayload() }
        let briefSnapshot = project.brief?.toSnapshot()
        let sortedStages = project.stages.sorted { $0.order < $1.order }
        let activeStage = sortedStages.first { $0.stageStatusValue == .needsReview }
            ?? sortedStages.first { $0.stageStatusValue == .active }
            ?? sortedStages.first { $0.stageStatusValue == .notStarted }
        let stageSnapshot = activeStage?.toSnapshot()
        let activeStageOrder = activeStage?.order ?? project.currentStageOrder

        recordThinkingMoment(
            momType: "answer",
            content: truncatedMomentText(text),
            stageOrder: activeStageOrder,
            relatedField: nil,
            context: context
        )
        try? context.save()

        // ④ 流式调用 LLM
        isStreaming = true
        currentStreamingText = ""
        errorMessage = nil

        do {
            let stream = llmService.streamChat(
                messages: payloadMessages,
                briefSnapshot: briefSnapshot,
                currentStage: stageSnapshot
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

        // ⑤ 保存 AI 回复
        let assistantMsg = ChatMessage(role: "assistant", content: currentStreamingText)
        context.insert(assistantMsg)
        project.messages.append(assistantMsg)
        recordThinkingMoment(
            momType: "question",
            content: questionMomentText(from: assistantMsg.content),
            stageOrder: activeStageOrder,
            relatedField: nil,
            context: context
        )
        currentStreamingText = ""
        isStreaming = false

        // ⑥ 结构化提取（失败不中断对话）
        let extractionMessages = project.messages
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.toPayload() }
        do {
            let outcome = try await extractor.extract(
                from: extractionMessages,
                existing: briefSnapshot
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

        // ⑥.5 思维片段记录：检测新填充的字段，生成 ThinkingMoment
        let updatedBriefSnapshot = project.brief?.toSnapshot() ?? DesignBriefSnapshot()
        let preBrief = briefSnapshot ?? DesignBriefSnapshot()
        for field in BriefField.allCases {
            let wasEmpty = !field.isFilled(in: preBrief)
            let isNowFilled = field.isFilled(in: updatedBriefSnapshot)
            let changedMeaningfully = fieldFingerprint(field, in: preBrief) != fieldFingerprint(field, in: updatedBriefSnapshot)
            if isNowFilled && (wasEmpty || changedMeaningfully) {
                let stageOrder = StageDefinition.all
                    .first { $0.briefFields.contains(field) }?.order ?? 1
                recordThinkingMoment(
                    momType: "decision",
                    content: "确认：\(field.displayName)",
                    stageOrder: stageOrder,
                    relatedField: field.rawValue,
                    context: context
                )
            }
        }

        // ⑦ 进度分析
        let currentBriefSnapshot = project.brief?.toSnapshot() ?? DesignBriefSnapshot()
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

        // ⑧ 学习轨迹检测
        let traces = analyzer.detectLearningTraces(
            previousBrief: previousBrief,
            currentBrief: currentBriefSnapshot,
            activeStageOrder: activeStage?.order ?? 1
        )
        for traceDTO in traces {
            let trace = LearningTrace(
                stageOrder: traceDTO.stageOrder,
                actionType: traceDTO.actionType,
                title: traceDTO.title,
                detail: traceDTO.detail
            )
            context.insert(trace)
            project.learningTraces.append(trace)
        }

        // ⑨ 保存
        try? context.save()
    }

    // MARK: - Thinking Moment Recording

    private func recordThinkingMoment(
        momType: String,
        content: String,
        stageOrder: Int,
        relatedField: String?,
        context: ModelContext
    ) {
        let normalized = truncatedMomentText(content)
        guard !normalized.isEmpty else { return }

        let now = Date()
        let isDuplicate = project.thinkingMoments.contains { moment in
            moment.momType == momType &&
            moment.content == normalized &&
            moment.stageOrder == stageOrder &&
            moment.relatedField == relatedField &&
            abs(moment.timestamp.timeIntervalSince(now)) < 4
        }
        guard !isDuplicate else { return }

        let moment = ThinkingMoment(
            momType: momType,
            content: normalized,
            stageOrder: stageOrder,
            relatedField: relatedField,
            timestamp: now,
            isActiveBranch: true
        )
        context.insert(moment)
        project.thinkingMoments.append(moment)
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
        let separators = CharacterSet(charactersIn: "。！？!?\n")
        let fragments = text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let question = fragments.first(where: { fragment in
            text.contains(fragment + "？") || text.contains(fragment + "?")
        }) {
            return truncatedMomentText(question)
        }

        return truncatedMomentText(fragments.first ?? text)
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
