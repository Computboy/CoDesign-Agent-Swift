import SwiftUI

// MARK: - Node Kind

enum TreeNodeKind {
    case root
    case stage
    case field
}

// MARK: - Tree Node

/// A single node in the thinking tree visualization.
/// Pure value type — NOT a SwiftData model.
struct TreeNode: Identifiable {
    let id: String
    let kind: TreeNodeKind
    let content: String           // primary label
    let subContent: String?       // secondary text (e.g. field value)
    let stageOrder: Int?          // 1-9 for stage/field nodes
    let field: BriefField?        // only for field nodes
    var position: CGPoint         // computed by layout engine
    let nodeColor: Color
    let isGhost: Bool             // unfilled / unexplored
    let richness: CGFloat         // 0...1, drives node size & opacity

    var iconSystemName: String? {
        switch kind {
        case .root: return nil
        case .stage:
            guard let order = stageOrder else { return nil }
            return StageDefinition.all.first { $0.order == order }?.iconName
        case .field: return nil
        }
    }
}

// MARK: - Edge Style

enum TreeEdgeStyle {
    case branch     // solid, medium width — root → stage or stage → filled field
    case twig       // solid, thin — stage → field
    case ghost      // dashed, thin — root → ghost stage or stage → ghost field
}

// MARK: - Tree Edge

/// A connection between two nodes in the tree.
struct TreeEdge: Identifiable {
    let id: String
    let fromID: String
    let toID: String
    let style: TreeEdgeStyle
}

// MARK: - Tree Data

/// The complete data for rendering a thinking tree.
struct TreeData {
    let nodes: [TreeNode]
    let edges: [TreeEdge]

    func node(for id: String) -> TreeNode? {
        nodes.first { $0.id == id }
    }
}

// MARK: - Tree Builder

/// Builds a `TreeData` from a Project's current state.
struct TreeBuilder {

    func build(project: Project) -> TreeData {
        let brief = project.brief?.toSnapshot() ?? DesignBriefSnapshot()
        let stages = project.stages.sorted { $0.order < $1.order }

        var nodes: [TreeNode] = []
        var edges: [TreeEdge] = []

        // Root node
        let rootID = "root"
        let root = TreeNode(
            id: rootID,
            kind: .root,
            content: project.name,
            subContent: nil,
            stageOrder: nil,
            field: nil,
            position: .zero,
            nodeColor: Color.primaryAccent,
            isGhost: false,
            richness: 1.0
        )
        nodes.append(root)

        // Determine first uncompleted stage for ghost display
        let firstIncomplete = stages.first {
            $0.stageStatusValue == .notStarted || $0.stageStatusValue == .active
        }?.order

        // Stage + field nodes
        for def in StageDefinition.all {
            let stage = stages.first { $0.order == def.order }
            let status = stage?.stageStatusValue ?? .notStarted
            let completionRatio = stage?.completionRatio ?? 0

            let isGhost = status == .notStarted && completionRatio == 0
            let stageID = "stage-\(def.order)"

            // Stage color based on status
            let color: Color = {
                switch status {
                case .completed: return .success
                case .active: return .primaryAccent
                case .needsReview: return .warning
                case .notStarted: return Color.stageNotStarted
                }
            }()

            let stageNode = TreeNode(
                id: stageID,
                kind: .stage,
                content: "\(def.order)",
                subContent: def.shortSubtitle,
                stageOrder: def.order,
                field: nil,
                position: .zero,
                nodeColor: color,
                isGhost: isGhost,
                richness: max(completionRatio, 0.15)
            )
            nodes.append(stageNode)

            // Edge: root → stage
            edges.append(TreeEdge(
                id: "\(rootID)-\(stageID)",
                fromID: rootID,
                toID: stageID,
                style: isGhost ? .ghost : .branch
            ))

            // Field nodes for this stage
            let filledFields = def.briefFields.filter { $0.isFilled(in: brief) }
            let unfilledFields = def.briefFields.filter { !$0.isFilled(in: brief) }

            // Show filled fields as real nodes
            for (i, field) in filledFields.enumerated() {
                let fieldID = "field-\(field.rawValue)"
                let fieldValue = fieldDisplayValue(field, brief: brief)
                let fieldNode = TreeNode(
                    id: fieldID,
                    kind: .field,
                    content: field.displayName,
                    subContent: fieldValue,
                    stageOrder: def.order,
                    field: field,
                    position: .zero,
                    nodeColor: color,
                    isGhost: false,
                    richness: 0.6 + 0.4 * CGFloat(i + 1) / CGFloat(def.briefFields.count)
                )
                nodes.append(fieldNode)
                edges.append(TreeEdge(
                    id: "\(stageID)-\(fieldID)",
                    fromID: stageID,
                    toID: fieldID,
                    style: .twig
                ))
            }

            // Show unfilled fields as ghost nodes (only if stage is active or next)
            let showGhosts = status == .active || def.order == firstIncomplete
            if showGhosts {
                for field in unfilledFields {
                    let fieldID = "ghost-\(field.rawValue)"
                    let fieldNode = TreeNode(
                        id: fieldID,
                        kind: .field,
                        content: field.displayName,
                        subContent: nil,
                        stageOrder: def.order,
                        field: field,
                        position: .zero,
                        nodeColor: Color.stageNotStarted,
                        isGhost: true,
                        richness: 0.2
                    )
                    nodes.append(fieldNode)
                    edges.append(TreeEdge(
                        id: "\(stageID)-\(fieldID)",
                        fromID: stageID,
                        toID: fieldID,
                        style: .ghost
                    ))
                }
            }
        }

        return TreeData(nodes: nodes, edges: edges)
    }

    // MARK: - Helpers

    private func fieldDisplayValue(_ field: BriefField, brief: DesignBriefSnapshot) -> String? {
        switch field {
        case .targetUser: return brief.targetUser
        case .painPoint: return brief.painPoint
        case .useScenario: return brief.useScenario
        case .coreValue: return brief.coreValue
        case .differentiation: return brief.differentiation
        case .boundaryItems:
            let included = brief.boundaryItems.filter { $0.isIncluded }
            return included.isEmpty ? nil : "\(included.count) 项核心功能"
        case .mvpFeatures: return brief.mvpFeatures
        case .technicalModules: return brief.technicalModules
        case .interactionFlow: return brief.interactionFlow
        case .operationLogic: return brief.operationLogic
        case .hardConstraints: return brief.hardConstraints
        case .successMetrics:
            return brief.successMetrics.isEmpty ? nil : "\(brief.successMetrics.count) 项指标"
        case .risks:
            return brief.risks.isEmpty ? nil : "\(brief.risks.count) 项风险"
        case .milestones: return brief.milestones
        }
    }
}
