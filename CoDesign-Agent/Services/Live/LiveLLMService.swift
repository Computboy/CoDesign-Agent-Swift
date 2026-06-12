import Foundation

final class LiveLLMService: LLMServiceProtocol {
    private let fallback = MockLLMService()

    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        mode: ClarificationMode,
        resourceCards: [ResourceCard]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // 1. 构造 API messages
                let apiMessages = self.buildAPIMessages(
                    messages: messages,
                    briefSnapshot: briefSnapshot,
                    currentStage: currentStage,
                    mode: mode,
                    resourceCards: resourceCards
                )

                do {
                    // 2. 调用流式 API
                    let stream = LLMAPIClient().streamChat(messages: apiMessages)

                    // 3. 转发 token
                    for try await token in stream {
                        continuation.yield(token)
                    }

                    continuation.finish()
                } catch {
                    print("[LiveLLMService] Live streaming failed, retrying non-streaming: \(error)")

                    do {
                        let reply = try await LLMAPIClient().completeChat(messages: apiMessages)
                        continuation.yield(reply)
                        continuation.finish()
                        return
                    } catch {
                        print("[LiveLLMService] Live non-streaming chat failed, fallback to Mock: \(error)")
                        Self.reportFallback(error)
                    }

                    // 4. Fallback to Mock only after both Live paths fail.
                    let mockStream = self.fallback.streamChat(
                        messages: messages,
                        briefSnapshot: briefSnapshot,
                        currentStage: currentStage,
                        mode: mode,
                        resourceCards: resourceCards
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

    private static func reportFallback(_ error: Error) {
        NotificationCenter.default.post(
            name: LLMRuntimeNotification.serviceFallback,
            object: nil,
            userInfo: [
                LLMRuntimeNotification.serviceKey: "Live 对话",
                LLMRuntimeNotification.messageKey: error.localizedDescription,
            ]
        )
    }

    // MARK: - Private

    private func buildAPIMessages(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        mode: ClarificationMode,
        resourceCards: [ResourceCard]
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
                currentStage: currentStage,
                resourceCards: resourceCards,
                mode: mode
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
