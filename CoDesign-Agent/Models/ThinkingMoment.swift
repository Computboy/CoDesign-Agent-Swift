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
    var summary: String?         // compact tree label; full question remains in content
    var stageOrder: Int          // associated stage 1~9
    var relatedField: String?    // BriefField rawValue, nil for stage-level moments
    var resourceCardID: String?  // stable ResourceLibrary identifier for method/evidence cards
    var parentMomentID: UUID?    // parent moment in tree hierarchy
    var timestamp: Date

    // Branching support
    var isActiveBranch: Bool     // true = current active branch, false = archived/old branch
    var branchVersion: Int       // version number (increments on each branch fork)
    var archivedAt: Date?        // when this branch was archived (nil if still active)

    var project: Project?        // inverse relationship, SwiftData auto-maintains

    init(
        id: UUID = UUID(),
        momType: String,
        content: String,
        summary: String? = nil,
        stageOrder: Int,
        relatedField: String? = nil,
        resourceCardID: String? = nil,
        parentMomentID: UUID? = nil,
        timestamp: Date = Date(),
        isActiveBranch: Bool = true,
        branchVersion: Int = 1,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.momType = momType
        self.content = content
        self.summary = summary
        self.stageOrder = stageOrder
        self.relatedField = relatedField
        self.resourceCardID = resourceCardID
        self.parentMomentID = parentMomentID
        self.timestamp = timestamp
        self.isActiveBranch = isActiveBranch
        self.branchVersion = branchVersion
        self.archivedAt = archivedAt
    }
}
