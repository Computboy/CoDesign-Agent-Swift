import Foundation

final class LLMAPIClient {
    private let config: LLMAPIConfig
    private let session: URLSession

    init(config: LLMAPIConfig = .loadFromEnvironment(),
         session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - Non-streaming JSON completion
    //
    // 用于 LiveStructuredExtractor 的结构化 JSON 字段提取。
    // stream = false, maxTokens = 1200, response_format = json_object, thinking = disabled
    //
    // 抛出：
    // - APIError.missingAPIKey: config.isValid == false
    // - APIError.httpStatus: HTTP 状态码非 2xx
    // - APIError.decodingFailed: JSON 解码失败或 finish_reason == "length"（输出被截断）
    // - APIError.emptyResponse: choices 为空或 content 为空
    // - APIError.networkFailed: 底层网络错误（不会重复包装已有 APIError）

    func completeJSON(messages: [ChatCompletionMessage]) async throws -> String {
        guard config.isValid else {
            throw APIError.missingAPIKey
        }

        let request: URLRequest
        do {
            request = try makeRequest(body: ChatCompletionRequest(
                model: config.model,
                messages: messages,
                stream: false,
                temperature: 0.2,
                maxTokens: 1200,
                responseFormat: ResponseFormat(type: "json_object"),
                thinking: config.thinkingType.map { ThinkingConfig(type: $0) }
            ))
        } catch {
            throw error
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpStatus(http.statusCode, bodyText)
        }

        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }

        guard let choice = decoded.choices.first else {
            throw APIError.emptyResponse
        }

        if choice.finishReason == "length" {
            throw APIError.decodingFailed
        }

        guard let content = choice.message?.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.emptyResponse
        }

        return content
    }

    // MARK: - Streaming chat
    //
    // 用于 LiveLLMService 的流式苏格拉底式追问。
    // stream = true, temperature = 0.7, maxTokens = 500, thinking = disabled
    //
    // 返回 AsyncThrowingStream<String, Error>，每个 yield 为一段增量文本 token。
    //
    // 抛出：
    // - APIError.missingAPIKey: config.isValid == false
    // - APIError.httpStatus: HTTP 状态码非 2xx
    // - APIError.emptyResponse: 流正常结束但 0 个 token 被 yield
    // - APIError.networkFailed: 底层网络错误（不会重复包装已有 APIError）

    func streamChat(messages: [ChatCompletionMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard config.isValid else {
                        throw APIError.missingAPIKey
                    }

                    let request: URLRequest
                    do {
                        request = try makeRequest(body: ChatCompletionRequest(
                            model: config.model,
                            messages: messages,
                            stream: true,
                            temperature: 0.7,
                            maxTokens: 500,
                            responseFormat: nil,
                            thinking: config.thinkingType.map { ThinkingConfig(type: $0) }
                        ))
                    } catch {
                        throw error
                    }

                    let (bytes, response) = try await session.bytes(for: request)

                    if let http = response as? HTTPURLResponse,
                       !(200...299).contains(http.statusCode) {
                        throw APIError.httpStatus(http.statusCode, "")
                    }

                    var emittedTokenCount = 0

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }

                        let dataString = String(line.dropFirst(6))

                        if dataString == "[DONE]" {
                            break
                        }

                        guard let data = dataString.data(using: .utf8) else { continue }

                        let decoded = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                        let token = decoded?.choices.first?.delta?.content

                        if let token, !token.isEmpty {
                            continuation.yield(token)
                            emittedTokenCount += 1
                        }
                    }

                    // 0 token 检测：如果流正常结束但没有任何 token，视为空响应
                    if emittedTokenCount == 0 {
                        throw APIError.emptyResponse
                    }

                    continuation.finish()
                } catch let error as APIError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: APIError.networkFailed(error))
                }
            }
        }
    }

    // MARK: - Connection test
    //
    // 用于设置页验证当前 Base URL / API Key / Model / Thinking Type 是否能跑通。
    // 使用极小的非流式请求，避免消耗过多 token，也避免依赖 response_format 支持。

    func testConnection() async throws -> String {
        guard config.isValid else {
            throw APIError.missingAPIKey
        }

        let request = try makeRequest(body: ChatCompletionRequest(
            model: config.model,
            messages: [
                ChatCompletionMessage(role: "system", content: "You are an API connection tester. Reply with exactly OK."),
                ChatCompletionMessage(role: "user", content: "Reply OK.")
            ],
            stream: false,
            temperature: 0,
            maxTokens: 8,
            responseFormat: nil,
            thinking: config.thinkingType.map { ThinkingConfig(type: $0) }
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpStatus(http.statusCode, bodyText)
        }

        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }

        guard let content = decoded.choices.first?.message?.content?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw APIError.emptyResponse
        }

        return content
    }

    // MARK: - Private

    private func makeRequest(body: ChatCompletionRequest) throws -> URLRequest {
        var request = URLRequest(url: config.chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = config.timeoutSeconds
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
