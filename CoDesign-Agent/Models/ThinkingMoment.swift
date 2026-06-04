import Foundation
import SwiftData

/// A persistent record of a thinking event during the design process.
/// Represents cognitive actions like diverging, converging, deepening, etc.
/// Drives the growth of the Thinking Tree visualization.
@Model
final class ThinkingMoment {
    @Attribute(.unique) var id: UUID
    var momType: String          // "seed" | "branch" | "deepen" | "converge" | "abandon" | "revise"
    var content: String          // display text
    var stageOrder: Int          // associated stage 1~9
    var relatedField: String?    // BriefField rawValue, nil for stage-level moments
    var parentMomentID: UUID?    // parent moment in tree hierarchy
    var timestamp: Date

    var project: Project?        // inverse relationship, SwiftData auto-maintains

    init(
        id: UUID = UUID(),
        momType: String,
        content: String,
        stageOrder: Int,
        relatedField: String? = nil,
        parentMomentID: UUID? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.momType = momType
        self.content = content
        self.stageOrder = stageOrder
        self.relatedField = relatedField
        self.parentMomentID = parentMomentID
        self.timestamp = timestamp
    }
}
