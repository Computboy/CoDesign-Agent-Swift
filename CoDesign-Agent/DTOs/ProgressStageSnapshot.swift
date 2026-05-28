import Foundation

// MARK: - StageStatus
// 从 Models/ProgressStage.swift 迁移至此（Step 2）

enum StageStatus: String, Codable, CaseIterable {
    case notStarted
    case active
    case completed
    case needsReview
}

struct ProgressStageSnapshot: Codable {
    let order: Int
    let name: String
    var status: StageStatus
    var completionRatio: Double
}
