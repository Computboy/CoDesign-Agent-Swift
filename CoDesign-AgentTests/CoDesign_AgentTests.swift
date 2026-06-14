import Foundation
import SwiftData
import Testing
@testable import CoDesign_Agent

struct CoDesign_AgentTests {

    @Test @MainActor func extractionRunsBeforeNextAssistantQuestion() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let project = Project(name: "Test", briefDescription: "Testing chat extraction")
        let brief = DesignBrief()
        let stage = ProgressStage(order: 1, name: "痛点与场景锚定", status: "active", completionRatio: 0)
        context.insert(project)
        context.insert(brief)
        context.insert(stage)
        project.brief = brief
        project.stages = [stage]

        let extractor = RecordingExtractor()
        let viewModel = ChatViewModel(
            project: project,
            llmService: ImmediateLLMService(response: "AI reply for extraction"),
            extractor: extractor
        )

        await viewModel.sendMessage("用户本轮输入")

        let messages = project.messages.sorted { $0.timestamp < $1.timestamp }
        #expect(messages.map(\.role) == ["user", "assistant"])
        #expect(extractor.capturedMessages.map(\.role) == ["user"])
        #expect(extractor.capturedMessages.last?.content == "用户本轮输入")
    }

    @Test @MainActor func extractionFailureDoesNotDiscardAssistantReply() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let project = Project(name: "Test", briefDescription: "Testing extraction failure")
        let brief = DesignBrief()
        let stage = ProgressStage(order: 1, name: "痛点与场景锚定", status: "active", completionRatio: 0)
        context.insert(project)
        context.insert(brief)
        context.insert(stage)
        project.brief = brief
        project.stages = [stage]

        let viewModel = ChatViewModel(
            project: project,
            llmService: ImmediateLLMService(response: "AI reply survives"),
            extractor: ThrowingExtractor()
        )

        await viewModel.sendMessage("用户本轮输入")

        let messages = project.messages.sorted { $0.timestamp < $1.timestamp }
        #expect(messages.map(\.role) == ["user", "assistant"])
        #expect(messages.last?.content == "AI reply survives")
        #expect(brief.latestExtractionFailureLog() != nil)
    }

    @Test @MainActor func oneRoundCampusNavigationInteractionAdvancesBeforeAsking() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let project = Project(name: "校园导航助手", briefDescription: "帮助新生减少校园迷路")
        let brief = DesignBrief()
        context.insert(project)
        context.insert(brief)
        project.brief = brief
        project.stages = StageDefinition.all.map { definition in
            let stage = ProgressStage(
                order: definition.order,
                name: definition.name,
                status: definition.order == 1 ? "active" : "notStarted",
                completionRatio: 0
            )
            context.insert(stage)
            return stage
        }

        let llm = CapturingPlannerLLMService()
        let viewModel = ChatViewModel(
            project: project,
            llmService: llm,
            extractor: CampusNavigationExtractor()
        )

        await viewModel.sendMessage("我想做一个给外地大一新生用的校园导航助手，他们开学第一周经常找不到教学楼。")

        let messages = project.messages.sorted { $0.timestamp < $1.timestamp }
        #expect(messages.map(\.role) == ["user", "assistant"])
        #expect(brief.targetUser == "外地大一新生")
        #expect(brief.painPoint == "开学第一周经常找不到教学楼")
        #expect(project.thinkingMoments.contains { $0.momType == "decision" && $0.relatedField == BriefField.targetUser.rawValue })
        #expect(project.learningTraces.contains { $0.actionType == "reframe" })
        #expect(llm.capturedBrief?.targetUser == "外地大一新生")
        #expect(llm.capturedBrief?.painPoint == "开学第一周经常找不到教学楼")
        #expect(llm.capturedStage?.order == 1)
        #expect(messages.last?.content.contains("这个判断会影响") == true)
        #expect(messages.last?.content.contains("所以这轮我只想先确认") == true)
    }

    @Test @MainActor func questionRevisionGeneratesNewQuestionFromActiveBranchContext() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let project = Project(name: "回溯项目", briefDescription: "测试回溯续问")
        let brief = DesignBrief()
        let stage = ProgressStage(order: 1, name: "痛点与场景锚定", status: "needsReview", completionRatio: 0.3)
        let oldAssistant = ChatMessage(role: "assistant", content: "旧分支里已经生成的 Stage 3 问题")
        context.insert(project)
        context.insert(brief)
        context.insert(stage)
        context.insert(oldAssistant)
        project.brief = brief
        project.stages = [stage]
        project.messages = [oldAssistant]

        let question = ThinkingMoment(momType: "question", content: "原问题是什么？", stageOrder: 1)
        let answer = ThinkingMoment(
            momType: "answer",
            content: "新答案",
            stageOrder: 1,
            parentMomentID: question.id,
            isActiveBranch: true
        )
        context.insert(question)
        context.insert(answer)
        project.thinkingMoments = [question, answer]

        let llm = CapturingPlannerLLMService()
        let viewModel = ChatViewModel(
            project: project,
            llmService: llm,
            extractor: RecordingExtractor()
        )

        await viewModel.continueAfterQuestionRevision(
            question: "原问题是什么？",
            revisedAnswer: "新答案",
            stageOrder: 1
        )

        let messages = project.messages.sorted { $0.timestamp < $1.timestamp }
        #expect(messages.last?.role == "assistant")
        #expect(messages.contains { $0.role == "user" && $0.content.contains("【回溯修改】") })
        #expect(llm.capturedMessages.contains { $0.content.contains("新答案") })
        #expect(!llm.capturedMessages.contains { $0.content.contains("旧分支里已经生成的 Stage 3 问题") })
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Project.self,
            ChatMessage.self,
            DesignBrief.self,
            ProgressStage.self,
            BoundaryItem.self,
            RiskItem.self,
            SuccessMetric.self,
            LearningTrace.self,
            ThinkingMoment.self,
            ExtractionAuditLog.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

