import Foundation

struct LLMAPIConfig {
    let baseURL: URL
    let apiKey: String
    let model: String
    let timeoutSeconds: TimeInterval
    let thinkingType: String?

    init(
        baseURL: URL,
        apiKey: String,
        model: String,
        timeoutSeconds: TimeInterval,
        thinkingType: String?
    ) {
        self.baseURL = Self.normalizedBaseURL(from: baseURL.absoluteString) ?? baseURL
        self.apiKey = Self.normalizedAPIKey(apiKey)
        self.model = Self.normalizedRequired(model)
        self.timeoutSeconds = timeoutSeconds
        self.thinkingType = Self.normalizedOptional(thinkingType)
    }

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
            normalizedOptional(defaults.string(forKey: "llmBaseURL"))
            ?? normalizedOptional(env["LLM_BASE_URL"])
            ?? normalizedOptional(env["DEEPSEEK_BASE_URL"])
            ?? "https://api.deepseek.com"
        let apiKey =
            normalizedOptional(defaults.string(forKey: "llmAPIKey"))
            ?? normalizedOptional(env["LLM_API_KEY"])
            ?? normalizedOptional(env["DEEPSEEK_API_KEY"])
            ?? ""
        let model =
            normalizedOptional(defaults.string(forKey: "llmModel"))
            ?? normalizedOptional(env["LLM_MODEL"])
            ?? normalizedOptional(env["DEEPSEEK_MODEL"])
            ?? "deepseek-v4-flash"
        // For thinkingType, empty string means nil (don't send)
        let thinkingType =
            normalizedOptional(defaults.string(forKey: "llmThinkingType"))
            ?? normalizedOptional(env["LLM_THINKING_TYPE"])

        return LLMAPIConfig(
            baseURL: normalizedBaseURL(from: baseURLString) ?? URL(string: "https://api.deepseek.com")!,
            apiKey: apiKey,
            model: model,
            timeoutSeconds: 60,
            thinkingType: thinkingType
        )
    }

    private static func normalizedRequired(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = normalizedRequired(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedAPIKey(_ rawValue: String) -> String {
        var value = normalizedRequired(rawValue)
        if value.lowercased().hasPrefix("bearer") {
            value = String(value.dropFirst("bearer".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
    }

    private static func normalizedBaseURL(from rawValue: String) -> URL? {
        let trimmed = normalizedRequired(rawValue)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed) else {
            return nil
        }

        components.query = nil
        components.fragment = nil

        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if path.hasSuffix("/chat/completions") {
            path.removeLast("/chat/completions".count)
        }
        components.path = path

        return components.url
    }
}
