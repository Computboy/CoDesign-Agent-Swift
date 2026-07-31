import SwiftUI

/// Builds the visible question tree from persisted project history.
///
/// Stage cards are derived completion boundaries. They are never persisted as
/// fixed-position canvas nodes, and an in-progress Stage never gets one.
struct TreeBuilder {
    private struct RollbackFork {
        let id: String
        let sequence: Int
        let sourceStageOrder: Int
        let archivedAt: Date
        let parentQuestionID: UUID?
        let branchVersion: Int
        let archivedMoments: [ThinkingMoment]
    }

    private enum ActiveEvent {
        case question(ThinkingMoment)
        case rollback(RollbackFork)

        var timestamp: Date {
            switch self {
            case .question(let question):
                return question.timestamp
            case .rollback(let fork):
                return fork.archivedAt
            }
        }

        var stableID: String {
            switch self {
            case .question(let question):
                return question.id.uuidString
            case .rollback(let fork):
                return fork.id
            }
        }

        var tieBreakRank: Int {
            switch self {
            case .question: return 0
            case .rollback: return 1
            }
        }
    }

    static let rootID = "root"

    static func stageNodeID(_ order: Int) -> String {
        "stage-\(order)"
    }

    func build(project: Project) -> TreeData {
        build(
            project: project,
            expandedTransitionOrders: [],
            expandedArchivedStageOrders: []
        )
    }

    func build(
        project: Project,
        expandedTransitionOrders: Set<Int>,
        expandedArchivedStageOrders: Set<Int> = [],
        visibleStageLimit: Int = 9
    ) -> TreeData {
        // Kept in the signature and annotation document for backward
        // compatibility. A Stage now owns its rollback subtree, so old-branch
        // visibility is no longer an independent interaction.
        _ = expandedArchivedStageOrders

        let stageByOrder = Dictionary(
            uniqueKeysWithValues: project.stages.map { ($0.order, $0) }
        )
        let questionNumbers = questionNumbers(in: project)
        let forksByStage = Dictionary(
            grouping: rollbackForks(in: project),
            by: \.sourceStageOrder
        )
        let sortedStages = project.stages.sorted { $0.order < $1.order }
        let currentOpenStageOrder = sortedStages.first {
            $0.stageStatusValue == .needsReview
        }?.order
            ?? sortedStages.first {
                $0.stageStatusValue == .active
            }?.order
            ?? sortedStages.first {
                $0.stageStatusValue != .completed
            }?.order
            ?? project.currentStageOrder

        var nodes = [rootNode(project: project)]
        var edges: [TreeEdge] = []
        var previousBoundaryID = Self.rootID
        var globalRank = 0
        var activeColumn = 0

        for definition in StageDefinition.all
            where definition.order <= min(max(visibleStageLimit, 1), 9) {
            let stage = stageByOrder[definition.order]
            guard let state = stageTreeState(
                order: definition.order,
                stage: stage,
                currentOpenStageOrder: currentOpenStageOrder,
                expandedTransitionOrders: expandedTransitionOrders
            ) else {
                continue
            }

            let orderedQuestions = ThinkingTreeTopology.activeQuestions(
                for: definition.order,
                in: project.thinkingMoments
            )
            let activeLeaf = ThinkingTreeTopology.activeLeafNode(
                for: definition.order,
                in: project.thinkingMoments
            )
            let stageForks = (forksByStage[definition.order] ?? [])
                .sorted { lhs, rhs in
                    if lhs.archivedAt != rhs.archivedAt {
                        return lhs.archivedAt < rhs.archivedAt
                    }
                    return lhs.id < rhs.id
                }
            let events = activeEvents(
                questions: orderedQuestions,
                forks: stageForks
            )

            var eventRank = globalRank
            var eventColumn = activeColumn
            var rankByQuestionID: [UUID: Int] = [:]
            var columnByQuestionID: [UUID: Int] = [:]
            var rankByForkID: [String: Int] = [:]
            var columnByForkID: [String: Int] = [:]

            for event in events {
                eventRank += 1
                switch event {
                case .question(let question):
                    rankByQuestionID[question.id] = eventRank
                    columnByQuestionID[question.id] = eventColumn
                case .rollback(let fork):
                    rankByForkID[fork.id] = eventRank
                    columnByForkID[fork.id] = eventColumn
                    eventColumn += 1
                }
            }

            if state.isExpanded {
                appendExpandedStage(
                    project: project,
                    definition: definition,
                    questions: orderedQuestions,
                    forks: stageForks,
                    events: events,
                    previousBoundaryID: previousBoundaryID,
                    questionNumbers: questionNumbers,
                    rankByQuestionID: rankByQuestionID,
                    columnByQuestionID: columnByQuestionID,
                    rankByForkID: rankByForkID,
                    columnByForkID: columnByForkID,
                    nodes: &nodes,
                    edges: &edges
                )
            }

            let leafRank = activeLeaf.flatMap { rankByQuestionID[$0.id] }
                ?? globalRank
            let leafColumn = activeLeaf.flatMap { columnByQuestionID[$0.id] }
                ?? eventColumn

            if state.isCompleted {
                let stageRank = leafRank + 1
                let stageNode = completionStageNode(
                    definition: definition,
                    progress: stage,
                    state: state,
                    branchDepth: leafColumn,
                    layoutRank: stageRank
                )
                nodes.append(stageNode)

                let leafID = activeLeaf.map { "moment-\($0.id)" }
                let sourceID = state.isExpanded
                    ? (leafID ?? previousBoundaryID)
                    : previousBoundaryID
                edges.append(
                    TreeEdge(
                        id: "\(sourceID)-\(stageNode.id)",
                        fromID: sourceID,
                        toID: stageNode.id,
                        style: .active,
                        togglesTransitionOrder: definition.order
                    )
                )

                previousBoundaryID = stageNode.id
                globalRank = stageRank
                activeColumn = leafColumn
            } else {
                globalRank = eventRank
                activeColumn = eventColumn
            }
        }

        return TreeData(nodes: nodes, edges: edges, contentSize: .zero)
    }

