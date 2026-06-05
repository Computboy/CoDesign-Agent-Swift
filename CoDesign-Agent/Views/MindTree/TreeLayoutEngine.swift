import SwiftUI

/// Organic tree layout engine with natural jitter and variable spacing.
/// Creates an upward-growing tree with non-uniform positioning for a natural feel.
struct TreeLayoutEngine {
    let stageHeight: CGFloat
    let branchSpacing: CGFloat
    let rootNodeHeight: CGFloat
    let topPadding: CGFloat
    let contentWidth: CGFloat

    init(
        stageHeight: CGFloat = 200,
        branchSpacing: CGFloat = 180,
        rootNodeHeight: CGFloat = 120,
        topPadding: CGFloat = 100,
        contentWidth: CGFloat = 2000
    ) {
        self.stageHeight = stageHeight
        self.branchSpacing = branchSpacing
        self.rootNodeHeight = rootNodeHeight
        self.topPadding = topPadding
        self.contentWidth = contentWidth
    }

    /// Deterministic jitter based on string hash (so same tree always looks the same)
    private func jitter(for id: String, range: CGFloat) -> CGFloat {
        let hash = abs(id.hashValue)
        return CGFloat((hash % 200) - 100) / 100.0 * range
    }

    /// Separate jitter for vertical offset
    private func verticalJitter(for id: String, range: CGFloat) -> CGFloat {
        let hash = abs(id.hashValue >> 4)
        return CGFloat((hash % 200) - 100) / 100.0 * range
    }

    func layout(_ data: TreeData, in size: CGSize) -> TreeData {
        let centerX = size.width / 2
        let bottomY = size.height - rootNodeHeight

        // Group moments by stageOrder
        var momentsByStage: [Int: [TreeNode]] = [:]
        for node in data.nodes {
            if let stageOrder = node.stageOrder {
                momentsByStage[stageOrder, default: []].append(node)
            }
        }

        // Sort moments within each stage:
        //   1. Stage nodes before field nodes
        //   2. Active before archived
        //   3. By branchVersion ascending
        for stage in momentsByStage.keys {
            momentsByStage[stage]?.sort { a, b in
                let aIsStage = a.kind == .stage
                let bIsStage = b.kind == .stage
                if aIsStage != bIsStage { return aIsStage }
                if a.isActiveBranch != b.isActiveBranch { return a.isActiveBranch }
                return a.branchVersion < b.branchVersion
            }
        }

        // Assign positions with organic jitter
        var updatedNodes = data.nodes

        for (idx, node) in updatedNodes.enumerated() {
            switch node.kind {
            case .root:
                // Root stays centered at bottom
                updatedNodes[idx].position = CGPoint(x: centerX, y: bottomY)

            case .stage, .field:
                guard let stageOrder = node.stageOrder else { continue }

                // Base Y with per-stage variation (some stages are taller/shorter)
                let stageVariation = jitter(for: "stage-\(stageOrder)", range: 12)
                let baseY = bottomY - CGFloat(stageOrder) * (stageHeight + stageVariation)

                // X position: spread siblings horizontally
                let siblings = momentsByStage[stageOrder] ?? []
                let siblingIndex = siblings.firstIndex { $0.id == node.id } ?? 0
                let totalSiblings = siblings.count

                let totalWidth = CGFloat(totalSiblings - 1) * branchSpacing
                let startX = centerX - totalWidth / 2
                let baseX = startX + CGFloat(siblingIndex) * branchSpacing

                // Add organic jitter per node
                let horizontalJitter = jitter(for: node.id, range: 22)
                let nodeVerticalJitter = verticalJitter(for: node.id, range: 14)

                // Archived nodes offset slightly more
                let archiveOffset = node.isArchived ? 18.0 : 0.0

                // Field nodes have slightly more vertical variation than stage nodes
                let fieldBonus = node.kind == .field ? verticalJitter(for: "field-\(node.id)", range: 8) : 0

                updatedNodes[idx].position = CGPoint(
                    x: baseX + horizontalJitter + archiveOffset,
                    y: baseY + nodeVerticalJitter + fieldBonus
                )
            }
        }

        return TreeData(nodes: updatedNodes, edges: data.edges)
    }

    func minimumContentSize(maxStage: Int) -> CGSize {
        let height = rootNodeHeight + CGFloat(maxStage) * stageHeight + topPadding
        return CGSize(width: contentWidth, height: height)
    }
}
