import Foundation
import SwiftUI

struct MindTreeAnnotationProjectionSummary: Equatable {
    var hiddenTextCount = 0
    var unresolvedTextCount = 0
    var hiddenInkCount = 0
    var unresolvedInkCount = 0

    var hiddenCount: Int { hiddenTextCount + hiddenInkCount }
    var unresolvedCount: Int { unresolvedTextCount + unresolvedInkCount }
    var hasExceptions: Bool { hiddenCount > 0 || unresolvedCount > 0 }
}

struct MindTreeAnnotationProjectionService {
    struct ResolvedPosition: Equatable {
        var point: CGPoint
        var state: MindTreeAnnotationResolutionState
    }

    @MainActor
    static func layoutSnapshot(
        graph: TreeData,
        fingerprint: String,
        expandedTransitionOrders: Set<Int>,
        expandedArchivedStageOrders: Set<Int>,
        resourceDeckProgressByQuestionID: [String: CGFloat] = [:],
        canvasContentSize: CGSize? = nil,
        capturedAt: Date = Date()
    ) -> MindTreeAnnotationLayoutSnapshot {
        var frames = graph.nodes.compactMap(anchorFrame(for:))
        frames.append(
            contentsOf: QuestionResourceDeckLayout.annotationFrames(
                graph: graph,
                progressByQuestionID: resourceDeckProgressByQuestionID
            )
        )

        for edge in graph.edges {
            guard let order = edge.togglesTransitionOrder,
                  let from = graph.node(for: edge.fromID),
                  let to = graph.node(for: edge.toID) else {
                continue
            }
            let center = CGPoint(
                x: (from.position.x + to.position.x) / 2,
                y: (from.position.y + to.position.y) / 2
            )
            frames.append(
                MindTreeAnnotationAnchorFrame(
                    anchor: .transition(stageOrder: order),
                    nodeID: edge.id,
                    x: center.x,
                    y: center.y,
                    width: max(abs(to.position.x - from.position.x), 44),
                    height: max(abs(to.position.y - from.position.y), 44)
                )
            )
        }

        let resolvedContentSize = canvasContentSize
            ?? QuestionResourceDeckLayout.canvasContentSize(
                graph: graph,
                progressByQuestionID: resourceDeckProgressByQuestionID
            )

        return MindTreeAnnotationLayoutSnapshot(
            anchors: deduplicated(frames),
            contentWidth: resolvedContentSize.width,
            contentHeight: resolvedContentSize.height,
            expandedTransitionOrders: MindTreeAnnotationExpansionCodec.encode(expandedTransitionOrders),
            expandedArchivedStageOrders: MindTreeAnnotationExpansionCodec.encode(expandedArchivedStageOrders),
            fingerprint: fingerprint,
            capturedAt: capturedAt
        )
    }

    static func knownAnchors(in project: Project) -> Set<MindTreeAnnotationAnchor> {
        var anchors: Set<MindTreeAnnotationAnchor> = [.project]

        for order in StageDefinition.all.map(\.order) {
            anchors.insert(.stage(order: order))
            anchors.insert(.transition(stageOrder: order))
        }

        for moment in project.thinkingMoments {
            anchors.insert(
                .moment(
                    id: moment.id,
                    branchVersion: moment.branchVersion,
                    stageOrder: moment.stageOrder
                )
            )
            if !moment.isActiveBranch {
                anchors.insert(
                    .archivedBranch(
                        stageOrder: moment.stageOrder,
                        branchVersion: moment.branchVersion
                    )
                )
            }
        }

        return anchors
    }

