import Foundation

final class LiveStructuredExtractor: StructuredExtractorProtocol {
    private let fallback = MockStructuredExtractor()

    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractedFields {
        // v0.2 TODO:
        // 1. 构造提取 Prompt（含 existing brief 和最近对话）
        // 2. 调用 LLM（非流式）
        // 3. 解析 JSON → ExtractedFields
        // 4. JSON 解析失败时静默跳过
        return try await fallback.extract(from: messages, existing: existing)
    }
}
