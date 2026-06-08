import SwiftUI

// MARK: - Node Kind

enum TreeNodeKind {
    case root
    case stage
    case question
    case field
    case process
    case evidence
    case revision
}

// MARK: - Tree Node

/// A single node in the thinking tree visualization.
struct TreeNode: Identifiable {
    let id: String
    let kind: TreeNodeKind
    let content: String
    let subContent: String?
    let stageOrder: Int?
    let field: BriefField?
    let momentID: UUID?
    var position: CGPoint
    let nodeColor: Color
    let isActiveBranch: Bool
    let branchVersion: Int
    let richness: CGFloat
    let isGhost: Bool
    let processLabel: String?
    let processIcon: String?
    let statusText: String?
    let resource: ResourceCard?
    let timestamp: Date?

    var iconSystemName: String? {
        switch kind {
        case .root:
            return "lightbulb.fill"
        case .stage:
            guard let order = stageOrder else { return nil }
            return StageDefinition.all.first { $0.order == order }?.iconName
        case .question:
            return "questionmark.circle"
        case .field:
            return processIcon ?? "checkmark.seal"
        case .process:
            return processIcon ?? "bubble.left"
        case .evidence:
            return "doc.text.magnifyingglass"
        case .revision:
            return "arrow.uturn.backward"
        }
    }

    var isArchived: Bool { !isActiveBranch }
    var isEditable: Bool { momentID != nil && !isGhost }
}

// MARK: - Edge Style

enum TreeEdgeStyle {
    case active
    case archived
    case transition
    case ghost
    case evidence
}

// MARK: - Tree Edge

struct TreeEdge: Identifiable {
    let id: String
    let fromID: String
    let toID: String
    let style: TreeEdgeStyle
    let togglesTransitionOrder: Int?

    init(
        id: String,
        fromID: String,
        toID: String,
        style: TreeEdgeStyle,
        togglesTransitionOrder: Int? = nil
    ) {
        self.id = id
        self.fromID = fromID
        self.toID = toID
        self.style = style
        self.togglesTransitionOrder = togglesTransitionOrder
    }
}

// MARK: - Tree Data

struct TreeData {
    let nodes: [TreeNode]
    let edges: [TreeEdge]
    let contentSize: CGSize

    func node(for id: String) -> TreeNode? {
        nodes.first { $0.id == id }
    }
}

// MARK: - Tree Builder

/// Builds a persistent process projection from Project state.
struct TreeBuilder {

    func build(project: Project) -> TreeData {
        build(project: project, expandedTransitionOrders: [], evidenceResourcesByStage: [:])
    }

