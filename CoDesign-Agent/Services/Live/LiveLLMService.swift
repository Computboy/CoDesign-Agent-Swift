import Foundation

final class LiveLLMService: LLMServiceProtocol {
    private let fallback = MockLLMService()

    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?
    ) -> AsyncThrowingStream<String, Error> {
        // v0.2 TODO:
        // 1. 读取 API Key（ProcessInfo / Keychain）
        // 2. 构造 HTTP request（messages, model, stream: true）
        // 3. URLSession.bytes(for:) 发起请求
        // 4. 逐行解析 SSE data，yield content delta
        // 5. 错误处理：apiKeyMissing / networkFailed / rateLimited
        return fallback.streamChat(
            messages: messages,
            briefSnapshot: briefSnapshot,
            currentStage: currentStage
        )
    }
}