    // MARK: - Active stage

    private func appendExpandedStage(
        project: Project,
        definition: StageDefinition,
        questions: [ThinkingMoment],
        forks: [RollbackFork],
        events: [ActiveEvent],
        previousBoundaryID: String,
        questionNumbers: [UUID: Int],
        rankByQuestionID: [UUID: Int],
        columnByQuestionID: [UUID: Int],
        rankByForkID: [String: Int],
        columnByForkID: [String: Int],
        nodes: inout [TreeNode],
        edges: inout [TreeEdge]
    ) {
        var previousID = previousBoundaryID

        for event in events {
            switch event {
            case .question(let question):
                guard let rank = rankByQuestionID[question.id],
                      let column = columnByQuestionID[question.id]
                else {
                    continue
                }
                let priorFork = forks.last {
                    $0.archivedAt < question.timestamp
                        || $0.archivedAt == question.timestamp
                }
                let node = questionNode(
                    question,
                    project: project,
                    questionNumber: questionNumbers[question.id],
                    branchAnchorID: priorFork?.id,
                    branchDepth: column,
                    layoutRank: rank
                )
                nodes.append(node)
                edges.append(
                    TreeEdge(
                        id: "\(previousID)-\(node.id)",
                        fromID: previousID,
                        toID: node.id,
                        style: .active
                    )
                )
                previousID = node.id

            case .rollback(let fork):
                guard let rank = rankByForkID[fork.id],
                      let column = columnByForkID[fork.id]
                else {
                    continue
                }
                let forkNode = rollbackNode(
                    fork,
                    branchDepth: column,
                    layoutRank: rank
                )
                nodes.append(forkNode)
                edges.append(
                    TreeEdge(
                        id: "\(previousID)-\(fork.id)",
                        fromID: previousID,
                        toID: fork.id,
                        style: .active
                    )
                )
                previousID = fork.id

                appendArchivedQuestions(
                    for: fork,
                    project: project,
                    questionNumbers: questionNumbers,
                    forkRank: rank,
                    forkColumn: column,
                    nodes: &nodes,
                    edges: &edges
                )
            }
        }
    }

