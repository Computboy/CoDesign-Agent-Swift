import Foundation
import SwiftData

@Model
final class MindTreeAnnotation {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var drawingData: Data
    @Attribute(.externalStorage) var textItemsData: Data?
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
        textItemsData: Data? = nil,
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
        self.textItemsData = textItemsData
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

struct MindTreeTextAnnotationItem: Codable, Identifiable, Equatable {
    var id: UUID
    var text: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        x: Double,
        y: Double,
        width: Double = 260,
        height: Double = 112,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum MindTreeTextAnnotationCodec {
    static func encode(_ items: [MindTreeTextAnnotationItem]) -> Data {
        (try? JSONEncoder().encode(items)) ?? Data()
    }

    static func decode(_ data: Data) -> [MindTreeTextAnnotationItem] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([MindTreeTextAnnotationItem].self, from: data)) ?? []
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
