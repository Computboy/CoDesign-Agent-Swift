import SwiftUI
import CoreGraphics

/// Computes positions for all nodes in a radial tree layout.
///
/// Layout structure:
///   - Root node: center of canvas
///   - Stage nodes (1-9): ring around root at `stageRadius`
///   - Field nodes: fan outward from parent stage at `fieldRadius`
struct TreeLayoutEngine {

    // MARK: - Configuration

    let stageRadius: CGFloat
    let fieldRadius: CGFloat
    let stageFanDegrees: CGFloat

    init(
        stageRadius: CGFloat = 160,
        fieldRadius: CGFloat = 300,
        stageFanDegrees: CGFloat = 22
    ) {
        self.stageRadius = stageRadius
        self.fieldRadius = fieldRadius
        self.stageFanDegrees = stageFanDegrees
    }

    // MARK: - Layout

    /// Computes positions for all nodes. Returns a new `TreeData` with positions filled in.
    func layout(_ data: TreeData, in size: CGSize) -> TreeData {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let stageCount = 9

        var stagePositions: [Int: CGPoint] = [:]
        var stageAngles: [Int: CGFloat] = [:]

        for i in 0..<stageCount {
            let order = i + 1
            let angle = -90.0 + CGFloat(i) * (360.0 / CGFloat(stageCount))
            let rad = angle * .pi / 180
            let pos = CGPoint(
                x: center.x + stageRadius * cos(rad),
                y: center.y + stageRadius * sin(rad)
            )
            stagePositions[order] = pos
            stageAngles[order] = angle
        }

        // Group field nodes by their parent stage
        var fieldNodesByStage: [Int: [(index: Int, node: TreeNode)]] = [:]
        for (idx, node) in data.nodes.enumerated() {
            if node.kind == .field, let stageOrder = node.stageOrder {
                fieldNodesByStage[stageOrder, default: []].append((idx, node))
            }
        }

        // Apply positions
        var updatedNodes = data.nodes

        for (idx, node) in updatedNodes.enumerated() {
            switch node.kind {
            case .root:
                updatedNodes[idx].position = center

            case .stage:
                if let order = node.stageOrder, let pos = stagePositions[order] {
                    updatedNodes[idx].position = pos
                }

            case .field:
                guard let stageOrder = node.stageOrder,
                      let parentAngle = stageAngles[stageOrder],
                      let siblings = fieldNodesByStage[stageOrder] else {
                    continue
                }

                let siblingIndex = siblings.firstIndex { $0.index == idx } ?? 0
                let totalSiblings = siblings.count

                let fanRange = stageFanDegrees * 2
                let fieldAngle: CGFloat
                if totalSiblings == 1 {
                    fieldAngle = parentAngle
                } else {
                    let t = CGFloat(siblingIndex) / CGFloat(totalSiblings - 1)
                    fieldAngle = parentAngle - stageFanDegrees + t * fanRange
                }

                let rad = fieldAngle * .pi / 180
                updatedNodes[idx].position = CGPoint(
                    x: center.x + fieldRadius * cos(rad),
                    y: center.y + fieldRadius * sin(rad)
                )
            }
        }

        return TreeData(nodes: updatedNodes, edges: data.edges)
    }

    // MARK: - Canvas Size

    func minimumContentSize() -> CGSize {
        let maxRadius = fieldRadius + 60
        let diameter = maxRadius * 2
        return CGSize(width: diameter, height: diameter)
    }
}