    private func appendArchivedQuestions(
        for fork: RollbackFork,
        project: Project,
        questionNumbers: [UUID: Int],
        forkRank: Int,
        forkColumn: Int,
        nodes: inout [TreeNode],
        edges: inout [TreeEdge]
    ) {
        let archivedQuestions = archivedQuestions(
            for: fork,
            in: project.thinkingMoments
        )
        var previousID = fork.id

        for (offset, question) in archivedQuestions.enumerated() {
            let node = questionNode(
                question,
                project: project,
                questionNumber: questionNumbers[question.id],
                branchAnchorID: fork.id,
                branchDepth: forkColumn - 1,
                layoutRank: forkRank + offset + 1
            )
            nodes.append(node)
            edges.append(
                TreeEdge(
                    id: "\(previousID)-\(node.id)",
                    fromID: previousID,
                    toID: node.id,
                    style: .archived
                )
            )
            previousID = node.id
        }
    }

    // MARK: - Lifecycle

    private func stageTreeState(
        order: Int,
        stage: ProgressStage?,
        currentOpenStageOrder: Int,
        expandedTransitionOrders: Set<Int>
    ) -> StageTreeState? {
        let status = stage?.stageStatusValue
            ?? (order == currentOpenStageOrder ? .active : .notStarted)

        if status == .completed {
            return expandedTransitionOrders.contains(order)
                ? .completedExpanded
                : .completedCollapsed
        }

        if order == currentOpenStageOrder
            && (status == .active || status == .needsReview) {
            return .inProgress
        }
        return nil
    }

