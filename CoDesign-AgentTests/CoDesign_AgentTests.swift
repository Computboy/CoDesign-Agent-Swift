import Foundation
import SwiftData
import Testing
@testable import CoDesign_Agent

struct CoDesign_AgentTests {

    @Test @MainActor func extractorReceivesCurrentAssistantReply() async throws {
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
        #expect(extractor.capturedMessages.map(\.role) == ["user", "assistant"])
        #expect(extractor.capturedMessages.last?.content == "AI reply for extraction")
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
        currentStage: ProgressStageSnapshot?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(response)
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

private struct ThrowingExtractor: StructuredExtractorProtocol {
    struct Failure: Error {}

    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractionOutcome {
        throw Failure()
    }
}