    func build(
        project: Project,
        expandedTransitionOrders: Set<Int>,
        evidenceResourcesByStage: [Int: [ResourceCard]] = [:],
        visibleStageLimit: Int = 9
    ) -> TreeData {
        let brief = project.brief?.toSnapshot() ?? DesignBriefSnapshot()
        let stageByOrder = Dictionary(uniqueKeysWithValues: project.stages.map { ($0.order, $0) })
        let activeOrder = project.currentStageOrder
        let visibleLimit = min(max(visibleStageLimit, 1), 9)

        var nodes: [TreeNode] = []
        var edges: [TreeEdge] = []

        nodes.append(rootNode(project: project))

        for definition in StageDefinition.all where definition.order <= visibleLimit {
            let stage = stageByOrder[definition.order]
            let status = stage?.stageStatusValue ?? (definition.order == activeOrder ? .active : .notStarted)
            let stageID = Self.stageNodeID(definition.order)

            nodes.append(
                TreeNode(
                    id: stageID,
                    kind: .stage,
                    content: "Stage \(definition.order)",
                    subContent: definition.name,
                    stageOrder: definition.order,
                    field: nil,
                    momentID: nil,
                    position: .zero,
                    nodeColor: stageColor(for: status),
                    isActiveBranch: true,
                    branchVersion: 1,
                    richness: stage?.completionRatio ?? 0,
                    isGhost: status == .notStarted,
                    processLabel: nil,
                    processIcon: definition.iconName,
                    statusText: stageStatusText(status),
                    resource: nil,
                    timestamp: nil
                )
            )

            let parentID = definition.order == 1 ? Self.rootID : Self.stageNodeID(definition.order - 1)
            edges.append(
                TreeEdge(
                    id: "\(parentID)-\(stageID)",
                    fromID: parentID,
                    toID: stageID,
                    style: edgeStyle(for: status),
                    togglesTransitionOrder: definition.order
                )
            )
        }

        let visibleMoments = project.thinkingMoments
            .filter { expandedTransitionOrders.contains($0.stageOrder) && $0.stageOrder <= visibleLimit }
            .sorted { lhs, rhs in
                if lhs.stageOrder == rhs.stageOrder {
                    return lhs.timestamp < rhs.timestamp
                }
                return lhs.stageOrder < rhs.stageOrder
            }

        let momentsByTransition = Dictionary(grouping: visibleMoments.filter { (1...9).contains($0.stageOrder) }, by: \.stageOrder)
        for stageOrder in momentsByTransition.keys.sorted() {
            let transitionMoments = momentsByTransition[stageOrder] ?? []
            let previousStageID = transitionStartNodeID(for: stageOrder)
            var latestQuestionID: String?

            for moment in transitionMoments {
                let node = momentNode(moment, brief: brief, project: project)
                nodes.append(node)

                let explicitParentID = moment.parentMomentID.flatMap { parentID in
                    transitionMoments.contains { $0.id == parentID } ? "moment-\(parentID)" : nil
                }
                let fallbackParentID: String
                if node.kind == .question {
                    fallbackParentID = previousStageID
                } else {
                    fallbackParentID = latestQuestionID ?? previousStageID
                }
                let parentID = explicitParentID ?? fallbackParentID

                edges.append(
                    TreeEdge(
                        id: "\(parentID)-\(node.id)",
                        fromID: parentID,
                        toID: node.id,
                        style: moment.isActiveBranch ? (node.kind == .evidence ? .evidence : .active) : .archived
                    )
                )

                if node.kind == .question {
                    latestQuestionID = node.id
                }
            }
        }

        for trace in project.learningTraces
            .filter({ expandedTransitionOrders.contains($0.stageOrder) && $0.stageOrder <= visibleLimit })
            .sorted(by: { $0.timestamp < $1.timestamp }) {
            let nodeID = "trace-\(trace.id)"
            nodes.append(
                TreeNode(
                    id: nodeID,
                    kind: .process,
                    content: trace.title,
                    subContent: trace.detail,
                    stageOrder: trace.stageOrder,
                    field: nil,
                    momentID: nil,
                    position: .zero,
                    nodeColor: Color.secondaryAccent,
                    isActiveBranch: true,
                    branchVersion: 1,
                    richness: 0.62,
                    isGhost: false,
                    processLabel: traceLabel(trace.actionType),
                    processIcon: traceIcon(trace.actionType),
                    statusText: "学习轨迹",
                    resource: nil,
                    timestamp: trace.timestamp
                )
            )
            edges.append(
                TreeEdge(
                    id: "\(transitionStartNodeID(for: trace.stageOrder))-\(nodeID)",
                    fromID: transitionStartNodeID(for: trace.stageOrder),
                    toID: nodeID,
                    style: .transition
                )
            )
        }

        for (stageOrder, resources) in evidenceResourcesByStage where expandedTransitionOrders.contains(stageOrder) && stageOrder <= visibleLimit {
            let adoptedTitles = Set(
                project.thinkingMoments
                    .filter { $0.stageOrder == stageOrder && $0.momType == "evidence" && $0.isActiveBranch }
                    .map(\.content)
            )

            for resource in resources where !adoptedTitles.contains(resource.title) {
                let nodeID = "evidence-\(stageOrder)-\(resource.id)"
                nodes.append(
                    TreeNode(
                        id: nodeID,
                        kind: .evidence,
                        content: resource.title,
                        subContent: resource.summary,
                        stageOrder: stageOrder,
                        field: nil,
                        momentID: nil,
                        position: .zero,
                        nodeColor: Color.secondaryAccent,
                        isActiveBranch: true,
                        branchVersion: 1,
                        richness: 0.45,
                        isGhost: true,
                        processLabel: "Resource",
                        processIcon: "doc.text.magnifyingglass",
                        statusText: "资源卡",
                        resource: resource,
                        timestamp: nil
                    )
                )
                edges.append(
                    TreeEdge(
                        id: "\(transitionStartNodeID(for: stageOrder))-\(nodeID)",
                        fromID: transitionStartNodeID(for: stageOrder),
                        toID: nodeID,
                        style: .evidence
                    )
                )
            }
        }

        return TreeData(nodes: nodes, edges: edges, contentSize: .zero)
    }