    private func activeEvents(
        questions: [ThinkingMoment],
        forks: [RollbackFork]
    ) -> [ActiveEvent] {
        let events = questions.map(ActiveEvent.question)
            + forks.map(ActiveEvent.rollback)
        return events.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp < rhs.timestamp
            }
            if lhs.tieBreakRank != rhs.tieBreakRank {
                return lhs.tieBreakRank < rhs.tieBreakRank
            }
            return lhs.stableID < rhs.stableID
        }
    }

    // MARK: - Rollback topology

    private func rollbackForks(in project: Project) -> [RollbackFork] {
        let archivedMoments = project.thinkingMoments.filter {
            !$0.isActiveBranch
        }
        let groups = Dictionary(grouping: archivedMoments) { moment in
            if let archivedAt = moment.archivedAt {
                return "date-\(archivedAt.timeIntervalSinceReferenceDate)"
            }
            return "legacy-v\(moment.branchVersion)"
        }
        let drafts = groups.values.compactMap {
            rollbackDraft(for: $0, allMoments: project.thinkingMoments)
        }
        let groupedBySource = Dictionary(grouping: drafts, by: \.sourceStageOrder)
        var result: [RollbackFork] = []

        for sourceOrder in groupedBySource.keys.sorted() {
            let sorted = (groupedBySource[sourceOrder] ?? []).sorted {
                if $0.archivedAt != $1.archivedAt {
                    return $0.archivedAt < $1.archivedAt
                }
                return $0.branchVersion < $1.branchVersion
            }
            for (offset, draft) in sorted.enumerated() {
                let sequence = offset + 1
                result.append(
                    RollbackFork(
                        id: "branch-stage-\(sourceOrder)-\(sourceOrder)-fork-\(sequence)",
                        sequence: sequence,
                        sourceStageOrder: sourceOrder,
                        archivedAt: draft.archivedAt,
                        parentQuestionID: draft.parentQuestionID,
                        branchVersion: draft.branchVersion,
                        archivedMoments: draft.archivedMoments
                    )
                )
            }
        }
        return result
    }

    private func rollbackDraft(
        for moments: [ThinkingMoment],
        allMoments: [ThinkingMoment]
    ) -> (
        sourceStageOrder: Int,
        archivedAt: Date,
        parentQuestionID: UUID?,
        branchVersion: Int,
        archivedMoments: [ThinkingMoment]
    )? {
        guard !moments.isEmpty else { return nil }
        let sorted = moments.sorted {
            if $0.timestamp != $1.timestamp {
                return $0.timestamp < $1.timestamp
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        let questionByID = Dictionary(
            uniqueKeysWithValues: allMoments
                .filter { $0.momType == "question" }
                .map { ($0.id, $0) }
        )
        let parentQuestion = sorted
            .filter { $0.momType == "answer" }
            .compactMap { answer in
                answer.parentMomentID.flatMap { questionByID[$0] }
            }
            .first
            ?? sorted
                .filter { $0.momType == "question" }
                .compactMap { question in
                    question.parentMomentID.flatMap { questionByID[$0] }
                }
                .first
        guard let parentQuestion else {
            return nil
        }
        let sourceOrder = parentQuestion.stageOrder
        let archivedAt = sorted.compactMap(\.archivedAt).min()
            ?? sorted.first?.timestamp
            ?? .distantPast
        return (
            sourceOrder,
            archivedAt,
            parentQuestion.id,
            sorted.map(\.branchVersion).max() ?? 1,
            sorted
        )
    }

    private func archivedQuestions(
        for fork: RollbackFork,
        in allMoments: [ThinkingMoment]
    ) -> [ThinkingMoment] {
        let direct = fork.archivedMoments.filter {
            $0.momType == "question"
                && $0.id != fork.parentQuestionID
        }
        let archivedIDs = Set(fork.archivedMoments.map(\.id))
        let inferred = allMoments.filter { moment in
            guard moment.momType == "question",
                  !moment.isActiveBranch,
                  moment.id != fork.parentQuestionID
            else {
                return false
            }
            if archivedIDs.contains(moment.id) {
                return true
            }
            return moment.archivedAt == fork.archivedAt
        }

        var seen = Set<UUID>()
        return (direct + inferred)
            .filter { seen.insert($0.id).inserted }
            .sorted {
                if $0.timestamp != $1.timestamp {
                    return $0.timestamp < $1.timestamp
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    // MARK: - Nodes

    private func rootNode(project: Project) -> TreeNode {
        TreeNode(
            id: Self.rootID,
            kind: .root,
            content: project.name,
            subContent: project.briefDescription.isEmpty
                ? "最初模糊主题"
                : project.briefDescription,
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
            timestamp: project.createdAt,
            branchAnchorID: nil,
            branchDepth: 0,
            layoutRank: 0
        )
    }

    private func completionStageNode(
        definition: StageDefinition,
        progress: ProgressStage?,
        state: StageTreeState,
        branchDepth: Int,
        layoutRank: Int
    ) -> TreeNode {
        TreeNode(
            id: Self.stageNodeID(definition.order),
            kind: .stage,
            content: "Stage \(definition.order)",
            subContent: definition.name,
            stageOrder: definition.order,
            field: nil,
            momentID: nil,
            position: .zero,
            nodeColor: Color.primaryAccent,
            isActiveBranch: true,
            branchVersion: 1,
            richness: progress?.completionRatio ?? 1,
            isGhost: false,
            processLabel: "阶段完成",
            processIcon: definition.iconName,
            statusText: "已完成",
            timestamp: progress?.lastUpdated,
            branchAnchorID: nil,
            branchDepth: branchDepth,
            layoutRank: layoutRank,
            stageTreeState: state
        )
    }

    private func rollbackNode(
        _ fork: RollbackFork,
        branchDepth: Int,
        layoutRank: Int
    ) -> TreeNode {
        TreeNode(
            id: fork.id,
            kind: .branchStage,
            content: "回溯于 \(fork.archivedAt.formatted(date: .numeric, time: .shortened))",
            subContent: "左侧旧路径 · 右侧新路径",
            stageOrder: fork.sourceStageOrder,
            field: nil,
            momentID: nil,
            position: .zero,
            nodeColor: Color.primaryAccent,
            isActiveBranch: true,
            branchVersion: fork.branchVersion,
            richness: 0.6,
            isGhost: false,
            processLabel: "回溯分叉",
            processIcon: "arrow.triangle.branch",
            statusText: "二叉分支",
            timestamp: fork.archivedAt,
            branchAnchorID: nil,
            branchDepth: branchDepth,
            layoutRank: layoutRank
        )
    }

    private func questionNode(
        _ moment: ThinkingMoment,
        project: Project,
        questionNumber: Int?,
        branchAnchorID: String?,
        branchDepth: Int,
        layoutRank: Int
    ) -> TreeNode {
        let field = moment.relatedField.flatMap(BriefField.init(rawValue:))
        let bindings = moment.isActiveBranch
            ? resourceBindings(for: moment, project: project)
            : []
        let answered = ThinkingTreeMomentProjector.pairedAnswer(
            for: moment,
            in: project.thinkingMoments
        ) != nil

        return TreeNode(
            id: "moment-\(moment.id)",
            kind: .question,
            content: moment.summary
                ?? QuestionTreeSummary.make(from: moment.content),
            subContent: moment.isActiveBranch ? "AI 追问" : "旧分支",
            stageOrder: moment.stageOrder,
            field: field,
            momentID: moment.id,
            position: .zero,
            nodeColor: moment.isActiveBranch
                ? Color.primaryAccent
                : Color(red: 0.58, green: 0.60, blue: 0.66),
            isActiveBranch: moment.isActiveBranch,
            branchVersion: moment.branchVersion,
            richness: moment.isActiveBranch ? 0.72 : 0.34,
            isGhost: false,
            processLabel: moment.isActiveBranch ? "问题节点" : "回溯问题",
            processIcon: moment.isActiveBranch
                ? "questionmark.circle"
                : "arrow.uturn.backward",
            statusText: moment.isActiveBranch ? "问题" : "旧问题",
            timestamp: moment.timestamp,
            branchAnchorID: branchAnchorID,
            questionNumber: questionNumber,
            questionCategory: questionCategory(field: field),
            isAnswered: answered || !moment.isActiveBranch,
            boundResources: bindings,
            branchDepth: branchDepth,
            layoutRank: layoutRank
        )
    }

    // MARK: - Question metadata

    private func questionNumbers(in project: Project) -> [UUID: Int] {
        let questions = project.thinkingMoments
            .filter {
                $0.momType == "question"
                    && ThinkingTreeMomentProjector.isVisibleInTree($0)
            }
            .sorted {
                if $0.timestamp != $1.timestamp {
                    return $0.timestamp < $1.timestamp
                }
                return $0.id.uuidString < $1.id.uuidString
            }
        return Dictionary(
            uniqueKeysWithValues: questions.enumerated().map {
                ($0.element.id, $0.offset + 1)
            }
        )
    }

    private func resourceBindings(
        for question: ThinkingMoment,
        project: Project
    ) -> [QuestionResourceBinding] {
        project.thinkingMoments
            .filter {
                $0.isActiveBranch
                    && ($0.momType == "method" || $0.momType == "evidence")
                    && $0.parentMomentID == question.id
            }
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap { method in
                let direct = method.resourceCardID.flatMap { cardID in
                    ResourceLibrary.all.first { $0.id == cardID }
                }
                let legacy = direct ?? ResourceLibrary.all.first { card in
                    method.content.contains(card.title)
                }
                guard let card = legacy else { return nil }
                return QuestionResourceBinding(
                    momentID: method.id,
                    card: card
                )
            }
    }

    private func questionCategory(
        field: BriefField?
    ) -> QuestionNodeCategory {
        switch field {
        case .painPoint:
            return .painPoint
        case .targetUser:
            return .targetUser
        case .useScenario:
            return .useScenario
        case .coreValue, .differentiation:
            return .value
        case .boundaryItems:
            return .boundary
        default:
            return .general
        }
    }
}
