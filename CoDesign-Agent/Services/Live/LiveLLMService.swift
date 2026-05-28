import Foundation

final class LiveLLMService: LLMServiceProtocol {
    private let fallback = MockLLMService()
    private let apiClient = LLMAPIClient()

    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // 1. 构造 API messages
                    let apiMessages = self.buildAPIMessages(
                        messages: messages,
                        briefSnapshot: briefSnapshot,
                        currentStage: currentStage
                    )

                    // 2. 调用流式 API
                    let stream = self.apiClient.streamChat(messages: apiMessages)

                    // 3. 转发 token
                    for try await token in stream {
                        continuation.yield(token)
                    }

                    continuation.finish()
                } catch {
                    print("[LiveLLMService] Live chat failed, fallback to Mock: \(error)")

                    // 4. Fallback to Mock
                    let mockStream = self.fallback.streamChat(
                        messages: messages,
                        briefSnapshot: briefSnapshot,
                        currentStage: currentStage
                    )

                    Task {
                        do {
                            for try await token in mockStream {
                                continuation.yield(token)
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Private

    private func buildAPIMessages(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?
    ) -> [ChatCompletionMessage] {
        var result: [ChatCompletionMessage] = []

        // 1. System prompt
        result.append(ChatCompletionMessage(
            role: "system",
            content: SocraticPromptTemplates.systemPrompt()
        ))

        // 2. Context prompt (当前状态)
        result.append(ChatCompletionMessage(
            role: "user",
            content: SocraticPromptTemplates.contextPrompt(
                brief: briefSnapshot,
                currentStage: currentStage
            )
        ))

        result.append(ChatCompletionMessage(
            role: "assistant",
            content: "好的，我会根据当前阶段和已有信息继续追问。"
        ))

        // 3. 最近 12 条历史消息
        let recent = messages.suffix(12)
        for msg in recent {
            result.append(ChatCompletionMessage(
                role: msg.role,
                content: msg.content
            ))
        }

        return result
    }
}
