import SwiftUI

enum ThinkingTreeLayoutMetrics {
    static let verticalNodeGap: CGFloat = 42
    static let branchHorizontalGap: CGFloat = 356
    static let stageCardGap: CGFloat = 60
    static let rollbackNodeGap: CGFloat = 46
    static let canvasHorizontalPadding: CGFloat = 150
    static let canvasTopPadding: CGFloat = 126
    static let canvasBottomPadding: CGFloat = 156

    static let verticalStep = TreeNodeMetrics.questionSize.height
        + verticalNodeGap
}

/// One graph-space definition shared by the embedded and full-screen tree.
/// Viewport size never changes graph coordinates, so semantic annotations
/// remain attached to the same nodes.
enum MindTreeCanonicalLayout {
    static let visibleStageLimit = 9

    static let engine = TreeLayoutEngine(
        stageSpacing: ThinkingTreeLayoutMetrics.verticalStep,
        sideBranchSpacing: ThinkingTreeLayoutMetrics.branchHorizontalGap,
        sideNodeVerticalSpacing: ThinkingTreeLayoutMetrics.verticalNodeGap,
        topPadding: ThinkingTreeLayoutMetrics.canvasTopPadding,
        bottomPadding: ThinkingTreeLayoutMetrics.canvasBottomPadding,
        contentWidth: 1_160
    )

    static func layout(
        _ data: TreeData,
        visibleStageLimit: Int,
        in viewport: CGSize
    ) -> TreeData {
        _ = visibleStageLimit
        _ = viewport
        return engine.layout(data, in: .zero)
    }
}

/// Deterministic bottom-to-top tree layout.
///
/// `layoutRank` controls vertical topology and `branchDepth` controls the
/// current active trunk. Rollback forks shift the active trunk right by one
/// column while their archived questions occupy the left column.
struct TreeLayoutEngine {
    let stageSpacing: CGFloat
    let sideBranchSpacing: CGFloat
    let sideNodeVerticalSpacing: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let contentWidth: CGFloat

    init(
        stageSpacing: CGFloat = ThinkingTreeLayoutMetrics.verticalStep,
        sideBranchSpacing: CGFloat = ThinkingTreeLayoutMetrics.branchHorizontalGap,
        sideNodeVerticalSpacing: CGFloat = ThinkingTreeLayoutMetrics.verticalNodeGap,
        topPadding: CGFloat = ThinkingTreeLayoutMetrics.canvasTopPadding,
        bottomPadding: CGFloat = ThinkingTreeLayoutMetrics.canvasBottomPadding,
        contentWidth: CGFloat = 1_160
    ) {
        self.stageSpacing = stageSpacing
        self.sideBranchSpacing = sideBranchSpacing
        self.sideNodeVerticalSpacing = sideNodeVerticalSpacing
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.contentWidth = contentWidth
    }

    func layout(_ data: TreeData, in minimumSize: CGSize) -> TreeData {
        var nodes = nodesWithFallbackRanks(data.nodes)
        let structuralIDs = Set(nodes.map(\.id))
        let structuralEdges = data.edges.filter {
            structuralIDs.contains($0.fromID)
                && structuralIDs.contains($0.toID)
        }
        let maximumRank = nodes.map(\.layoutRank).max() ?? 0
        let baseX = contentWidth / 2

        for index in nodes.indices {
            let rank = nodes[index].layoutRank
            let y = topPadding
                + CGFloat(maximumRank - rank) * stageSpacing
                + TreeNodeMetrics.questionSize.height / 2

            let column = resolvedColumn(
                for: nodes[index],
                in: nodes
            )
            nodes[index].position = CGPoint(
                x: baseX + CGFloat(column) * sideBranchSpacing,
                y: y
            )
        }

        let rawBounds = nodeBounds(nodes)
        let xShift = ThinkingTreeLayoutMetrics.canvasHorizontalPadding
            - rawBounds.minX
        let yShift = topPadding - rawBounds.minY
        for index in nodes.indices {
            nodes[index].position.x += xShift
            nodes[index].position.y += yShift
        }

        let shiftedBounds = nodeBounds(nodes)
        let width = max(
            minimumSize.width,
            shiftedBounds.maxX
                + ThinkingTreeLayoutMetrics.canvasHorizontalPadding
        )
        let height = max(
            minimumSize.height,
            shiftedBounds.maxY + bottomPadding
        )

        return TreeData(
            nodes: nodes,
            edges: structuralEdges,
            contentSize: CGSize(width: width, height: height)
        )
    }

    func minimumContentSize(maxStage: Int = 9) -> CGSize {
        _ = maxStage
        return CGSize(
            width: contentWidth,
            height: topPadding + bottomPadding
                + TreeNodeMetrics.rootSize.height
        )
    }

    private func resolvedColumn(
        for node: TreeNode,
        in nodes: [TreeNode]
    ) -> Int {
        guard node.kind == .question,
              let branchAnchorID = node.branchAnchorID,
              let fork = nodes.first(where: {
                  $0.id == branchAnchorID && $0.kind == .branchStage
              })
        else {
            return node.branchDepth
        }

        if node.isArchived {
            return min(node.branchDepth, fork.branchDepth - 1)
        }
        return max(node.branchDepth, fork.branchDepth + 1)
    }

    private func nodesWithFallbackRanks(
        _ source: [TreeNode]
    ) -> [TreeNode] {
        guard !source.contains(where: { $0.layoutRank > 0 }) else {
            return source
        }

        var nodes = source
        var rank = 0
        let stageOrders = Set(nodes.compactMap(\.stageOrder)).sorted()

        for order in stageOrders {
            let eventIndices = nodes.indices
                .filter {
                    nodes[$0].stageOrder == order
                        && nodes[$0].kind != .stage
                }
                .sorted { lhs, rhs in
                    let lhsDate = nodes[lhs].timestamp ?? .distantPast
                    let rhsDate = nodes[rhs].timestamp ?? .distantPast
                    if lhsDate != rhsDate {
                        return lhsDate < rhsDate
                    }
                    if fallbackKindRank(nodes[lhs].kind)
                        != fallbackKindRank(nodes[rhs].kind) {
                        return fallbackKindRank(nodes[lhs].kind)
                            < fallbackKindRank(nodes[rhs].kind)
                    }
                    return nodes[lhs].id < nodes[rhs].id
                }
            for index in eventIndices {
                rank += 1
                nodes[index].layoutRank = rank
            }
            if let stageIndex = nodes.firstIndex(where: {
                $0.stageOrder == order && $0.kind == .stage
            }) {
                rank += 1
                nodes[stageIndex].layoutRank = rank
            }
        }
        return nodes
    }

    private func fallbackKindRank(_ kind: TreeNodeKind) -> Int {
        switch kind {
        case .branchStage: return 0
        case .question: return 1
        case .field, .process, .revision: return 2
        case .stage: return 3
        case .root: return 4
        }
    }

    private func nodeBounds(_ nodes: [TreeNode]) -> CGRect {
        guard let first = nodes.first else {
            return .zero
        }
        var bounds = frame(for: first)
        for node in nodes.dropFirst() {
            bounds = bounds.union(frame(for: node))
        }
        return bounds
    }

    private func frame(for node: TreeNode) -> CGRect {
        let size = TreeNodeMetrics.size(for: node.kind)
        return CGRect(
            x: node.position.x - size.width / 2,
            y: node.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
