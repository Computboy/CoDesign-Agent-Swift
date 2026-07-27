import Foundation
import SwiftData

@Model
final class MindTreeAnnotation {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var drawingData: Data
    var contentWidth: Double
    var contentHeight: Double
    var treeFingerprint: String
    var expandedTransitionOrders: String
    var expandedArchivedStageOrders: String
    var authorName: String
    var authorRole: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var project: Project?

    init(
        id: UUID = UUID(),
        drawingData: Data = Data(),
        contentWidth: Double,
        contentHeight: Double,
        treeFingerprint: String,
        expandedTransitionOrders: String = "",
        expandedArchivedStageOrders: String = "",
        authorName: String = "本机用户",
        authorRole: String = "设计者",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        project: Project? = nil
    ) {
        self.id = id
        self.drawingData = drawingData
        self.contentWidth = contentWidth
        self.contentHeight = contentHeight
        self.treeFingerprint = treeFingerprint
        self.expandedTransitionOrders = expandedTransitionOrders
        self.expandedArchivedStageOrders = expandedArchivedStageOrders
        self.authorName = authorName
        self.authorRole = authorRole
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.project = project
    }
}

enum MindTreeAnnotationLayerSelector {
    static func annotation(
        matching fingerprint: String,
        in annotations: [MindTreeAnnotation]
    ) -> MindTreeAnnotation? {
        annotations
            .filter { !$0.isArchived && $0.treeFingerprint == fingerprint }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }
}

extension Notification.Name {
    static let mindTreeAnnotationWillExport = Notification.Name(
        "CoDesignAgent.MindTreeAnnotationWillExport"
    )
}
