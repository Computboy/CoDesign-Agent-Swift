import Foundation

// MARK: - ChatCompletionRequest
//
// OpenAI-compatible Chat Completions 请求体。
//
// 用法建议：
// - 对话流式回复（LiveLLMService）：stream = true, maxTokens = 500
// - 结构化 JSON 提取（LiveStructuredExtractor）：stream = false, maxTokens = 1200,
//   responseFormat = ResponseFormat(type: "json_object")
//
// thinking：
// - v0.2 阶段显式传入 ThinkingConfig(type: "disabled") 关闭 thinking mode，
//   保证速度、稳定性和可调试性。
//
// 如果 API 不支持 response_format 或 thinking，会静默忽略这些字段，不会报错。

struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatCompletionMessage]
    let stream: Bool
    let temperature: Double?
    let maxTokens: Int?
    let responseFormat: ResponseFormat?
    let thinking: ThinkingConfig?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
        case thinking
    }
}

// MARK: - ChatCompletionMessage

struct ChatCompletionMessage: Codable {
    let role: String
    let content: String
}

// MARK: - ResponseFormat
//
// 用于 JSON 提取时指定响应格式：ResponseFormat(type: "json_object")

struct ResponseFormat: Encodable {
    let type: String
}

// MARK: - ThinkingConfig
//
// v0.2 阶段关闭 thinking mode：ThinkingConfig(type: "disabled")

struct ThinkingConfig: Encodable {
    let type: String
}
