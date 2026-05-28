import Foundation

// MARK: - ChatCompletionResponse
//
// OpenAI-compatible Chat Completions 响应体。
// 同时支持非流式与流式（SSE）两种响应格式：
//
// - 非流式（JSON 提取）：读取 choices[0].message.content
// - 流式（SSE token）：读取 choices[0].delta.content
//
// finishReason == "length" 表示输出可能被 maxTokens 截断，
// 后续 LLMAPIClient.completeJSON() 应抛出 APIError.decodingFailed 并 fallback Mock。

struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message?
        let delta: Delta?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Message: Decodable {
        let role: String?
        let content: String?
    }

    struct Delta: Decodable {
        let role: String?
        let content: String?
    }
}
