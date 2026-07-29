import Foundation

enum MindTreeAnnotationDocument {
    static let currentVersion = 2
    static let currentMigrationVersion = 1
}

enum MindTreeAnnotationAnchor: Hashable, Equatable, Codable {
    case project
    case stage(order: Int)
    case transition(stageOrder: Int)
    case moment(id: UUID, branchVersion: Int, stageOrder: Int)
    case archivedBranch(stageOrder: Int, branchVersion: Int)

    private enum CodingKeys: String, CodingKey {
        case kind
        case order
        case id
        case branchVersion
        case stageOrder
    }

    private enum Kind: String, Codable {
        case project
        case stage
        case transition
        case moment
        case archivedBranch
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .project:
            self = .project
        case .stage:
            self = .stage(order: try container.decode(Int.self, forKey: .order))
        case .transition:
            self = .transition(stageOrder: try container.decode(Int.self, forKey: .stageOrder))
        case .moment:
            self = .moment(
                id: try container.decode(UUID.self, forKey: .id),
                branchVersion: try container.decode(Int.self, forKey: .branchVersion),
                stageOrder: try container.decode(Int.self, forKey: .stageOrder)
            )
        case .archivedBranch:
            self = .archivedBranch(
                stageOrder: try container.decode(Int.self, forKey: .stageOrder),
                branchVersion: try container.decode(Int.self, forKey: .branchVersion)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .project:
            try container.encode(Kind.project, forKey: .kind)
        case let .stage(order):
            try container.encode(Kind.stage, forKey: .kind)
            try container.encode(order, forKey: .order)
        case let .transition(stageOrder):
            try container.encode(Kind.transition, forKey: .kind)
            try container.encode(stageOrder, forKey: .stageOrder)
        case let .moment(id, branchVersion, stageOrder):
            try container.encode(Kind.moment, forKey: .kind)
            try container.encode(id, forKey: .id)
            try container.encode(branchVersion, forKey: .branchVersion)
            try container.encode(stageOrder, forKey: .stageOrder)
        case let .archivedBranch(stageOrder, branchVersion):
            try container.encode(Kind.archivedBranch, forKey: .kind)
            try container.encode(stageOrder, forKey: .stageOrder)
            try container.encode(branchVersion, forKey: .branchVersion)
        }
    }

    var stableID: String {
        switch self {
        case .project:
            return "project"
        case let .stage(order):
            return "stage:\(order)"
        case let .transition(stageOrder):
            return "transition:\(stageOrder)"
        case let .moment(id, branchVersion, stageOrder):
            return "moment:\(id.uuidString):\(branchVersion):\(stageOrder)"
        case let .archivedBranch(stageOrder, branchVersion):
            return "archived:\(stageOrder):\(branchVersion)"
        }
    }

    func remappingMomentIDs(_ mapping: [UUID: UUID]) -> Self {
        guard case let .moment(id, branchVersion, stageOrder) = self,
              let mappedID = mapping[id] else {
            return self
        }
        return .moment(id: mappedID, branchVersion: branchVersion, stageOrder: stageOrder)
    }
}

enum MindTreeAnnotationResolutionState: String, Codable, Equatable {
    case resolved
    case hidden
    case unresolved
}

struct MindTreeAnnotationAnchorFrame: Codable, Equatable, Identifiable {
    var anchor: MindTreeAnnotationAnchor
    var nodeID: String?
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var id: String { anchor.stableID }
}

struct MindTreeAnnotationLayoutSnapshot: Codable, Equatable {
    var version: Int
    var anchors: [MindTreeAnnotationAnchorFrame]
    var contentWidth: Double
    var contentHeight: Double
    var expandedTransitionOrders: String
    var expandedArchivedStageOrders: String
    var fingerprint: String
    var capturedAt: Date

