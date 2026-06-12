import SwiftUI

// MARK: - Node Kind

enum TreeNodeKind {
    case root
    case stage
    case branchStage
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
    let branchAnchorID: String?

    var iconSystemName: String? {
        switch kind {
        case .root:
            return "lightbulb.fill"
        case .stage, .branchStage:
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

// MARK: - Moment Projection

/// Projects the raw thinking log into the user-facing tree.
/// Answers and scaffold turns stay in SwiftData for audit/detail views, but
/// they are not rendered as standalone tree nodes.
struct ThinkingTreeMomentProjector {
    static func visibleMoments(_ moments: [ThinkingMoment]) -> [ThinkingMoment] {
        moments
            .sorted { $0.timestamp < $1.timestamp }
            .filter { isVisibleInTree($0) }
    }

    static func isVisibleInTree(_ moment: ThinkingMoment) -> Bool {
        switch moment.momType {
        case "answer", "method", "scaffold":
            return false
        case "question":
            return !isScaffoldQuestion(moment.content)
        default:
            return true
        }
    }

    static func pairedAnswer(for question: ThinkingMoment, in moments: [ThinkingMoment]) -> ThinkingMoment? {
        if let direct = moments
            .filter({
                $0.parentMomentID == question.id &&
                $0.momType == "answer" &&
                $0.isActiveBranch
            })
            .sorted(by: { $0.timestamp < $1.timestamp })
            .last {
            return direct
        }

        var latestAnswer: ThinkingMoment?
        let laterMoments = moments
            .filter { $0.stageOrder == question.stageOrder && $0.timestamp > question.timestamp }
            .sorted { $0.timestamp < $1.timestamp }

        for moment in laterMoments {
            if question.isActiveBranch && !moment.isActiveBranch {
                continue
            }

            switch moment.momType {
            case "answer":
                guard !isStuckAnswer(moment.content) else { continue }
                latestAnswer = moment
            case "question":
                if isScaffoldQuestion(moment.content) {
                    continue
                }
                return latestAnswer
            default:
                continue
            }
        }

        return latestAnswer
    }

    static func archivedAnswers(for question: ThinkingMoment, in moments: [ThinkingMoment]) -> [ThinkingMoment] {
        let direct = moments.filter {
            $0.parentMomentID == question.id &&
            $0.momType == "answer" &&
            !$0.isActiveBranch
        }
        let inferred = moments.filter {
            $0.parentMomentID == nil &&
            $0.stageOrder == question.stageOrder &&
            $0.momType == "answer" &&
            !$0.isActiveBranch &&
            $0.timestamp > question.timestamp
        }
        let all = direct + inferred
        var seen = Set<UUID>()
        return all
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.timestamp < $1.timestamp }
    }

    static func isStuckAnswer(_ content: String) -> Bool {
        if ClarificationMode.detect(from: content) == .stuckScaffold {
            return true
        }

        let normalized = content
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return [
            "我还不确定",
            "我还不太确定",
            "不确定",
            "我不知道",
            "不知道",
            "想不出来",
            "没想好",
            "卡住了",
            "不会答",
            "没有思路",
            "没思路",
            "请进入线索+提问模式",
            "线索+提问模式"
        ].contains { normalized.contains($0) }
    }

    static func isScaffoldQuestion(_ content: String) -> Bool {
        let normalized = content
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return [
            "线索追问",
            "引导追问",
            "线索：",
            "追问：",
            "先回想",
            "先想一个",
            "任务片段",
            "方法线索",
            "从一个具体例子开始"
        ].contains { marker in
            normalized.contains(marker.replacingOccurrences(of: " ", with: "").lowercased())
        }
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
                    timestamp: nil,
                    branchAnchorID: nil
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

        appendCollapsedArchivedBranches(
            project: project,
            visibleLimit: visibleLimit,
            expandedTransitionOrders: expandedTransitionOrders,
            nodes: &nodes,
            edges: &edges
        )

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
            let projectedMoments = ThinkingTreeMomentProjector.visibleMoments(transitionMoments)
            let previousStageID = transitionStartNodeID(for: stageOrder)
            var latestQuestionID: String?
            var archivedQuestionIDsByParent: [UUID: String] = [:]

            for moment in projectedMoments {
                let archivedQuestionID: String?
                if !moment.isActiveBranch,
                   let question = visibleQuestionParent(
                    for: moment,
                    allMoments: transitionMoments,
                    projectedMoments: projectedMoments
                   ) {
                    if let existingID = archivedQuestionIDsByParent[question.id] {
                        archivedQuestionID = existingID
                    } else {
                        let archivedID = Self.archivedQuestionNodeID(question.id, branchVersion: moment.branchVersion)
                        let questionNode = momentNode(question, brief: brief, project: project)
                        nodes.append(
                            TreeNode(
                                id: archivedID,
                                kind: .question,
                                content: questionNode.content,
                                subContent: "旧分支 v\(moment.branchVersion)",
                                stageOrder: question.stageOrder,
                                field: nil,
                                momentID: question.id,
                                position: .zero,
                                nodeColor: archivedBranchColor,
                                isActiveBranch: false,
                                branchVersion: moment.branchVersion,
                                richness: 0.36,
                                isGhost: false,
                                processLabel: "回溯问题",
                                processIcon: "arrow.uturn.backward",
                                statusText: "旧问题",
                                resource: nil,
                                timestamp: question.timestamp,
                                branchAnchorID: "moment-\(question.id)"
                            )
                        )
                        edges.append(
                            TreeEdge(
                                id: "moment-\(question.id)-\(archivedID)",
                                fromID: "moment-\(question.id)",
                                toID: archivedID,
                                style: .archived
                            )
                        )
                        archivedQuestionIDsByParent[question.id] = archivedID
                        archivedQuestionID = archivedID
                    }
                } else {
                    archivedQuestionID = nil
                }

                let node = momentNode(
                    moment,
                    brief: brief,
                    project: project,
                    branchAnchorID: archivedQuestionID
                )
                nodes.append(node)

                var parentID = parentNodeID(
                    for: moment,
                    node: node,
                    allMoments: transitionMoments,
                    projectedMoments: projectedMoments,
                    previousStageID: previousStageID,
                    latestQuestionID: latestQuestionID
                )

                if let archivedQuestionID {
                    parentID = archivedQuestionID
                }

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
                    timestamp: trace.timestamp,
                    branchAnchorID: nil
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
                        subContent: resource.userDisplayText,
                        stageOrder: stageOrder,
                        field: nil,
                        momentID: nil,
                        position: .zero,
                        nodeColor: Color.secondaryAccent,
                        isActiveBranch: true,
                        branchVersion: 1,
                        richness: 0.45,
                        isGhost: true,
                        processLabel: "RAG",
                        processIcon: "doc.text.magnifyingglass",
                        statusText: "推荐依据",
                        resource: resource,
                        timestamp: nil,
                        branchAnchorID: nil
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

    private static func branchStageNodeID(sourceOrder: Int, order: Int) -> String {
        "branch-stage-\(sourceOrder)-\(order)"
    }

    private static func archivedQuestionNodeID(_ questionID: UUID, branchVersion: Int) -> String {
        "archived-question-\(questionID)-v\(branchVersion)"
    }

    // MARK: - Helpers

    private var archivedBranchColor: Color {
        Color(red: 0.58, green: 0.59, blue: 0.64)
    }

    private func appendCollapsedArchivedBranches(
        project: Project,
        visibleLimit: Int,
        expandedTransitionOrders: Set<Int>,
        nodes: inout [TreeNode],
        edges: inout [TreeEdge]
    ) {
        let archivedStageOrders = Set(
            project.thinkingMoments
                .filter { !$0.isActiveBranch && $0.stageOrder <= visibleLimit }
                .map(\.stageOrder)
        )
        guard let sourceOrder = archivedStageOrders.min(),
              !expandedTransitionOrders.contains(sourceOrder)
        else {
            return
        }

        let maxArchivedOrder = visibleLimit
        guard sourceOrder < maxArchivedOrder else { return }
        let branchOrders = Array((sourceOrder + 1)...maxArchivedOrder)
        guard !branchOrders.isEmpty else { return }

        let branchSourceID = Self.stageNodeID(sourceOrder)
        var previousID = branchSourceID

        for order in branchOrders {
            let id = Self.branchStageNodeID(sourceOrder: sourceOrder, order: order)
            let definition = StageDefinition.all.first { $0.order == order }
            nodes.append(
                TreeNode(
                    id: id,
                    kind: .branchStage,
                    content: "Stage \(order)",
                    subContent: definition?.name ?? "旧分支阶段",
                    stageOrder: order,
                    field: nil,
                    momentID: nil,
                    position: .zero,
                    nodeColor: archivedBranchColor,
                    isActiveBranch: false,
                    branchVersion: 1,
                    richness: 0.34,
                    isGhost: false,
                    processLabel: "旧阶段",
                    processIcon: definition?.iconName,
                    statusText: "旧分支",
                    resource: nil,
                    timestamp: nil,
                    branchAnchorID: branchSourceID
                )
            )
            edges.append(
                TreeEdge(
                    id: "\(previousID)-\(id)",
                    fromID: previousID,
                    toID: id,
                    style: .archived
                )
            )
            previousID = id
        }
    }

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
            timestamp: nil,
            branchAnchorID: nil
        )
    }

    private func momentNode(
        _ moment: ThinkingMoment,
        brief: DesignBriefSnapshot,
        project: Project,
        branchAnchorID: String? = nil
    ) -> TreeNode {
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
            timestamp: moment.timestamp,
            branchAnchorID: branchAnchorID
        )
    }

    private func nodeKind(for moment: ThinkingMoment, field: BriefField?) -> TreeNodeKind {
        if moment.momType == "question" { return .question }
        if !moment.isActiveBranch { return .revision }
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
        case "method": return "本地知识库调用"
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
        case "question": return "问题节点"
        case "answer": return "答案节点"
        case "decision", "deepen": return "Decision"
        case "method": return "依据"
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
        case "answer": return "答案"
        case "decision", "deepen": return "判断"
        case "method": return "依据"
        case "evidence": return "依据"
        case "revise": return "回溯"
        default: return "过程"
        }
    }

