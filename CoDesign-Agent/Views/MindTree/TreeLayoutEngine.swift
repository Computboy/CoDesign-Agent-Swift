import SwiftUI

/// One graph-space definition shared by the embedded and full-screen tree.
/// Display surfaces may choose different viewport scales and offsets, but they
/// must never relayout nodes with different spacing because annotations are
/// stored in this graph coordinate space.
enum MindTreeCanonicalLayout {
    static let visibleStageLimit = 9
    static let evidenceLimit = 3

    static let engine = TreeLayoutEngine(
        stageSpacing: 164,
        sideBranchSpacing: 430,
        sideNodeVerticalSpacing: 56,
        topPadding: 126,
        bottomPadding: 170,
        contentWidth: 1_800
    )

    static func layout(
        _ data: TreeData,
        visibleStageLimit: Int,
        in viewport: CGSize
    ) -> TreeData {
        // The viewport is intentionally not used to derive graph geometry.
        // It is accepted so tests can enforce that compact and full surfaces
        // receive identical graph coordinates.
        _ = viewport
        return engine.layout(
            data,
            in: engine.minimumContentSize(maxStage: visibleStageLimit)
        )
    }
}

/// Stable upward-growing layout for the design-thinking projection.
struct TreeLayoutEngine {
    let stageSpacing: CGFloat
    let sideBranchSpacing: CGFloat
    let sideNodeVerticalSpacing: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let contentWidth: CGFloat