    static func anchoredTextItem(
        _ item: MindTreeTextAnnotationItem,
        at point: CGPoint,
        in snapshot: MindTreeAnnotationLayoutSnapshot,
        fingerprint: String
    ) -> MindTreeTextAnnotationItem {
        let frame = nearestAnchor(to: point, in: snapshot)
            ?? snapshot.frame(for: .project)
            ?? MindTreeAnnotationAnchorFrame(
                anchor: .project,
                nodeID: nil,
                x: snapshot.contentWidth / 2,
                y: snapshot.contentHeight / 2,
                width: 1,
                height: 1
            )

        var copy = item
        copy.x = point.x
        copy.y = point.y
        copy.anchor = frame.anchor
        copy.localX = point.x - frame.x
        copy.localY = point.y - frame.y
        copy.sourceAnchorX = frame.x
        copy.sourceAnchorY = frame.y
        copy.sourceAnchorWidth = frame.width
        copy.sourceAnchorHeight = frame.height
        copy.fallbackNormalizedX = normalized(point.x, dimension: snapshot.contentWidth)
        copy.fallbackNormalizedY = normalized(point.y, dimension: snapshot.contentHeight)
        copy.createdAgainstFingerprint = copy.createdAgainstFingerprint ?? fingerprint
        copy.migrationVersion = MindTreeAnnotationDocument.currentMigrationVersion
        copy.resolutionState = .resolved
        return copy
    }

    static func migrateLegacyTextItems(
        _ items: [MindTreeTextAnnotationItem],
        sourceWidth: Double,
        sourceHeight: Double,
        to snapshot: MindTreeAnnotationLayoutSnapshot,
        fingerprint: String
    ) -> [MindTreeTextAnnotationItem] {
        items.map { item in
            if item.anchor != nil {
                return projectedTextItem(
                    item,
                    in: snapshot,
                    knownAnchors: Set(snapshot.anchors.map(\.anchor))
                )
            }

            let projectedPoint = CGPoint(
                x: normalized(item.x, dimension: sourceWidth) * snapshot.contentWidth,
                y: normalized(item.y, dimension: sourceHeight) * snapshot.contentHeight
            )
            return anchoredTextItem(item, at: projectedPoint, in: snapshot, fingerprint: fingerprint)
        }
    }

    static func projectedTextItems(
        _ items: [MindTreeTextAnnotationItem],
        in snapshot: MindTreeAnnotationLayoutSnapshot,
        knownAnchors: Set<MindTreeAnnotationAnchor>
    ) -> [MindTreeTextAnnotationItem] {
        items.map {
            projectedTextItem($0, in: snapshot, knownAnchors: knownAnchors)
        }
    }

    static func projectedTextItem(
        _ item: MindTreeTextAnnotationItem,
        in snapshot: MindTreeAnnotationLayoutSnapshot,
        knownAnchors: Set<MindTreeAnnotationAnchor>
    ) -> MindTreeTextAnnotationItem {
        guard let anchor = item.anchor else {
            var copy = item
            copy.resolutionState = .unresolved
            return copy
        }

        let resolved = resolvedPosition(
            anchor: anchor,
            localX: item.localX ?? 0,
            localY: item.localY ?? 0,
            fallbackNormalizedX: item.fallbackNormalizedX ?? normalized(item.x, dimension: snapshot.contentWidth),
            fallbackNormalizedY: item.fallbackNormalizedY ?? normalized(item.y, dimension: snapshot.contentHeight),
            in: snapshot,
            knownAnchors: knownAnchors
        )
        var copy = item
        copy.x = resolved.point.x
        copy.y = resolved.point.y
        copy.resolutionState = resolved.state
        return copy
    }

    static func resolvedPosition(
        anchor: MindTreeAnnotationAnchor,
        localX: Double,
        localY: Double,
        fallbackNormalizedX: Double,
        fallbackNormalizedY: Double,
        in snapshot: MindTreeAnnotationLayoutSnapshot,
        knownAnchors: Set<MindTreeAnnotationAnchor>
    ) -> ResolvedPosition {
        if let frame = snapshot.frame(for: anchor) {
            return ResolvedPosition(
                point: CGPoint(x: frame.x + localX, y: frame.y + localY),
                state: .resolved
            )
        }

        let fallback = CGPoint(
            x: clampedNormalized(fallbackNormalizedX) * snapshot.contentWidth,
            y: clampedNormalized(fallbackNormalizedY) * snapshot.contentHeight
        )
        return ResolvedPosition(
            point: fallback,
            state: knownAnchors.contains(anchor) ? .hidden : .unresolved
        )
    }