    private func parentNodeID(
        for moment: ThinkingMoment,
        node: TreeNode,
        allMoments: [ThinkingMoment],
        projectedMoments: [ThinkingMoment],
        previousStageID: String,
        latestQuestionID: String?
    ) -> String {
        if let visibleParent = visibleParentID(
            for: moment,
            allMoments: allMoments,
            projectedMoments: projectedMoments
        ) {
            return visibleParent
        }

        if node.kind == .question && node.isActiveBranch {
            return previousStageID
        }

        return latestQuestionID ?? previousStageID
    }

    private func visibleParentID(
        for moment: ThinkingMoment,
        allMoments: [ThinkingMoment],
        projectedMoments: [ThinkingMoment]
    ) -> String? {
        guard let parentID = moment.parentMomentID,
              let parent = allMoments.first(where: { $0.id == parentID }) else {
            return nil
        }

        if projectedMoments.contains(where: { $0.id == parent.id }) {
            return "moment-\(parent.id)"
        }

        return visibleParentID(
            for: parent,
            allMoments: allMoments,
            projectedMoments: projectedMoments
        )
    }

    private func visibleQuestionParent(
        for moment: ThinkingMoment,
        allMoments: [ThinkingMoment],
        projectedMoments: [ThinkingMoment]
    ) -> ThinkingMoment? {
        guard let parentID = moment.parentMomentID,
              let parent = allMoments.first(where: { $0.id == parentID }) else {
            return nil
        }

        if parent.momType == "question",
           projectedMoments.contains(where: { $0.id == parent.id }) {
            return parent
        }

        return visibleQuestionParent(
            for: parent,
            allMoments: allMoments,
            projectedMoments: projectedMoments
        )
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
        case "methodCard": return "Evidence"
        default: return "Trace"
        }
    }

    private func traceIcon(_ actionType: String) -> String {
        switch actionType {
        case "reframe": return "arrow.triangle.2.circlepath"
        case "converge": return "arrow.down.right.and.arrow.up.left"
        case "boundaryShrink": return "rectangle.compress.vertical"
        case "methodCard": return "doc.text.magnifyingglass"
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
