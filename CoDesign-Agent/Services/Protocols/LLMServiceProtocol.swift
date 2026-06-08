import Foundation

protocol LLMServiceProtocol {
    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        mode: ClarificationMode,
        resourceCards: [ResourceCard]
    ) -> AsyncThrowingStream<String, Error>
}