    private var minimumSideCardSpacing: CGFloat { 176 }
    private var sideCardColumnSpacing: CGFloat { 286 }
    private var collisionPadding: CGFloat { 18 }
    private var archivedTimelineTopOffset: CGFloat { 154 }
    private var archivedTimelineRowSpacing: CGFloat { 176 }
    private var archivedTimelineHalfWidth: CGFloat { questionNodeWidth / 2 }
    private var archivedBranchHalfWidth: CGFloat { TreeNodeMetrics.stageSize.width / 2 }
    private var archivedBranchReservedWidth: CGFloat { 430 }
    private var archivedBranchGapFromMain: CGFloat { 280 }
    private var activeQuestionRowSpacing: CGFloat { 88 }
    private var archivedQuestionRowSpacing: CGFloat { 108 }
    private var questionNodeWidth: CGFloat { TreeNodeMetrics.questionSize.width }
    private var questionNodeHeight: CGFloat { TreeNodeMetrics.questionSize.height }

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
        let hasArchivedBranch = data.nodes.contains { $0.kind == .branchStage }
        let width = max(size.width, contentWidth + (hasArchivedBranch ? archivedBranchReservedWidth : 0))
        let mainContentWidth = hasArchivedBranch ? max(contentWidth, width - archivedBranchReservedWidth) : width
        let nodesByStage = Dictionary(grouping: data.nodes.filter { node in
            node.stageOrder != nil && node.kind != .stage && node.kind != .branchStage
        }, by: { $0.stageOrder ?? 0 })
        let transitionSpacings = transitionSpacings(maxStage: maxStage, nodesByStage: nodesByStage)
        let height = max(size.height, minimumContentSize(transitionSpacings: transitionSpacings).height)
        let centerX = mainContentWidth / 2
        let archivedBranchX = archivedBranchX(
            centerX: centerX,
            contentWidth: width,
            usesSecondaryRightLane: usesSecondaryRightLane(nodesByStage: nodesByStage)
        )
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
                    y: stageY(order: order, rootY: rootY, transitionSpacings: transitionSpacings)
                )

            case .branchStage:
                guard let order = updatedNodes[index].stageOrder else { continue }
                updatedNodes[index].position = CGPoint(
                    x: archivedBranchX,
                    y: stageY(order: order, rootY: rootY, transitionSpacings: transitionSpacings)
                )

            case .question, .field, .process, .evidence, .revision:
                guard let order = updatedNodes[index].stageOrder else { continue }
                let siblings = sortedSideNodes(
                    updatedNodes.filter {
                        $0.stageOrder == order &&
                        $0.kind != .stage &&
                        $0.kind != .branchStage
                    }
                )
                guard let siblingIndex = siblings.firstIndex(where: { $0.id == updatedNodes[index].id }) else {
                    continue
                }

                updatedNodes[index].position = sideNodePosition(
                    node: updatedNodes[index],
                    siblingIndex: siblingIndex,
                    siblings: siblings,
                    centerX: centerX,
                    fromY: transitionStartY(order: order, rootY: rootY, transitionSpacings: transitionSpacings),
                    toY: stageY(order: order, rootY: rootY, transitionSpacings: transitionSpacings),
                    contentWidth: width,
                    mainContentWidth: mainContentWidth,
                    archivedBranchX: archivedBranchX
                )
            }
        }

        let resolvedNodes = resolveCollisions(
            in: updatedNodes,
            centerX: centerX,
            rootY: rootY,
            transitionSpacings: transitionSpacings,
            contentSize: contentSize
        )

        return TreeData(nodes: resolvedNodes, edges: data.edges, contentSize: contentSize)
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

    private func minimumContentSize(transitionSpacings: [Int: CGFloat]) -> CGSize {
        CGSize(
            width: contentWidth,
            height: topPadding + bottomPadding + transitionSpacings.values.reduce(0, +) + 90
        )
    }

    private func transitionSpacings(maxStage: Int, nodesByStage: [Int: [TreeNode]]) -> [Int: CGFloat] {
        Dictionary(uniqueKeysWithValues: (1...max(maxStage, 1)).map { order in
            (order, transitionSpacing(for: nodesByStage[order] ?? []))
        })
    }

    private func transitionSpacing(for nodes: [TreeNode]) -> CGFloat {
        guard !nodes.isEmpty else { return stageSpacing }

        let sideRowCount = maxSideCardRows(in: nodes)
        let questionCount = nodes.filter { $0.kind == .question }.count
        let archivedTimelineRowCount = maxArchivedTimelineRows(in: nodes)
        let expandedMinimum = stageSpacing + 124
        let requiredSideSpacing = sideRowCount > 0
            ? CGFloat(max(sideRowCount - 1, 0)) * minimumSideCardSpacing + 306
            : 0
        let requiredQuestionSpacing = questionCount > 0
            ? CGFloat(max(questionCount - 1, 0)) * activeQuestionRowSpacing + questionNodeHeight + 210
            : 0
        let requiredTimelineSpacing = archivedTimelineRowCount > 0
            ? archivedTimelineTopOffset + CGFloat(max(archivedTimelineRowCount - 1, 0)) * archivedTimelineRowSpacing + 282
            : 0

        return max(stageSpacing, expandedMinimum, requiredSideSpacing, requiredQuestionSpacing, requiredTimelineSpacing)
    }

    private func stageY(order: Int, rootY: CGFloat, transitionSpacings: [Int: CGFloat]) -> CGFloat {
        rootY - transitionSpacings
            .filter { $0.key <= order }
            .map(\.value)
            .reduce(0, +)
    }

    private func transitionStartY(order: Int, rootY: CGFloat, transitionSpacings: [Int: CGFloat]) -> CGFloat {
        guard order > 1 else { return rootY }
        return stageY(order: order - 1, rootY: rootY, transitionSpacings: transitionSpacings)
    }

    private func sortedSideNodes(_ nodes: [TreeNode]) -> [TreeNode] {
        nodes.sorted { lhs, rhs in
            if lhs.branchAnchorID != rhs.branchAnchorID {
                return (lhs.branchAnchorID ?? "") < (rhs.branchAnchorID ?? "")
            }
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
        case .branchStage: return 5
        case .root, .stage: return 6
        }
    }

    private func sideNodePosition(
        node: TreeNode,
        siblingIndex: Int,
        siblings: [TreeNode],
        centerX: CGFloat,
        fromY: CGFloat,
        toY: CGFloat,
        contentWidth: CGFloat,
        mainContentWidth: CGFloat,
        archivedBranchX: CGFloat
    ) -> CGPoint {
        let yJitter = deterministicUnit(for: node.id + "-y") * 1.5

        if isArchivedStageTimelineNode(node), let anchorID = node.branchAnchorID {
            let timelineNodes = sortedSideNodes(siblings.filter {
                $0.branchAnchorID == anchorID && isArchivedStageTimelineNode($0)
            })
            let ordinal = timelineNodes.firstIndex { $0.id == node.id } ?? 0
            let x = timelineColumnX(archivedBranchX: archivedBranchX, contentWidth: contentWidth)
            let y = toY + archivedTimelineTopOffset + CGFloat(ordinal) * archivedTimelineRowSpacing

            return CGPoint(
                x: x,
                y: min(max(y, topPadding + 62), fromY - 112)
            )
        }

        if node.kind == .question && node.isArchived, let anchorID = node.branchAnchorID {
            let anchorY = siblings.first { $0.id == anchorID }?.position.y
            let anchoredQuestions = siblings.filter {
                $0.kind == .question &&
                $0.isArchived &&
                $0.branchAnchorID == anchorID
            }
            let ordinal = anchoredQuestions.firstIndex { $0.id == node.id } ?? 0
            let rowOffset = CGFloat(ordinal) * archivedQuestionRowSpacing
            let baseX = archivedBranchX
            let halfWidth = estimatedHalfWidth(for: node)
            let baseY: CGFloat
            if anchorID.hasPrefix("branch-stage-") {
                baseY = toY - 92 - rowOffset
            } else {
                baseY = (anchorY ?? ((fromY + toY) / 2)) + rowOffset
            }

            return CGPoint(
                x: min(max(baseX, halfWidth + 28), contentWidth - halfWidth - 28),
                y: min(max(baseY + yJitter, topPadding + 62), fromY - 144)
            )
        }

        if node.kind == .question && !node.isArchived {
            let questionNodes = siblings.filter { $0.kind == .question && !$0.isArchived }
            let questionIndex = questionNodes.firstIndex(where: { $0.id == node.id }) ?? 0
            let safeTopY = min(fromY, toY) + questionNodeHeight / 2 + 58
            let safeBottomY = max(fromY, toY) - questionNodeHeight / 2 - 72
            let blockHeight = CGFloat(max(questionNodes.count - 1, 0)) * activeQuestionRowSpacing
            let proposedFirstY = (safeTopY + safeBottomY - blockHeight) / 2
            let maxFirstY = max(safeTopY, safeBottomY - blockHeight)
            let firstY = min(max(proposedFirstY, safeTopY), maxFirstY)
            let y = firstY + CGFloat(questionIndex) * activeQuestionRowSpacing + yJitter

            return CGPoint(
                x: centerX,
                y: min(max(y, topPadding + questionNodeHeight / 2 + 24), fromY - questionNodeHeight / 2 - 74)
            )
        }

        let sideNodes = siblings.filter { $0.kind != .question || ($0.isArchived && $0.branchAnchorID == nil) }
        let sideIndex = sideNodes.firstIndex(where: { $0.id == node.id }) ?? siblingIndex
        let side = preferredSide(for: node, ordinal: sideIndex)
        let sameSideNodes = sideNodes.enumerated()
            .filter { preferredSide(for: $0.element, ordinal: $0.offset) == side }
        let sameSideOrdinal = sameSideNodes.firstIndex { $0.element.id == node.id } ?? 0
        let laneCount = laneCount(forSideCardCount: sameSideNodes.count)
        let laneIndex = sameSideOrdinal % laneCount
        let rowIndex = sameSideOrdinal / laneCount
        let rowCount = max(rowsNeeded(forSideCardCount: sameSideNodes.count, laneIndex: laneIndex), 1)
        let safeTopY = min(fromY, toY) + 118
        let safeBottomY = max(fromY, toY) - 154
        let rowSpacing = rowCount > 1
            ? max(minimumSideCardSpacing, (safeBottomY - safeTopY) / CGFloat(rowCount - 1))
            : 0
        let sideDistance = min(
            sideBranchSpacing,
            max(168, mainContentWidth / 2 - 146 - CGFloat(laneCount - 1) * sideCardColumnSpacing)
        )
        let xJitter = deterministicUnit(for: node.id + "-x") * 2
        let archivedOffset = node.isArchived ? CGFloat(28) : 0

        let x = centerX + side * (sideDistance + CGFloat(laneIndex) * sideCardColumnSpacing + archivedOffset) + xJitter
        let y = rowCount == 1
            ? (safeTopY + safeBottomY) / 2 + yJitter
            : safeTopY + CGFloat(rowIndex) * rowSpacing + yJitter
        let halfWidth = estimatedHalfWidth(for: node)

        return CGPoint(
            x: min(max(x, halfWidth + 28), mainContentWidth - halfWidth - 28),
            y: min(max(y, topPadding + 62), fromY - 144)
        )
    }

    private func maxSideCardRows(in nodes: [TreeNode]) -> Int {
        let sideNodes = sortedSideNodes(nodes).filter {
            !isArchivedStageTimelineNode($0) &&
            ($0.kind != .question || ($0.isArchived && $0.branchAnchorID == nil))
        }
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

    private func maxArchivedTimelineRows(in nodes: [TreeNode]) -> Int {
        let grouped = Dictionary(grouping: nodes.filter(isArchivedStageTimelineNode), by: { $0.branchAnchorID ?? "" })
        return grouped.values.map(\.count).max() ?? 0
    }

    private func laneCount(forSideCardCount count: Int) -> Int {
        count > 3 && contentWidth >= 1_160 ? 2 : 1
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

    private func usesSecondaryRightLane(nodesByStage: [Int: [TreeNode]]) -> Bool {
        nodesByStage.values.contains { nodes in
            let sideNodes = sortedSideNodes(nodes).filter {
                !isArchivedStageTimelineNode($0) &&
                ($0.kind != .question || ($0.isArchived && $0.branchAnchorID == nil))
            }

            let rightSideCount = sideNodes.enumerated().filter { offset, node in
                preferredSide(for: node, ordinal: offset) > 0
            }.count

            return laneCount(forSideCardCount: rightSideCount) > 1
        }
    }

    private func resolveCollisions(
        in nodes: [TreeNode],
        centerX: CGFloat,
        rootY: CGFloat,
        transitionSpacings: [Int: CGFloat],
        contentSize: CGSize
    ) -> [TreeNode] {
        var resolved = nodes
        var occupied: [CGRect] = []

        let staticIndices = resolved.indices.filter { index in
            switch resolved[index].kind {
            case .root, .stage, .branchStage:
                return true
            case .question, .field, .process, .evidence, .revision:
                return false
            }
        }
        let staticIndexSet = Set(staticIndices)
        for index in staticIndices {
            occupied.append(collisionRect(for: resolved[index], at: resolved[index].position))
        }

        let movableIndices = resolved.indices
            .filter { !staticIndexSet.contains($0) }
            .sorted { lhs, rhs in
                collisionSortKey(resolved[lhs]) < collisionSortKey(resolved[rhs])
            }

        for index in movableIndices {
            let node = resolved[index]
            let yRange = collisionYRange(
                for: node,
                rootY: rootY,
                transitionSpacings: transitionSpacings,
                contentHeight: contentSize.height
            )
            let candidates = collisionCandidates(
                for: node,
                base: node.position,
                centerX: centerX,
                yRange: yRange,
                contentWidth: contentSize.width
            )

            let position = candidates.first { candidate in
                let rect = collisionRect(for: node, at: candidate)
                return !occupied.contains { $0.intersects(rect) }
            } ?? candidates.first ?? node.position

            resolved[index].position = position
            occupied.append(collisionRect(for: node, at: position))
        }

        return resolved
    }

    private func collisionSortKey(_ node: TreeNode) -> String {
        let stage = String(format: "%02d", node.stageOrder ?? 0)

        if isArchivedStageTimelineNode(node) {
            let time = String(format: "%.6f", node.timestamp?.timeIntervalSinceReferenceDate ?? 0)
            return "\(stage)-1-timeline-\(node.branchAnchorID ?? "")-\(time)-\(node.id)"
        }

        let branch = node.isActiveBranch ? "0" : "1"
        let kind = String(format: "%02d", kindRank(node.kind))
        let time = String(format: "%.6f", node.timestamp?.timeIntervalSinceReferenceDate ?? 0)
        return "\(stage)-\(branch)-\(kind)-\(time)-\(node.id)"
    }

    private func collisionCandidates(
        for node: TreeNode,
        base: CGPoint,
        centerX: CGFloat,
        yRange: ClosedRange<CGFloat>,
        contentWidth: CGFloat
    ) -> [CGPoint] {
        let verticalStep = estimatedSize(for: node).height + collisionPadding
        let horizontalStep = estimatedSize(for: node).width + collisionPadding + 24
        let yOffsets = isArchivedStageTimelineNode(node)
            ? forwardOffsets(step: max(verticalStep, archivedTimelineRowSpacing), count: 9)
            : alternatingOffsets(step: verticalStep, count: 7)
        let xOffsets = isArchivedStageTimelineNode(node)
            ? [CGFloat(0)]
            : horizontalOffsets(for: node, baseX: base.x, centerX: centerX, step: horizontalStep)
        let halfWidth = estimatedHalfWidth(for: node)

        var candidates: [(point: CGPoint, score: CGFloat)] = []
        for yOffset in yOffsets {
            for xOffset in xOffsets {
                let x = min(max(base.x + xOffset, halfWidth + 28), contentWidth - halfWidth - 28)
                let y = min(max(base.y + yOffset, yRange.lowerBound), yRange.upperBound)
                let score = abs(yOffset) + abs(xOffset) * 1.18
                candidates.append((CGPoint(x: x, y: y), score))
            }
        }

        var seen = Set<String>()
        return candidates
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                if lhs.point.y != rhs.point.y { return lhs.point.y < rhs.point.y }
                return lhs.point.x < rhs.point.x
            }
            .filter { candidate in
                let key = "\(Int(candidate.point.x.rounded()))-\(Int(candidate.point.y.rounded()))"
                return seen.insert(key).inserted
            }
            .map(\.point)
    }

    private func alternatingOffsets(step: CGFloat, count: Int) -> [CGFloat] {
        var result: [CGFloat] = [0]
        for index in 1...count {
            let value = step * CGFloat(index)
            result.append(-value)
            result.append(value)
        }
        return result
    }

    private func forwardOffsets(step: CGFloat, count: Int) -> [CGFloat] {
        (0...count).map { CGFloat($0) * step }
    }

    private func horizontalOffsets(
        for node: TreeNode,
        baseX: CGFloat,
        centerX: CGFloat,
        step: CGFloat
    ) -> [CGFloat] {
        let direction: CGFloat
        if node.kind == .question && node.isArchived {
            direction = 1
        } else if baseX < centerX {
            direction = -1
        } else if baseX > centerX {
            direction = 1
        } else {
            direction = deterministicUnit(for: node.id + "-side") >= 0 ? 1 : -1
        }

        return [
            0,
            direction * step,
            -direction * step,
            direction * step * 2,
            -direction * step * 2
        ]
    }

    private func collisionYRange(
        for node: TreeNode,
        rootY: CGFloat,
        transitionSpacings: [Int: CGFloat],
        contentHeight: CGFloat
    ) -> ClosedRange<CGFloat> {
        let halfHeight = estimatedSize(for: node).height / 2
        let globalLower = topPadding + halfHeight + 24
        let globalUpper = contentHeight - bottomPadding - halfHeight - 24

        guard let order = node.stageOrder else {
            return globalLower...max(globalLower, globalUpper)
        }

        let fromY = transitionStartY(order: order, rootY: rootY, transitionSpacings: transitionSpacings)
        let toY = stageY(order: order, rootY: rootY, transitionSpacings: transitionSpacings)
        let lower = max(min(fromY, toY) + halfHeight + 40, globalLower)
        let upper = min(max(fromY, toY) - halfHeight - 40, globalUpper)

        if lower <= upper {
            return lower...upper
        }
        return globalLower...max(globalLower, globalUpper)
    }

    private func collisionRect(for node: TreeNode, at point: CGPoint) -> CGRect {
        let size = estimatedSize(for: node)
        return CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        ).insetBy(dx: -collisionPadding, dy: -collisionPadding)
    }

    private func preferredSide(for node: TreeNode, ordinal: Int) -> CGFloat {
        switch node.kind {
        case .evidence, .process:
            return 1
        case .field, .revision:
            return -1
        case .question:
            return node.isArchived ? 1 : 0
        case .branchStage:
            return 1
        case .root, .stage:
            return 0
        }
    }

    private func estimatedHalfWidth(for node: TreeNode) -> CGFloat {
        TreeNodeMetrics.size(for: node.kind).width / 2
    }

    private func estimatedSize(for node: TreeNode) -> CGSize {
        TreeNodeMetrics.size(for: node.kind)
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

    private func archivedBranchX(
        centerX: CGFloat,
        contentWidth: CGFloat,
        usesSecondaryRightLane: Bool
    ) -> CGFloat {
        let laneOffset = usesSecondaryRightLane ? sideCardColumnSpacing : 0
        let preferredX = centerX + sideBranchSpacing + laneOffset + archivedBranchGapFromMain
        let minimumX = centerX + sideBranchSpacing + archivedBranchGapFromMain
        let maximumX = contentWidth - max(archivedTimelineHalfWidth, archivedBranchHalfWidth) - 28

        return min(max(preferredX, minimumX), maximumX)
    }

    private func timelineColumnX(archivedBranchX: CGFloat, contentWidth: CGFloat) -> CGFloat {
        min(
            max(archivedBranchX, archivedTimelineHalfWidth + 28),
            contentWidth - archivedTimelineHalfWidth - 28
        )
    }

    private func isArchivedStageTimelineNode(_ node: TreeNode) -> Bool {
        guard node.isArchived,
              let anchorID = node.branchAnchorID,
              anchorID.hasPrefix("branch-stage-") else {
            return false
        }
        return node.kind != .branchStage && node.kind != .root && node.kind != .stage
    }
}
