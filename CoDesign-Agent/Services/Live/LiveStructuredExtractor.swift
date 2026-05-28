import Foundation

final class LiveStructuredExtractor: StructuredExtractorProtocol {
    private let fallback = MockStructuredExtractor()
    private let apiClient = LLMAPIClient()

    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractedFields {
        do {
            // 1. 构造提取 messages
            let apiMessages = buildMessages(
                messages: messages,
                existing: existing
            )

            // 2. 调用 LLM（非流式 JSON）
            let rawJSON = try await apiClient.completeJSON(messages: apiMessages)

            // 3. 清理 JSON（去除可能的 ```json / ``` 包裹）
            let cleaned = cleanJSON(rawJSON)

            // 4. 解析为 ExtractedFields
            guard let data = cleaned.data(using: .utf8) else {
                throw APIError.decodingFailed
            }

            let fields = try JSONDecoder().decode(ExtractedFields.self, from: data)
            return fields
        } catch {
            print("[LiveStructuredExtractor] Live extraction failed, fallback to Mock: \(error)")
            return try await fallback.extract(from: messages, existing: existing)
        }
    }

    // MARK: - Private

    private func buildMessages(
        messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) -> [ChatCompletionMessage] {
        [
            ChatCompletionMessage(
                role: "system",
                content: ExtractionPromptTemplates.systemPrompt()
            ),
            ChatCompletionMessage(
                role: "user",
                content: ExtractionPromptTemplates.userPrompt(
                    messages: messages,
                    existing: existing
                )
            ),
        ]
    }

    /// 去除模型可能返回的 ```json / ``` 包裹和首尾空白
    private func cleanJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 去除开头 ```json 或 ```
        if s.hasPrefix("```json") {
            s = String(s.dropFirst(7))
        } else if s.hasPrefix("```") {
            s = String(s.dropFirst(3))
        }

        // 去除结尾 ```
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
