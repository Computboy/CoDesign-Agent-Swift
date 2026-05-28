import Foundation

struct LLMAPIConfig {
    let baseURL: URL
    let apiKey: String
    let model: String
    let timeoutSeconds: TimeInterval
    let thinkingType: String?

    var chatCompletionsURL: URL {
        baseURL.appending(path: "chat/completions")
    }

    var isValid: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func loadFromEnvironment() -> LLMAPIConfig {
        let env = ProcessInfo.processInfo.environment

        let baseURLString =
            env["LLM_BASE_URL"]
            ?? env["DEEPSEEK_BASE_URL"]
            ?? "https://api.deepseek.com"
        let apiKey =
            env["LLM_API_KEY"]
            ?? env["DEEPSEEK_API_KEY"]
            ?? ""
        let model =
            env["LLM_MODEL"]
            ?? env["DEEPSEEK_MODEL"]
            ?? "deepseek-v4-flash"
        let thinkingType = env["LLM_THINKING_TYPE"]

        return LLMAPIConfig(
            baseURL: URL(string: baseURLString) ?? URL(string: "https://api.deepseek.com")!,
            apiKey: apiKey,
            model: model,
            timeoutSeconds: 60,
            thinkingType: thinkingType
        )
    }
}