    static func nearestAnchor(
        to point: CGPoint,
        in snapshot: MindTreeAnnotationLayoutSnapshot
    ) -> MindTreeAnnotationAnchorFrame? {
        snapshot.anchors.min { lhs, rhs in
            distanceSquared(from: point, to: lhs) < distanceSquared(from: point, to: rhs)
        }
    }

    static func mergedSnapshots(
        existing: [MindTreeAnnotationLayoutSnapshot],
        adding snapshot: MindTreeAnnotationLayoutSnapshot,
        limit: Int = 16
    ) -> [MindTreeAnnotationLayoutSnapshot] {
        let withoutDuplicate = existing.filter { $0.fingerprint != snapshot.fingerprint }
        return Array(
            (withoutDuplicate + [snapshot])
                .sorted { $0.capturedAt < $1.capturedAt }
                .suffix(max(limit, 1))
        )
    }

    static func summary(
        textItems: [MindTreeTextAnnotationItem],
        inkGroups: [MindTreeAnchoredInkGroup]
    ) -> MindTreeAnnotationProjectionSummary {
        MindTreeAnnotationProjectionSummary(
            hiddenTextCount: textItems.filter { $0.resolutionState == .hidden }.count,
            unresolvedTextCount: textItems.filter { $0.resolutionState == .unresolved }.count,
            hiddenInkCount: inkGroups.filter { $0.resolutionState == .hidden }.count,
            unresolvedInkCount: inkGroups.filter { $0.resolutionState == .unresolved }.count
        )
    }

    @MainActor
    private static func anchorFrame(for node: TreeNode) -> MindTreeAnnotationAnchorFrame? {
        let anchor: MindTreeAnnotationAnchor
        switch node.kind {
        case .root:
            anchor = .project
        case .stage:
            guard let order = node.stageOrder else { return nil }
            anchor = .stage(order: order)
        case .branchStage:
            guard let order = node.stageOrder else { return nil }
            anchor = .archivedBranch(stageOrder: order, branchVersion: node.branchVersion)
        case .question, .field, .process, .revision:
            guard let id = node.momentID, let order = node.stageOrder else { return nil }
            anchor = .moment(id: id, branchVersion: node.branchVersion, stageOrder: order)
        }

        let size = TreeNodeMetrics.size(for: node.kind)
        return MindTreeAnnotationAnchorFrame(
            anchor: anchor,
            nodeID: node.id,
            x: node.position.x,
            y: node.position.y,
            width: size.width,
            height: size.height
        )
    }

    private static func deduplicated(
        _ frames: [MindTreeAnnotationAnchorFrame]
    ) -> [MindTreeAnnotationAnchorFrame] {
        var seen = Set<MindTreeAnnotationAnchor>()
        return frames.filter { seen.insert($0.anchor).inserted }
    }

    private static func distanceSquared(
        from point: CGPoint,
        to frame: MindTreeAnnotationAnchorFrame
    ) -> Double {
        let halfWidth = max(frame.width / 2, 1)
        let halfHeight = max(frame.height / 2, 1)
        let dx = max(abs(point.x - frame.x) - halfWidth, 0)
        let dy = max(abs(point.y - frame.y) - halfHeight, 0)
        return dx * dx + dy * dy
    }

    private static func normalized(_ value: Double, dimension: Double) -> Double {
        guard dimension > 0, value.isFinite else { return 0.5 }
        return clampedNormalized(value / dimension)
    }

    private static func clampedNormalized(_ value: Double) -> Double {
        guard value.isFinite else { return 0.5 }
        return min(max(value, 0), 1)
    }
}
