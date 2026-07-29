import Foundation
import SwiftData

@Model
final class MindTreeAnnotation {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var drawingData: Data
    @Attribute(.externalStorage) var textItemsData: Data?
    @Attribute(.externalStorage) var anchoredInkData: Data?
    @Attribute(.externalStorage) var layoutSnapshotsData: Data?
    var contentWidth: Double
    var contentHeight: Double
    var treeFingerprint: String
    var annotationDocumentVersion: Int?
    var lastKnownFingerprint: String?
    var migrationStateRaw: String?
    var legacySourceAnnotationID: UUID?
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
        anchoredInkData: Data? = nil,
        layoutSnapshotsData: Data? = nil,
        contentWidth: Double,
        contentHeight: Double,
        treeFingerprint: String,
        annotationDocumentVersion: Int? = nil,
        lastKnownFingerprint: String? = nil,
        migrationStateRaw: String? = nil,
        legacySourceAnnotationID: UUID? = nil,
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
        self.anchoredInkData = anchoredInkData
        self.layoutSnapshotsData = layoutSnapshotsData
        self.contentWidth = contentWidth
        self.contentHeight = contentHeight
        self.treeFingerprint = treeFingerprint
        self.annotationDocumentVersion = annotationDocumentVersion
        self.lastKnownFingerprint = lastKnownFingerprint
        self.migrationStateRaw = migrationStateRaw
        self.legacySourceAnnotationID = legacySourceAnnotationID
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
    var anchor: MindTreeAnnotationAnchor?
    var localX: Double?
    var localY: Double?
    var sourceAnchorX: Double?
    var sourceAnchorY: Double?
    var sourceAnchorWidth: Double?
    var sourceAnchorHeight: Double?
    var fallbackNormalizedX: Double?
    var fallbackNormalizedY: Double?
    var createdAgainstFingerprint: String?
    var migrationVersion: Int?
    var resolutionStateRaw: String?

    init(
        id: UUID = UUID(),
        text: String,
        x: Double,
        y: Double,
        width: Double = 260,
        height: Double = 112,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        anchor: MindTreeAnnotationAnchor? = nil,
        localX: Double? = nil,
        localY: Double? = nil,
        sourceAnchorX: Double? = nil,
        sourceAnchorY: Double? = nil,
        sourceAnchorWidth: Double? = nil,
        sourceAnchorHeight: Double? = nil,
        fallbackNormalizedX: Double? = nil,
        fallbackNormalizedY: Double? = nil,
        createdAgainstFingerprint: String? = nil,
        migrationVersion: Int? = nil,
        resolutionStateRaw: String? = nil
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.anchor = anchor
        self.localX = localX
        self.localY = localY
        self.sourceAnchorX = sourceAnchorX
        self.sourceAnchorY = sourceAnchorY
        self.sourceAnchorWidth = sourceAnchorWidth
        self.sourceAnchorHeight = sourceAnchorHeight
        self.fallbackNormalizedX = fallbackNormalizedX
        self.fallbackNormalizedY = fallbackNormalizedY
        self.createdAgainstFingerprint = createdAgainstFingerprint
        self.migrationVersion = migrationVersion
        self.resolutionStateRaw = resolutionStateRaw
    }

    var resolutionState: MindTreeAnnotationResolutionState {
        get {
            resolutionStateRaw
                .flatMap(MindTreeAnnotationResolutionState.init(rawValue:))
                ?? .resolved
        }
        set {
            resolutionStateRaw = newValue.rawValue
        }
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
    static func selection(
        matching fingerprint: String,
        in annotations: [MindTreeAnnotation]
    ) -> MindTreeAnnotationSelection? {
        let newestFirst = annotations.sorted { lhs, rhs in
            if lhs.isArchived != rhs.isArchived {
                return !lhs.isArchived
            }
            return lhs.updatedAt > rhs.updatedAt
        }

        if let modern = newestFirst.first(where: {
            !$0.isArchived && ($0.annotationDocumentVersion ?? 0) >= MindTreeAnnotationDocument.currentVersion
        }) {
            return MindTreeAnnotationSelection(annotation: modern, source: .modernProjectDocument)
        }

        if let exactLegacy = newestFirst.first(where: {
            ($0.annotationDocumentVersion ?? 0) < MindTreeAnnotationDocument.currentVersion &&
            $0.treeFingerprint == fingerprint
        }) {
            return MindTreeAnnotationSelection(annotation: exactLegacy, source: .exactLegacyLayer)
        }

        if let latestLegacy = newestFirst.first(where: {
            ($0.annotationDocumentVersion ?? 0) < MindTreeAnnotationDocument.currentVersion
        }) {
            return MindTreeAnnotationSelection(annotation: latestLegacy, source: .legacyLayerNeedsMigration)
        }

        return nil
    }

    static func annotation(
        matching fingerprint: String,
        in annotations: [MindTreeAnnotation]
    ) -> MindTreeAnnotation? {
        selection(matching: fingerprint, in: annotations)?.annotation
    }
}

extension Notification.Name {
    static let mindTreeAnnotationWillExport = Notification.Name(
        "CoDesignAgent.MindTreeAnnotationWillExport"
    )
}
