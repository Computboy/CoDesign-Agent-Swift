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
        let activeStage = sortedStages.first {
            $0.stageStatusValue == .active || $0.stageStatusValue == .notStarted
        }
        let stageSnapshot = activeStage?.toSnapshot()

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
        currentStreamingText = ""
        isStreaming = false

        // ⑥ 结构化提取（失败不中断对话）
        do {
            let outcome = try await extractor.extract(
                from: payloadMessages,
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
}