    static let rootID = "root"

    static func stageNodeID(_ order: Int) -> String {
        "stage-\(order)"
    }

    // MARK: - Helpers

    private func rootNode(project: Project) -> TreeNode {
        TreeNode(
            id: Self.rootID,
            kind: .root,
            content: project.name,
            subContent: project.briefDescription.isEmpty ? "最初模糊主题" : project.briefDescription,
            stageOrder: nil,
            field: nil,
            momentID: nil,
            position: .zero,
            nodeColor: Color.primaryAccent,
            isActiveBranch: true,
            branchVersion: 1,
            richness: CGFloat(project.completionRate),
            isGhost: false,
            processLabel: nil,
            processIcon: "lightbulb.fill",
            statusText: "项目主题",
            resource: nil,
            timestamp: nil
        )
    }

    private func momentNode(_ moment: ThinkingMoment, brief: DesignBriefSnapshot, project: Project) -> TreeNode {
        let field = moment.relatedField.flatMap { BriefField(rawValue: $0) }
        let kind = nodeKind(for: moment, field: field)
        let status = project.stages.first { $0.order == moment.stageOrder }?.stageStatusValue ?? .notStarted
        let color = moment.isActiveBranch ? colorForMoment(moment, status: status) : Color(red: 0.58, green: 0.53, blue: 0.48)
        let content = momentContent(moment, field: field)
        let subContent = field.flatMap { fieldDisplayValue($0, brief: brief) } ?? momentSubContent(moment)

        return TreeNode(
            id: "moment-\(moment.id)",
            kind: kind,
            content: content,
            subContent: subContent,
            stageOrder: moment.stageOrder,
            field: field,
            momentID: moment.id,
            position: .zero,
            nodeColor: color,
            isActiveBranch: moment.isActiveBranch,
            branchVersion: moment.branchVersion,
            richness: moment.isActiveBranch ? 0.72 : 0.42,
            isGhost: false,
            processLabel: processLabel(for: moment),
            processIcon: processIcon(for: moment),
            statusText: momentStatusText(moment),
            resource: nil,
            timestamp: moment.timestamp
        )
    }

    private func nodeKind(for moment: ThinkingMoment, field: BriefField?) -> TreeNodeKind {
        if !moment.isActiveBranch { return .revision }
        if moment.momType == "question" { return .question }
        if moment.momType == "evidence" { return .evidence }
        if moment.momType == "revise" { return .revision }
        if field != nil || moment.momType == "decision" || moment.momType == "deepen" {
            return .field
        }
        return .process
    }

    private func momentContent(_ moment: ThinkingMoment, field: BriefField?) -> String {
        if let field, moment.momType == "decision" || moment.momType == "deepen" {
            return moment.content.isEmpty ? "确认：\(field.displayName)" : moment.content
        }
        return moment.content
    }

