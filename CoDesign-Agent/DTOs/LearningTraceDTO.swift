import Foundation

struct LearningTraceDTO: Codable, Identifiable {
    var id: UUID?
    var stageOrder: Int
    var actionType: String
    var title: String
    var detail: String
    var timestamp: Date?

    init(
        id: UUID? = nil,
        stageOrder: Int,
        actionType: String,
        title: String,
        detail: String,
        timestamp: Date? = nil
    ) {
        self.id = id
        self.stageOrder = stageOrder
        self.actionType = actionType
        self.title = title
        self.detail = detail
        self.timestamp = timestamp
    }
}
