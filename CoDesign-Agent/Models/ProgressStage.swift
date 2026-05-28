import Foundation
import SwiftData

@Model
final class ProgressStage {
    @Attribute(.unique) var id: UUID
    var order: Int                // 1~9
    var name: String
    var status: String            // "notStarted" | "active" | "completed" | "needsReview"
    var completionRatio: Double   // 0.0 ~ 1.0
    var lastUpdated: Date?

    var project: Project?         // 反向关系，SwiftData 自动维护

    init(
        id: UUID = UUID(),
        order: Int,
        name: String,
        status: String = "notStarted",
        completionRatio: Double = 0.0,
        lastUpdated: Date? = nil
    ) {
        self.id = id
        self.order = order
        self.name = name
        self.status = status
        self.completionRatio = completionRatio
        self.lastUpdated = lastUpdated
    }

    /// Model(String) ↔ DTO(StageStatus) 桥接
    var stageStatusValue: StageStatus {
        get { StageStatus(rawValue: status) ?? .notStarted }
        set { status = newValue.rawValue }
    }
}