private struct ImmediateLLMService: LLMServiceProtocol {
    let response: String

    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        mode: ClarificationMode,
        resourceCards: [ResourceCard]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(response)
            continuation.finish()
        }
    }
}

private final class CapturingPlannerLLMService: LLMServiceProtocol {
    var capturedBrief: DesignBriefSnapshot?
    var capturedStage: ProgressStageSnapshot?
    var capturedMessages: [ChatPayloadMessage] = []

    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        mode: ClarificationMode,
        resourceCards: [ResourceCard]
    ) -> AsyncThrowingStream<String, Error> {
        capturedMessages = messages
        capturedBrief = briefSnapshot
        capturedStage = currentStage

        let plan = DesignDialoguePlanner().plan(
            brief: briefSnapshot ?? DesignBriefSnapshot(),
            currentStage: currentStage
        )
        return AsyncThrowingStream { continuation in
            continuation.yield(plan.mockResponse)
            continuation.finish()
        }
    }
}

private final class RecordingExtractor: StructuredExtractorProtocol {
    var capturedMessages: [ChatPayloadMessage] = []

    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractionOutcome {
        capturedMessages = messages
        return ExtractionOutcome(
            source: .mock,
            status: .succeeded,
            envelope: ExtractionEnvelope(),
            attemptCount: 1
        )
    }
}

private struct CampusNavigationExtractor: StructuredExtractorProtocol {
    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractionOutcome {
        let quote = messages.last(where: { $0.role == "user" })?.content ?? ""
        let evidence = [EvidenceSpan(role: "user", quote: quote, turnIndex: 0)]
        return ExtractionOutcome(
            source: .mock,
            status: .succeeded,
            envelope: ExtractionEnvelope(
                targetUser: ExtractedFieldCandidate(
                    value: "外地大一新生",
                    confidence: 0.95,
                    level: .confirmed,
                    evidence: evidence,
                    shouldAutoCommit: true
                ),
                painPoint: ExtractedFieldCandidate(
                    value: "开学第一周经常找不到教学楼",
                    confidence: 0.95,
                    level: .confirmed,
                    evidence: evidence,
                    shouldAutoCommit: true
                )
            ),
            attemptCount: 1
        )
    }
}

private struct ThrowingExtractor: StructuredExtractorProtocol {
    struct Failure: Error {}

    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractionOutcome {
        throw Failure()
    }
}
