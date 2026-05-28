import Foundation

struct ChatPayloadMessage: Codable, Equatable {
    let role: String              // "system" | "user" | "assistant"
    let content: String

    // MARK: - 工厂方法

    static func system(_ content: String) -> ChatPayloadMessage {
        ChatPayloadMessage(role: "system", content: content)
    }

    static func user(_ content: String) -> ChatPayloadMessage {
        ChatPayloadMessage(role: "user", content: content)
    }

    static func assistant(_ content: String) -> ChatPayloadMessage {
        ChatPayloadMessage(role: "assistant", content: content)
    }
}
