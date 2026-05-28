import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var role: String              // "user" | "assistant" | "system"
    var content: String
    var timestamp: Date
    var isStreaming: Bool

    var project: Project?         // 反向关系，SwiftData 自动维护

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}
