import SwiftUI

/// Stable upward-growing layout for the design-thinking projection.
struct TreeLayoutEngine {
    let stageSpacing: CGFloat
    let sideBranchSpacing: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let contentWidth: CGFloat

    init(
        stageSpacing: CGFloat = 140,
        sideBranchSpacing: CGFloat = 170,
        topPadding: CGFloat = 90,
        bottomPadding: CGFloat = 120,
        contentWidth: CGFloat = 900
    ) {
        self.stageSpacing = stageSpacing
        self.sideBranchSpacing = sideBranchSpacing
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.contentWidth = contentWidth
    }

    func layout(_ data: TreeData, in size: CGSize) -> TreeData {
        let maxStage = max(data.nodes.compactMap(\.stageOrder).max() ?? 1, 1)
        let width = max(size.width, contentWidth)
        let height = max(size.height, minimumContentSize(maxStage: maxStage).height)
        let centerX = width / 2
        let rootY = height - bottomPadding
        let contentSize = CGSize(width: width, height: height)

        let nodesByStage = Dictionary(grouping: data.nodes.filter { node in
            node.stageOrder != nil && node.kind != .stage
        }, by: { $0.stageOrder ?? 0 })

        var updatedNodes = data.nodes

        for index in updatedNodes.indices {
            switch updatedNodes[index].kind {
            case .root:
                updatedNodes[index].position = CGPoint(x: centerX, y: rootY)

            case .stage:
                guard let order = updatedNodes[index].stageOrder else { continue }
                updatedNodes[index].position = CGPoint(
                    x: centerX,
                    y: stageY(order: order, rootY: rootY)
                )

            case .field, .process, .evidence, .revision:
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
                    contentWidth: width
                )
            }
        }

        return TreeData(nodes: updatedNodes, edges: data.edges, contentSize: contentSize)
    }

    func minimumContentSize(maxStage: Int = 9) -> CGSize {
        CGSize(
            width: contentWidth,
            height: topPadding + bottomPadding + stageSpacing * CGFloat(max(maxStage, 1)) + 90
        )
    }

    private func stageY(order: Int, rootY: CGFloat) -> CGFloat {
        rootY - CGFloat(order) * stageSpacing
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
        case .field: return 0
        case .process: return 1
        case .evidence: return 2
        case .revision: return 3
        case .root, .stage: return 4
        }
    }

    private func sideNodePosition(
        node: TreeNode,
        siblingIndex: Int,
        siblingCount: Int,
        stageOrder: Int,
        centerX: CGFloat,
        rootY: CGFloat,
        contentWidth: CGFloat
    ) -> CGPoint {
        let stageY = stageY(order: stageOrder, rootY: rootY)
        let side: CGFloat = siblingIndex.isMultiple(of: 2) ? -1 : 1
        let pairIndex = CGFloat(siblingIndex / 2)
        let sideDistance = min(
            sideBranchSpacing + pairIndex * 46,
            max(120, contentWidth / 2 - 116)
        )
        let verticalBase = CGFloat((siblingIndex % 5) - 2) * 22
        let yJitter = deterministicUnit(for: node.id + "-y") * 14
        let xJitter = deterministicUnit(for: node.id + "-x") * 16
        let archivedOffset = node.isArchived ? CGFloat(28) : 0

        let x = centerX + side * (sideDistance + archivedOffset) + xJitter
        let y = stageY + verticalBase + yJitter

        return CGPoint(
            x: min(max(x, 86), contentWidth - 86),
            y: min(max(y, topPadding), rootY - 72)
        )
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
