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
        let defaults = UserDefaults.standard
        let env = ProcessInfo.processInfo.environment

        // Read priority: UserDefaults → LLM_* env → DEEPSEEK_* env → default
        let baseURLString =
            defaults.string(forKey: "llmBaseURL").flatMap { $0.isEmpty ? nil : $0 }
            ?? env["LLM_BASE_URL"]
            ?? env["DEEPSEEK_BASE_URL"]
            ?? "https://api.deepseek.com"
        let apiKey =
            defaults.string(forKey: "llmAPIKey").flatMap { $0.isEmpty ? nil : $0 }
            ?? env["LLM_API_KEY"]
            ?? env["DEEPSEEK_API_KEY"]
            ?? ""
        let model =
            defaults.string(forKey: "llmModel").flatMap { $0.isEmpty ? nil : $0 }
            ?? env["LLM_MODEL"]
            ?? env["DEEPSEEK_MODEL"]
            ?? "deepseek-v4-flash"
        // For thinkingType, empty string means nil (don't send)
        let thinkingType =
            defaults.string(forKey: "llmThinkingType").flatMap { $0.isEmpty ? nil : $0 }
            ?? env["LLM_THINKING_TYPE"]

        return LLMAPIConfig(
            baseURL: URL(string: baseURLString) ?? URL(string: "https://api.deepseek.com")!,
            apiKey: apiKey,
            model: model,
            timeoutSeconds: 60,
            thinkingType: thinkingType
        )
    }
}