    private func momentSubContent(_ moment: ThinkingMoment) -> String? {
        switch moment.momType {
        case "question": return "AI 追问"
        case "answer": return "用户回答"
        case "decision", "deepen": return "结构化判断"
        case "method": return "方法调用"
        case "evidence": return "已采纳为依据"
        case "revise": return "回溯修改"
        case "branch": return "阶段探索"
        default: return nil
        }
    }

    private func colorForMoment(_ moment: ThinkingMoment, status: StageStatus) -> Color {
        switch moment.momType {
        case "answer": return Color.success
        case "question": return Color.primaryAccent
        case "decision", "deepen": return Color.warning
        case "evidence": return Color.secondaryAccent
        case "revise": return Color(red: 0.58, green: 0.53, blue: 0.48)
        default: return stageColor(for: status)
        }
    }

    private func processLabel(for moment: ThinkingMoment) -> String {
        switch moment.momType {
        case "question": return "Q"
        case "answer": return "A"
        case "decision", "deepen": return "Decision"
        case "method": return "线索"
        case "evidence": return "Evidence"
        case "revise": return "Revision"
        case "branch": return "Stage"
        default: return moment.momType.isEmpty ? "Process" : moment.momType
        }
    }

    private func processIcon(for moment: ThinkingMoment) -> String {
        switch moment.momType {
        case "question": return "questionmark.circle"
        case "answer": return "bubble.left"
        case "decision", "deepen": return "checkmark.seal"
        case "method": return "rectangle.stack.badge.play"
        case "evidence": return "doc.text.magnifyingglass"
        case "revise": return "arrow.uturn.backward"
        case "branch": return "square.stack.3d.up"
        default: return "sparkles"
        }
    }

    private func momentStatusText(_ moment: ThinkingMoment) -> String {
        if !moment.isActiveBranch { return "旧分支 v\(moment.branchVersion)" }
        switch moment.momType {
        case "question": return "问题"
        case "answer": return "回答"
        case "decision", "deepen": return "判断"
        case "method": return "方法"
        case "evidence": return "依据"
        case "revise": return "回溯"
        default: return "过程"
        }
    }

    private func transitionStartNodeID(for stageOrder: Int) -> String {
        stageOrder == 1 ? Self.rootID : Self.stageNodeID(stageOrder - 1)
    }

    private func fieldDisplayValue(_ field: BriefField, brief: DesignBriefSnapshot) -> String? {
        switch field {
        case .targetUser: return brief.targetUser
        case .painPoint: return brief.painPoint
        case .useScenario: return brief.useScenario
        case .coreValue: return brief.coreValue
        case .differentiation: return brief.differentiation
        case .boundaryItems:
            let included = brief.boundaryItems.filter { $0.isIncluded }
            return included.isEmpty ? nil : "\(included.count) 项边界"
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

    private func traceLabel(_ actionType: String) -> String {
        switch actionType {
        case "reframe": return "Reframe"
        case "converge": return "Converge"
        case "boundaryShrink": return "Boundary"
        default: return "Trace"
        }
    }

    private func traceIcon(_ actionType: String) -> String {
        switch actionType {
        case "reframe": return "arrow.triangle.2.circlepath"
        case "converge": return "arrow.down.right.and.arrow.up.left"
        case "boundaryShrink": return "rectangle.compress.vertical"
        default: return "sparkles"
        }
    }

    private func stageColor(for status: StageStatus) -> Color {
        switch status {
        case .completed: return .success
        case .active: return .primaryAccent
        case .needsReview: return .warning
        case .notStarted: return .stageNotStarted
        }
    }

    private func edgeStyle(for status: StageStatus) -> TreeEdgeStyle {
        switch status {
        case .completed, .active:
            return .active
        case .needsReview:
            return .transition
        case .notStarted:
            return .ghost
        }
    }

    private func stageStatusText(_ status: StageStatus) -> String {
        switch status {
        case .completed: return "已完成"
        case .active: return "进行中"
        case .needsReview: return "待复核"
        case .notStarted: return "未开始"
        }
    }
}
