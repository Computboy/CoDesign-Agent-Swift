import Foundation
import SwiftData

@Model
final class LearningTrace {
    @Attribute(.unique) var id: UUID
    var stageOrder: Int           // 关联阶段 1~9
    var actionType: String        // v0.1: "reframe" | "converge" | "boundaryShrink"
    var title: String
    var detail: String
    var timestamp: Date

    var project: Project?         // 反向关系，SwiftData 自动维护

    init(
        id: UUID = UUID(),
        stageOrder: Int,
        actionType: String,
        title: String,
        detail: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stageOrder = stageOrder
        self.actionType = actionType
        self.title = title
        self.detail = detail
        self.timestamp = timestamp
    }
}
