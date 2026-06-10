import SwiftUI

/// Stable upward-growing layout for the design-thinking projection.
struct TreeLayoutEngine {
    let stageSpacing: CGFloat
    let sideBranchSpacing: CGFloat
    let sideNodeVerticalSpacing: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let contentWidth: CGFloat

    private var minimumSideCardSpacing: CGFloat { 108 }
    private var sideCardColumnSpacing: CGFloat { 204 }

    init(
        stageSpacing: CGFloat = 118,
        sideBranchSpacing: CGFloat = 260,
        sideNodeVerticalSpacing: CGFloat = 42,
        topPadding: CGFloat = 90,
        bottomPadding: CGFloat = 120,
        contentWidth: CGFloat = 980
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
                    siblings: siblings,
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
        let largestSideCardRowCount = nodesByStage.values
            .map { maxSideCardRows(in: $0) }
            .max() ?? 0

        guard largestSideCardRowCount > 1 else { return stageSpacing }

        let requiredSpacing = CGFloat(largestSideCardRowCount - 1) * minimumSideCardSpacing + 188
        return max(stageSpacing, requiredSpacing)
    }

    private func sortedSideNodes(_ nodes: [TreeNode]) -> [TreeNode] {
        nodes.sorted { lhs, rhs in
            if let lhsDate = lhs.timestamp, let rhsDate = rhs.timestamp, lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
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
        siblings: [TreeNode],
        stageOrder: Int,
        centerX: CGFloat,
        rootY: CGFloat,
        stageSpacing: CGFloat,
        contentWidth: CGFloat
    ) -> CGPoint {
        let fromY: CGFloat
        if stageOrder == 1 {
            fromY = rootY
        } else {
            fromY = stageY(order: stageOrder - 1, rootY: rootY, stageSpacing: stageSpacing)
        }
        let toY = stageY(order: stageOrder, rootY: rootY, stageSpacing: stageSpacing)
        let corridorHeight = max(abs(fromY - toY), stageSpacing)
        let yJitter = deterministicUnit(for: node.id + "-y") * 2

        if node.kind == .question && !node.isArchived {
            let questionNodes = siblings.filter { $0.kind == .question && !$0.isArchived }
            let questionIndex = questionNodes.firstIndex(where: { $0.id == node.id }) ?? 0
            let fraction = CGFloat(questionIndex + 1) / CGFloat(max(questionNodes.count + 1, 2))
            return CGPoint(
                x: centerX,
                y: min(max(fromY - corridorHeight * fraction + yJitter, topPadding + 44), rootY - 116)
            )
        }

        let sideNodes = siblings.filter { $0.kind != .question || $0.isArchived }
        let sideIndex = sideNodes.firstIndex(where: { $0.id == node.id }) ?? siblingIndex
        let side = preferredSide(for: node, ordinal: sideIndex)
        let sameSideNodes = sideNodes.enumerated()
            .filter { preferredSide(for: $0.element, ordinal: $0.offset) == side }
        let sameSideOrdinal = sameSideNodes.firstIndex { $0.element.id == node.id } ?? 0
        let laneCount = laneCount(forSideCardCount: sameSideNodes.count)
        let laneIndex = sameSideOrdinal % laneCount
        let rowIndex = sameSideOrdinal / laneCount
        let rowCount = max(rowsNeeded(forSideCardCount: sameSideNodes.count, laneIndex: laneIndex), 1)
        let safeTopY = min(fromY, toY) + 76
        let safeBottomY = max(fromY, toY) - 112
        let rowSpacing = rowCount > 1
            ? max(minimumSideCardSpacing, (safeBottomY - safeTopY) / CGFloat(rowCount - 1))
            : 0
        let sideDistance = min(
            sideBranchSpacing,
            max(112, contentWidth / 2 - 112 - CGFloat(laneCount - 1) * sideCardColumnSpacing)
        )
        let xJitter = deterministicUnit(for: node.id + "-x") * 4
        let archivedOffset = node.isArchived ? CGFloat(24) : 0

        let x = centerX + side * (sideDistance + CGFloat(laneIndex) * sideCardColumnSpacing + archivedOffset) + xJitter
        let y = rowCount == 1
            ? (safeTopY + safeBottomY) / 2 + yJitter
            : safeTopY + CGFloat(rowIndex) * rowSpacing + yJitter

        return CGPoint(
            x: min(max(x, 86), contentWidth - 86),
            y: min(max(y, topPadding + 44), rootY - 116)
        )
    }

    private func maxSideCardRows(in nodes: [TreeNode]) -> Int {
        let sideNodes = sortedSideNodes(nodes).filter { $0.kind != .question }
        var left = 0
        var right = 0

        for (ordinal, node) in sideNodes.enumerated() {
            if preferredSide(for: node, ordinal: ordinal) < 0 {
                left += 1
            } else {
                right += 1
            }
        }

        return max(rowsNeeded(forSideCardCount: left), rowsNeeded(forSideCardCount: right))
    }

    private func laneCount(forSideCardCount count: Int) -> Int {
        count > 2 && contentWidth >= 1_080 ? 2 : 1
    }

    private func rowsNeeded(forSideCardCount count: Int) -> Int {
        guard count > 0 else { return 0 }
        let lanes = laneCount(forSideCardCount: count)
        return Int(ceil(Double(count) / Double(lanes)))
    }

    private func rowsNeeded(forSideCardCount count: Int, laneIndex: Int) -> Int {
        guard count > laneIndex else { return 0 }
        let lanes = laneCount(forSideCardCount: count)
        return Int(ceil(Double(count - laneIndex) / Double(lanes)))
    }

    private func preferredSide(for node: TreeNode, ordinal: Int) -> CGFloat {
        switch node.kind {
        case .evidence, .process:
            return ordinal.isMultiple(of: 2) ? 1 : -1
        case .field, .revision:
            return ordinal.isMultiple(of: 2) ? -1 : 1
        case .question:
            return node.isArchived ? 1 : 0
        case .root, .stage:
            return 0
        }
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
