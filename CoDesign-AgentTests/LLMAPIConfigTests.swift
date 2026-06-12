import Foundation
import Testing
@testable import CoDesign_Agent

struct LLMAPIConfigTests {
    @Test func normalizesPastedSettingsValues() throws {
        let config = try LLMAPIConfig(
            baseURL: #require(URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions?debug=true")),
            apiKey: "  Bearer \n sk-test-key \t ",
            model: " qwen-plus \n",
            timeoutSeconds: 20,
            thinkingType: " disabled "
        )

        #expect(config.apiKey == "sk-test-key")
        #expect(config.model == "qwen-plus")
        #expect(config.thinkingType == "disabled")
        #expect(config.chatCompletionsURL.absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")
    }
}
