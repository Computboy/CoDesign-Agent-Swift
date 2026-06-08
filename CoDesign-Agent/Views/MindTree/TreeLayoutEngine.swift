import SwiftUI

/// Stable upward-growing layout for the design-thinking projection.
struct TreeLayoutEngine {
    let stageSpacing: CGFloat
    let sideBranchSpacing: CGFloat
    let sideNodeVerticalSpacing: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let contentWidth: CGFloat

    init(
        stageSpacing: CGFloat = 140,
        sideBranchSpacing: CGFloat = 170,
        sideNodeVerticalSpacing: CGFloat = 34,
        topPadding: CGFloat = 90,
        bottomPadding: CGFloat = 120,
        contentWidth: CGFloat = 900
    ) {
        self.stageSpacing = stageSpacing
        self.sideBranchSpacing = sideBranchSpacing
        self.sideNodeVerticalSpacing = sideNodeVerticalSpacing
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.contentWidth = contentWidth
    }

    func layout(_ data: TreeData, in size: CGSize) -> TreeData {
        let maxStage = max(data.nodes.compactMap(\.stageOrder).max() ?? 1, 1)
        let width = max(size.width, contentWidth)
        let nodesByStage = Dictionary(grouping: data.nodes.filter { node in
            node.stageOrder != nil && node.kind != .stage
        }, by: { $0.stageOrder ?? 0 })
        let effectiveStageSpacing = effectiveStageSpacing(for: nodesByStage)
        let height = max(size.height, minimumContentSize(maxStage: maxStage, stageSpacing: effectiveStageSpacing).height)
        let centerX = width / 2
        let rootY = height - bottomPadding
        let contentSize = CGSize(width: width, height: height)

        var updatedNodes = data.nodes

        for index in updatedNodes.indices {
            switch updatedNodes[index].kind {
            case .root:
                updatedNodes[index].position = CGPoint(x: centerX, y: rootY)

            case .stage:
                guard let order = updatedNodes[index].stageOrder else { continue }
                updatedNodes[index].position = CGPoint(
                    x: centerX,
                    y: stageY(order: order, rootY: rootY, stageSpacing: effectiveStageSpacing)
                )

            case .question, .field, .process, .evidence, .revision:
                guard let order = updatedNodes[index].stageOrder else { continue }
                let siblings = sortedSideNodes(nodesByStage[order] ?? [])
                guard let siblingIndex = siblings.firstIndex(where: { $0.id == updatedNodes[index].id }) else {
                    continue
                }

                updatedNodes[index].position = sideNodePosition(
                    node: updatedNodes[index],
                    siblingIndex: siblingIndex,
                    siblingCount: siblings.count,
                    stageOrder: order,
                    centerX: centerX,
                    rootY: rootY,
                    stageSpacing: effectiveStageSpacing,
                    contentWidth: width
                )
            }
        }

        return TreeData(nodes: updatedNodes, edges: data.edges, contentSize: contentSize)
    }

    func minimumContentSize(maxStage: Int = 9) -> CGSize {
        minimumContentSize(maxStage: maxStage, stageSpacing: stageSpacing)
    }

    private func minimumContentSize(maxStage: Int, stageSpacing: CGFloat) -> CGSize {
        CGSize(
            width: contentWidth,
            height: topPadding + bottomPadding + stageSpacing * CGFloat(max(maxStage, 1)) + 90
        )
    }

    private func stageY(order: Int, rootY: CGFloat, stageSpacing: CGFloat) -> CGFloat {
        rootY - CGFloat(order) * stageSpacing
    }

    private func effectiveStageSpacing(for nodesByStage: [Int: [TreeNode]]) -> CGFloat {
        let maxSideCount = nodesByStage.values
            .map { nodes in
                let sideCounts = balancedSideCounts(for: nodes.count)
                return max(sideCounts.left, sideCounts.right)
            }
            .max() ?? 0

        guard maxSideCount > 1 else { return stageSpacing }

        let estimatedNodeHeight: CGFloat = 86
        let stackHeight = estimatedNodeHeight + CGFloat(maxSideCount - 1) * sideNodeVerticalSpacing
        return max(stageSpacing, stackHeight + 56)
    }

    private func sortedSideNodes(_ nodes: [TreeNode]) -> [TreeNode] {
        nodes.sorted { lhs, rhs in
            if lhs.isActiveBranch != rhs.isActiveBranch {
                return lhs.isActiveBranch
            }
            if kindRank(lhs.kind) != kindRank(rhs.kind) {
                return kindRank(lhs.kind) < kindRank(rhs.kind)
            }
            if lhs.id != rhs.id {
                return lhs.id < rhs.id
            }
            return lhs.content < rhs.content
        }
    }

    private func kindRank(_ kind: TreeNodeKind) -> Int {
        switch kind {
        case .question: return 0
        case .field: return 1
        case .process: return 2
        case .evidence: return 3
        case .revision: return 4
        case .root, .stage: return 5
        }
    }

    private func sideNodePosition(
        node: TreeNode,
        siblingIndex: Int,
        siblingCount: Int,
        stageOrder: Int,
        centerX: CGFloat,
        rootY: CGFloat,
        stageSpacing: CGFloat,
        contentWidth: CGFloat
    ) -> CGPoint {
        let stageY = stageY(order: stageOrder, rootY: rootY, stageSpacing: stageSpacing)
        let side: CGFloat = siblingIndex.isMultiple(of: 2) ? -1 : 1
        let sideIndex = siblingIndex / 2
        let sideCount = siblingIndex.isMultiple(of: 2)
            ? balancedSideCounts(for: siblingCount).left
            : balancedSideCounts(for: siblingCount).right
        let sideDistance = min(sideBranchSpacing, max(120, contentWidth / 2 - 116))
        let stackOffset = CGFloat(sideIndex) * sideNodeVerticalSpacing
            - CGFloat(max(sideCount - 1, 0)) * sideNodeVerticalSpacing / 2
        let yJitter = deterministicUnit(for: node.id + "-y") * 4
        let xJitter = deterministicUnit(for: node.id + "-x") * 6
        let archivedOffset = node.isArchived ? CGFloat(28) : 0

        let x = centerX + side * (sideDistance + archivedOffset) + xJitter
        let y = stageY + stackOffset + yJitter

        return CGPoint(
            x: min(max(x, 86), contentWidth - 86),
            y: min(max(y, topPadding + 44), rootY - 116)
        )
    }

    private func balancedSideCounts(for count: Int) -> (left: Int, right: Int) {
        (left: (count + 1) / 2, right: count / 2)
    }

    /// Stable deterministic pseudo-random value in -1...1.
    private func deterministicUnit(for id: String) -> CGFloat {
        var hash: UInt64 = 1469598103934665603
        for scalar in id.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash &*= 1099511628211
        }
        let bucket = Int(hash % 2001) - 1000
        return CGFloat(bucket) / 1000
    }
}