    init(
        version: Int = MindTreeAnnotationDocument.currentVersion,
        anchors: [MindTreeAnnotationAnchorFrame],
        contentWidth: Double,
        contentHeight: Double,
        expandedTransitionOrders: String,
        expandedArchivedStageOrders: String,
        fingerprint: String,
        capturedAt: Date = Date()
    ) {
        self.version = version
        self.anchors = anchors
        self.contentWidth = contentWidth
        self.contentHeight = contentHeight
        self.expandedTransitionOrders = expandedTransitionOrders
        self.expandedArchivedStageOrders = expandedArchivedStageOrders
        self.fingerprint = fingerprint
        self.capturedAt = capturedAt
    }

    func frame(for anchor: MindTreeAnnotationAnchor) -> MindTreeAnnotationAnchorFrame? {
        anchors.first { $0.anchor == anchor }
    }

    func remappingMomentIDs(_ mapping: [UUID: UUID]) -> Self {
        var copy = self
        copy.anchors = anchors.map { entry in
            var remapped = entry
            remapped.anchor = entry.anchor.remappingMomentIDs(mapping)
            return remapped
        }
        return copy
    }
}

struct MindTreeAnchoredInkGroup: Codable, Equatable, Identifiable {
    var id: UUID
    var anchor: MindTreeAnnotationAnchor
    var drawingData: Data
    var sourceAnchorX: Double
    var sourceAnchorY: Double
    var sourceAnchorWidth: Double
    var sourceAnchorHeight: Double
    var fallbackNormalizedX: Double
    var fallbackNormalizedY: Double
    var createdAt: Date
    var updatedAt: Date
    var createdAgainstFingerprint: String
    var migrationVersion: Int
    var resolutionStateRaw: String?

    init(
        id: UUID = UUID(),
        anchor: MindTreeAnnotationAnchor,
        drawingData: Data,
        sourceAnchorX: Double,
        sourceAnchorY: Double,
        sourceAnchorWidth: Double,
        sourceAnchorHeight: Double,
        fallbackNormalizedX: Double,
        fallbackNormalizedY: Double,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdAgainstFingerprint: String,
        migrationVersion: Int = MindTreeAnnotationDocument.currentMigrationVersion,
        resolutionStateRaw: String? = nil
    ) {
        self.id = id
        self.anchor = anchor
        self.drawingData = drawingData
        self.sourceAnchorX = sourceAnchorX
        self.sourceAnchorY = sourceAnchorY
        self.sourceAnchorWidth = sourceAnchorWidth
        self.sourceAnchorHeight = sourceAnchorHeight
        self.fallbackNormalizedX = fallbackNormalizedX
        self.fallbackNormalizedY = fallbackNormalizedY
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

    func remappingMomentIDs(_ mapping: [UUID: UUID]) -> Self {
        var copy = self
        copy.anchor = anchor.remappingMomentIDs(mapping)
        return copy
    }
}

enum MindTreeAnnotationMigrationState: String, Codable {
    case native
    case migrated
    case pending
    case failed
}

enum MindTreeAnnotationSelectionSource: Equatable {
    case modernProjectDocument
    case exactLegacyLayer
    case legacyLayerNeedsMigration
}

struct MindTreeAnnotationSelection {
    let annotation: MindTreeAnnotation
    let source: MindTreeAnnotationSelectionSource

    var needsMigration: Bool {
        source != .modernProjectDocument
    }
}

enum MindTreeAnchoredInkCodec {
    static func encode(_ groups: [MindTreeAnchoredInkGroup]) -> Data {
        (try? JSONEncoder().encode(groups)) ?? Data()
    }

    static func decode(_ data: Data?) -> [MindTreeAnchoredInkGroup] {
        guard let data, !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([MindTreeAnchoredInkGroup].self, from: data)) ?? []
    }
}

enum MindTreeAnnotationLayoutCodec {
    static func encode(_ snapshots: [MindTreeAnnotationLayoutSnapshot]) -> Data {
        (try? JSONEncoder().encode(snapshots)) ?? Data()
    }

    static func decode(_ data: Data?) -> [MindTreeAnnotationLayoutSnapshot] {
        guard let data, !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([MindTreeAnnotationLayoutSnapshot].self, from: data)) ?? []
    }
}
