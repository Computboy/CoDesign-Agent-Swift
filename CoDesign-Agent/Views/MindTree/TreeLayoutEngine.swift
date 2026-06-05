import SwiftUI
import CoreGraphics

/// Computes positions for all nodes in an upward-growing tree layout.
///
/// Layout structure:
///   - Root node: bottom center
///   - Tree grows upward (negative Y)
///   - Stages are horizontal levels (stage 1 = lowest, stage 9 = highest)
///   - Branches spread horizontally as they grow
struct TreeLayoutEngine {

    // MARK: - Configuration

    let stageHeight: CGFloat      // vertical spacing between stages
    let branchSpacing: CGFloat    // horizontal spacing between sibling branches
    let rootNodeHeight: CGFloat   // height of root node area
    let topPadding: CGFloat       // padding above highest node

    init(
        stageHeight: CGFloat = 120,
        branchSpacing: CGFloat = 80,
        rootNodeHeight: CGFloat = 100,
        topPadding: CGFloat = 60
    ) {
        self.stageHeight = stageHeight
        self.branchSpacing = branchSpacing
        self.rootNodeHeight = rootNodeHeight
        self.topPadding = topPadding
    }

    // MARK: - Layout

    /// Computes positions for all nodes. Returns a new TreeData with positions filled in.
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

        // Sort moments within each stage by branchVersion (active first)
        for stage in momentsByStage.keys {
            momentsByStage[stage]?.sort { a, b in
                if a.isActiveBranch != b.isActiveBranch {
                    return a.isActiveBranch  // active branches first
                }
                return a.branchVersion < b.branchVersion
            }
        }

        // Assign positions
        var updatedNodes = data.nodes

        for (idx, node) in updatedNodes.enumerated() {
            switch node.kind {
            case .root:
                updatedNodes[idx].position = CGPoint(x: centerX, y: bottomY)

            case .stage, .field:
                guard let stageOrder = node.stageOrder else { continue }

                // Y position based on stage (grows upward)
                let y = bottomY - CGFloat(stageOrder) * stageHeight

                // X position: spread siblings horizontally
                let siblings = momentsByStage[stageOrder] ?? []
                let siblingIndex = siblings.firstIndex { $0.id == node.id } ?? 0
                let totalSiblings = siblings.count

                // Center the group horizontally
                let totalWidth = CGFloat(totalSiblings - 1) * branchSpacing
                let startX = centerX - totalWidth / 2
                let x = startX + CGFloat(siblingIndex) * branchSpacing

                // Offset archived branches slightly to the right
                let xOffset = node.isArchived ? 20.0 : 0.0

                updatedNodes[idx].position = CGPoint(x: x + xOffset, y: y)
            }
        }

        return TreeData(nodes: updatedNodes, edges: data.edges)
    }

    // MARK: - Canvas Size

    func minimumContentSize(maxStage: Int) -> CGSize {
        let height = rootNodeHeight + CGFloat(maxStage) * stageHeight + topPadding
        let width: CGFloat = 800  // generous width for horizontal spreading
        return CGSize(width: width, height: height)
    }
}
