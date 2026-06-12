import Foundation

enum APIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String)
    case decodingFailed
    case emptyResponse
    case networkFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "缺少 API Key，请检查本地配置。"
        case .invalidURL:
            return "API 地址无效。"
        case .invalidResponse:
            return "API 返回格式无效。"
        case .httpStatus(let code, let body):
            return "API 请求失败：HTTP \(code)。\(body)"
        case .decodingFailed:
            return "API 返回解析失败。"
        case .emptyResponse:
            return "API 返回为空。"
        case .networkFailed(let error):
            return "网络请求失败：\(error.localizedDescription)"
        }
    }
}

enum LLMRuntimeNotification {
    static let serviceFallback = Notification.Name("coDesignLLMServiceFallback")
    static let configurationChanged = Notification.Name("coDesignLLMConfigurationChanged")
    static let serviceKey = "service"
    static let messageKey = "message"
}
