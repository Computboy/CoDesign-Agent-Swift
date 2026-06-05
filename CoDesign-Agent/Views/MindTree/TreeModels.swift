import SwiftUI

// MARK: - Node Kind

enum TreeNodeKind {
    case root
    case stage
    case field
}

// MARK: - Tree Node

/// A single node in the thinking tree visualization.
struct TreeNode: Identifiable {
    let id: String
    let kind: TreeNodeKind
    let content: String           // primary label
    let subContent: String?       // secondary text (e.g. field value)
    let stageOrder: Int?          // 1-9 for stage/field nodes
    let field: BriefField?        // only for field nodes
    let momentID: UUID?           // link to ThinkingMoment (nil for root)
    var position: CGPoint         // computed by layout engine
    let nodeColor: Color
    let isActiveBranch: Bool      // true = current branch, false = archived
    let branchVersion: Int
    let richness: CGFloat         // 0...1, drives node size
    let isGhost: Bool             // true = unfilled / unexplored placeholder

    var iconSystemName: String? {
        switch kind {
        case .root: return nil
        case .stage:
            guard let order = stageOrder else { return nil }
            return StageDefinition.all.first { $0.order == order }?.iconName
        case .field: return nil
        }
    }

    var isArchived: Bool { !isActiveBranch }
}

// MARK: - Edge Style

enum TreeEdgeStyle {
    case active      // solid, active branch
    case archived    // dashed, archived branch
    case transition  // solid, connecting archived to active (edit point)
}

// MARK: - Tree Edge

struct TreeEdge: Identifiable {
    let id: String
    let fromID: String
    let toID: String
    let style: TreeEdgeStyle
}

// MARK: - Tree Data

struct TreeData {
    let nodes: [TreeNode]
    let edges: [TreeEdge]

    func node(for id: String) -> TreeNode? {
        nodes.first { $0.id == id }
    }
}

// MARK: - Tree Builder

/// Builds a TreeData from Project's ThinkingMoments.
struct TreeBuilder {

    func build(project: Project) -> TreeData {
        let moments = project.thinkingMoments.sorted { $0.timestamp < $1.timestamp }
        let brief = project.brief?.toSnapshot() ?? DesignBriefSnapshot()

        var nodes: [TreeNode] = []
        var edges: [TreeEdge] = []

        // Root node (project idea)
        let rootID = "root"
        let rootNode = TreeNode(
            id: rootID,
            kind: .root,
            content: project.name,
            subContent: project.briefDescription.isEmpty ? nil : project.briefDescription,
            stageOrder: nil,
            field: nil,
            momentID: nil,
            position: .zero,
            nodeColor: Color.primaryAccent,
            isActiveBranch: true,
            branchVersion: 1,
            richness: 1.0,
            isGhost: false
        )
        nodes.append(rootNode)

        // Build moment-based nodes
        for moment in moments {
            let nodeID = "moment-\(moment.id)"
            let isStageNode = moment.relatedField == nil
            let field = moment.relatedField.flatMap { BriefField(rawValue: $0) }

            let color: Color
            if moment.isActiveBranch {
                // Active branch: use stage status colors
                let stage = project.stages.first { $0.order == moment.stageOrder }
                switch stage?.stageStatusValue ?? .notStarted {
                case .completed: color = .success
                case .active: color = .primaryAccent
                case .needsReview: color = .warning
                case .notStarted: color = .stageNotStarted
                }
            } else {
                // Archived branch: muted sepia/grey
                color = Color(red: 0.6, green: 0.55, blue: 0.5)
            }

            let fieldValue: String? = field.flatMap { fieldDisplayValue($0, brief: brief) }

            let node = TreeNode(
                id: nodeID,
                kind: isStageNode ? .stage : .field,
                content: moment.content,
                subContent: fieldValue,
                stageOrder: moment.stageOrder,
                field: field,
                momentID: moment.id,
                position: .zero,
                nodeColor: color,
                isActiveBranch: moment.isActiveBranch,
                branchVersion: moment.branchVersion,
                richness: moment.isActiveBranch ? 0.8 : 0.5,
                isGhost: false
            )
            nodes.append(node)

            // Edge from parent
            let parentID: String
            if let parentMomentID = moment.parentMomentID {
                parentID = "moment-\(parentMomentID)"
            } else {
                parentID = rootID  // root is parent if no parentMomentID
            }

            let edgeStyle: TreeEdgeStyle
            if moment.isActiveBranch {
                edgeStyle = .active
            } else {
                // Check if parent is active (this is the edit point)
                let parentMoment = moments.first { $0.id == moment.parentMomentID }
                edgeStyle = parentMoment?.isActiveBranch == true ? .transition : .archived
            }

            edges.append(TreeEdge(
                id: "\(parentID)-\(nodeID)",
                fromID: parentID,
                toID: nodeID,
                style: edgeStyle
            ))
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
