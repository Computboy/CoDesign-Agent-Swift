import Foundation
import SwiftUI
import Testing
@testable import CoDesign_Agent

struct ThinkingTreeProjectionTests {
    @Test @MainActor func scaffoldTurnsAreCollapsedIntoCoreQuestion() {
        let base = Date()
        let coreQuestion = moment("question", "核心问题：用户是谁？", at: base)
        let stuckAnswer = moment("answer", "我还不确定", at: base.addingTimeInterval(1))
        let method = moment("method", "调用依据：Persona", at: base.addingTimeInterval(2))
        let scaffoldQuestion = moment("question", "线索追问：先回想一个任务片段？", at: base.addingTimeInterval(3))
        let finalAnswer = moment("answer", "外地大一新生，报到当天会卡住。", at: base.addingTimeInterval(4))
        let nextCoreQuestion = moment("question", "下一个核心问题：场景在哪里发生？", at: base.addingTimeInterval(5))

        let visible = ThinkingTreeMomentProjector.visibleMoments([
            coreQuestion,
            stuckAnswer,
            method,
            scaffoldQuestion,
            finalAnswer,
            nextCoreQuestion,
        ])
        let paired = ThinkingTreeMomentProjector.pairedAnswer(
            for: coreQuestion,
            in: [coreQuestion, stuckAnswer, method, scaffoldQuestion, finalAnswer, nextCoreQuestion]
        )

        #expect(visible.map(\.content) == [
            "核心问题：用户是谁？",
            "下一个核心问题：场景在哪里发生？",
        ])
        #expect(paired?.content == "外地大一新生，报到当天会卡住。")
    }

    @Test @MainActor func treeBuilderKeepsArchivedNodesOutOfMainTreeUntilArchivedBranchExpands() {
        let base = Date()
        let project = Project(name: "测试项目", briefDescription: "测试树投影")
        project.stages = [
            ProgressStage(order: 1, name: "痛点与场景锚定", status: "needsReview", completionRatio: 0.4)
        ]
        let question = moment("question", "核心问题：用户是谁？", at: base)
        let oldAnswer = moment("answer", "旧答案", at: base.addingTimeInterval(1), parentID: question.id, isActive: false)
        let oldDecision = moment("decision", "旧答案影响的判断", at: base.addingTimeInterval(2), parentID: oldAnswer.id, isActive: false)
        let newAnswer = moment("answer", "新答案", at: base.addingTimeInterval(3), parentID: question.id)
        project.thinkingMoments = [question, oldAnswer, oldDecision, newAnswer]

        let tree = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            visibleStageLimit: 1
        )

        #expect(tree.nodes.contains { $0.kind == .question && $0.content == "核心问题：用户是谁？" })
        #expect(!tree.nodes.contains { $0.content == "旧答案影响的判断" && !$0.isActiveBranch })
        #expect(!tree.nodes.contains { $0.processLabel == "答案节点" })
        #expect(tree.nodes.contains { $0.kind == .branchStage && $0.stageOrder == 1 })

        let expandedTree = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            expandedArchivedStageOrders: [1],
            visibleStageLimit: 1
        )
        let archivedStage = expandedTree.nodes.first { $0.kind == .branchStage && $0.stageOrder == 1 }
        #expect(expandedTree.nodes.contains {
            $0.content == "旧答案影响的判断" &&
            !$0.isActiveBranch &&
            $0.branchAnchorID == archivedStage?.id
        })
    }

    @Test @MainActor func collapsedTreeShowsArchivedStageBranch() {
        let base = Date()
        let project = Project(name: "回溯项目", briefDescription: "测试折叠回溯")
        project.stages = (1...3).map { order in
            ProgressStage(
                order: order,
                name: "阶段 \(order)",
                status: order == 1 ? "needsReview" : "notStarted",
                completionRatio: order == 1 ? 0.4 : 0
            )
        }
        let question = moment("question", "核心问题：用户是谁？", at: base)
        let oldAnswer = moment("answer", "旧答案", at: base.addingTimeInterval(1), parentID: question.id, isActive: false)
        let oldStage2Answer = ThinkingMoment(
            momType: "answer",
            content: "旧 Stage 2 回答",
            stageOrder: 2,
            parentMomentID: oldAnswer.id,
            timestamp: base.addingTimeInterval(1.5),
            isActiveBranch: false
        )
        let oldDecision = ThinkingMoment(
            momType: "decision",
            content: "旧 Stage 2 判断",
            stageOrder: 2,
            parentMomentID: oldStage2Answer.id,
            timestamp: base.addingTimeInterval(2),
            isActiveBranch: false
        )
        project.thinkingMoments = [question, oldAnswer, oldStage2Answer, oldDecision]

        let tree = TreeBuilder().build(project: project, expandedTransitionOrders: [], visibleStageLimit: 3)

        #expect(tree.nodes.contains { $0.kind == .branchStage && $0.stageOrder == 2 })
        #expect(!tree.nodes.contains { $0.kind == .branchStage && $0.stageOrder == 3 })
    }

    @Test @MainActor func archivedBranchDoesNotShowFutureStageWithoutArchivedAnswer() {
        let base = Date()
        let project = Project(name: "回溯项目", briefDescription: "测试未回答阶段隐藏")
        project.stages = (1...4).map { order in
            ProgressStage(
                order: order,
                name: "阶段 \(order)",
                status: order == 2 ? "needsReview" : "notStarted",
                completionRatio: order == 2 ? 0.4 : 0
            )
        }

        let stage2Question = ThinkingMoment(momType: "question", content: "Stage 2 问题", stageOrder: 2, timestamp: base)
        let oldStage2Answer = ThinkingMoment(
            momType: "answer",
            content: "Stage 2 旧答案",
            stageOrder: 2,
            parentMomentID: stage2Question.id,
            timestamp: base.addingTimeInterval(1),
            isActiveBranch: false
        )
        let oldStage3Question = ThinkingMoment(
            momType: "question",
            content: "Stage 3 旧问题",
            stageOrder: 3,
            timestamp: base.addingTimeInterval(2),
            isActiveBranch: false
        )
        let oldStage3Answer = ThinkingMoment(
            momType: "answer",
            content: "Stage 3 旧答案",
            stageOrder: 3,
            parentMomentID: oldStage3Question.id,
            timestamp: base.addingTimeInterval(3),
            isActiveBranch: false
        )
        let unansweredStage4Question = ThinkingMoment(
            momType: "question",
            content: "Stage 4 只生成过问题",
            stageOrder: 4,
            timestamp: base.addingTimeInterval(4),
            isActiveBranch: false
        )
        let prematureStage4Decision = ThinkingMoment(
            momType: "decision",
            content: "Stage 4 被旧答案影响的判断",
            stageOrder: 4,
            parentMomentID: unansweredStage4Question.id,
            timestamp: base.addingTimeInterval(5),
            isActiveBranch: false
        )

        project.thinkingMoments = [
            stage2Question,
            oldStage2Answer,
            oldStage3Question,
            oldStage3Answer,
            unansweredStage4Question,
            prematureStage4Decision
        ]

        let tree = TreeBuilder().build(project: project, expandedTransitionOrders: [], visibleStageLimit: 2)

        #expect(!tree.nodes.contains { $0.id == TreeBuilder.stageNodeID(3) })
        #expect(!tree.nodes.contains { $0.id == TreeBuilder.stageNodeID(4) })
        #expect(tree.nodes.contains { $0.kind == .branchStage && $0.stageOrder == 3 })
        #expect(!tree.nodes.contains { $0.kind == .branchStage && $0.stageOrder == 4 })
    }

    @Test @MainActor func expandedArchivedStageAnchorsNodesToArchivedStage() {
        let base = Date()
        let project = Project(name: "回溯项目", briefDescription: "测试旧阶段展开")
        project.stages = (1...3).map { order in
            ProgressStage(
                order: order,
                name: "阶段 \(order)",
                status: order == 2 ? "needsReview" : "notStarted",
                completionRatio: order == 2 ? 0.4 : 0
            )
        }

        let stage2Question = ThinkingMoment(momType: "question", content: "Stage 2 问题", stageOrder: 2, timestamp: base)
        let oldStage2Answer = ThinkingMoment(
            momType: "answer",
            content: "Stage 2 旧答案",
            stageOrder: 2,
            parentMomentID: stage2Question.id,
            timestamp: base.addingTimeInterval(1),
            isActiveBranch: false
        )
        let oldStage3Question = ThinkingMoment(
            momType: "question",
            content: "Stage 3 旧问题",
            stageOrder: 3,
            timestamp: base.addingTimeInterval(2),
            isActiveBranch: false
        )
        let oldStage3Answer = ThinkingMoment(
            momType: "answer",
            content: "Stage 3 旧答案",
            stageOrder: 3,
            parentMomentID: oldStage3Question.id,
            timestamp: base.addingTimeInterval(3),
            isActiveBranch: false
        )
        let oldStage3Decision = ThinkingMoment(
            momType: "decision",
            content: "旧 Stage 3 判断",
            stageOrder: 3,
            parentMomentID: oldStage3Answer.id,
            timestamp: base.addingTimeInterval(4),
            isActiveBranch: false
        )
        project.thinkingMoments = [stage2Question, oldStage2Answer, oldStage3Question, oldStage3Answer, oldStage3Decision]

        let tree = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [],
            expandedArchivedStageOrders: [3],
            visibleStageLimit: 2
        )
        let archivedStage = tree.nodes.first { $0.kind == .branchStage && $0.stageOrder == 3 }
        let archivedQuestion = tree.nodes.first { $0.kind == .question && $0.stageOrder == 3 && !$0.isActiveBranch }

        #expect(archivedStage != nil)
        #expect(archivedQuestion?.branchAnchorID == archivedStage?.id)
        #expect(tree.nodes.first { $0.id == "moment-\(oldStage3Decision.id)" }?.branchAnchorID == archivedStage?.id)
        #expect(tree.edges.contains { $0.fromID == archivedStage?.id && $0.toID == archivedQuestion?.id })
        #expect(tree.edges.contains { $0.toID == "moment-\(oldStage3Decision.id)" })
    }

    @Test func truncatedQuestionDetailRestoresFullAssistantMessage() {
        let fullMessage = "这里更关键的线索是先做一个完整判断。请你说明第一版要保留什么，又暂时不做什么？"
        let node = layoutNode(
            id: "question",
            kind: .question,
            content: "这里更关键的线索是先做一个完整判断...",
            stageOrder: 3
        )
        let message = ChatMessage(role: "assistant", content: fullMessage)

        #expect(ThinkingTreeMomentProjector.displayQuestionText(for: node, in: [message]) == fullMessage)
    }

    @Test @MainActor func expandedArchivedBranchShowsOriginalQuestionAndAffectedNodesInOneBranch() {
        let base = Date()
        let project = Project(name: "回溯项目", briefDescription: "测试展开回溯")
        project.stages = [
            ProgressStage(order: 1, name: "痛点与场景锚定", status: "needsReview", completionRatio: 0.4)
        ]
        let question = moment("question", "核心问题：用户是谁？", at: base)
        let oldAnswer = moment("answer", "旧答案", at: base.addingTimeInterval(1), parentID: question.id, isActive: false)
        let oldDecision = moment("decision", "旧判断", at: base.addingTimeInterval(2), parentID: oldAnswer.id, isActive: false)
        project.thinkingMoments = [question, oldAnswer, oldDecision]

        let tree = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            expandedArchivedStageOrders: [1],
            visibleStageLimit: 1
        )
        let archivedStage = tree.nodes.first { $0.kind == .branchStage && $0.stageOrder == 1 }
        let archivedQuestion = tree.nodes.first {
            $0.kind == .question &&
            !$0.isActiveBranch &&
            $0.branchAnchorID == archivedStage?.id
        }

        #expect(archivedStage != nil)
        #expect(archivedQuestion != nil)
        #expect(tree.edges.contains { edge in
            edge.fromID == archivedStage?.id &&
            edge.toID == archivedQuestion?.id
        })
        #expect(tree.edges.contains { edge in
            edge.fromID == archivedQuestion?.id &&
            edge.toID == "moment-\(oldDecision.id)"
        })
    }

    @Test @MainActor func recommendedResourcesAttachToLatestActiveQuestion() {
        let base = Date()
        let project = Project(name: "资源连接测试", briefDescription: "测试 RAG 连线")
        project.stages = [
            ProgressStage(order: 1, name: "痛点与场景锚定", status: "active", completionRatio: 0.4)
        ]
        let firstQuestion = moment("question", "第一个问题", at: base)
        let latestQuestion = moment("question", "最新问题", at: base.addingTimeInterval(2))
        project.thinkingMoments = [firstQuestion, latestQuestion]
        let resource = ResourceCard(
            id: "journey-map",
            title: "User Journey Map",
            type: .method,
            relatedStages: [1],
            tags: ["journey"],
            summary: "用于梳理用户旅程。",
            whyRelevant: "适合澄清场景。",
            howToUse: "连接当前问题节点。"
        )

        let tree = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            evidenceResourcesByStage: [1: [resource]],
            visibleStageLimit: 1
        )

        #expect(tree.edges.contains { edge in
            edge.fromID == "moment-\(latestQuestion.id)" &&
            edge.toID == "evidence-1-journey-map"
        })
    }

    @Test func layoutSeparatesArchivedQuestionNodesWithSharedTarget() {
        let activeQuestionID = "moment-active-question"
        let nodes = [
            layoutNode(id: TreeBuilder.rootID, kind: .root, content: "根节点", stageOrder: nil),
            layoutNode(id: TreeBuilder.stageNodeID(1), kind: .stage, content: "Stage 1", stageOrder: 1),
            layoutNode(id: activeQuestionID, kind: .question, content: "现在的问题节点", stageOrder: 1),
            layoutNode(
                id: "archived-question-1",
                kind: .question,
                content: "旧问题节点 A",
                stageOrder: 1,
                isActive: false,
                branchAnchorID: activeQuestionID
            ),
            layoutNode(
                id: "archived-question-2",
                kind: .question,
                content: "旧问题节点 B",
                stageOrder: 1,
                isActive: false,
                branchAnchorID: activeQuestionID
            ),
            layoutNode(
                id: "archived-question-3",
                kind: .question,
                content: "旧问题节点 C",
                stageOrder: 1,
                isActive: false,
                branchAnchorID: activeQuestionID
            ),
        ]
        let layout = TreeLayoutEngine(
            stageSpacing: 160,
            sideBranchSpacing: 340,
            topPadding: 82,
            bottomPadding: 132,
            contentWidth: 760
        ).layout(TreeData(nodes: nodes, edges: [], contentSize: .zero), in: CGSize(width: 760, height: 620))
        let archivedRects = layout.nodes
            .filter { node in
                if case .question = node.kind {
                    return node.isArchived
                }
                return false
            }
            .map { questionRect(center: $0.position) }

        #expect(archivedRects.count == 3)
        for lhsIndex in archivedRects.indices {
            for rhsIndex in archivedRects.indices where lhsIndex < rhsIndex {
                #expect(!archivedRects[lhsIndex].intersects(archivedRects[rhsIndex]))
            }
        }
    }

    @Test func canonicalLayoutDoesNotChangeWithViewportSize() {
        let nodes = [
            layoutNode(id: TreeBuilder.rootID, kind: .root, content: "根节点", stageOrder: nil),
            layoutNode(id: TreeBuilder.stageNodeID(1), kind: .stage, content: "Stage 1", stageOrder: 1),
            layoutNode(id: "question-1", kind: .question, content: "核心问题", stageOrder: 1),
            layoutNode(id: "evidence-1", kind: .evidence, content: "设计依据", stageOrder: 1),
        ]
        let raw = TreeData(nodes: nodes, edges: [], contentSize: .zero)

        let embedded = MindTreeCanonicalLayout.layout(
            raw,
            visibleStageLimit: 9,
            in: CGSize(width: 480, height: 820)
        )
        let fullScreen = MindTreeCanonicalLayout.layout(
            raw,
            visibleStageLimit: 9,
            in: CGSize(width: 1_366, height: 920)
        )

        #expect(embedded.contentSize == fullScreen.contentSize)
        #expect(embedded.nodes.map(\.id) == fullScreen.nodes.map(\.id))
        for embeddedNode in embedded.nodes {
            let fullScreenNode = fullScreen.node(for: embeddedNode.id)
            #expect(embeddedNode.position == fullScreenNode?.position)
        }
    }

    @Test func layoutPlacesExpandedArchivedStageContentInSingleTimelineColumn() {
        let branchStageID = "branch-stage-2-3"
        let base = Date()
        let nodes = [
            layoutNode(id: TreeBuilder.rootID, kind: .root, content: "根节点", stageOrder: nil),
            layoutNode(id: TreeBuilder.stageNodeID(1), kind: .stage, content: "Stage 1", stageOrder: 1),
            layoutNode(id: TreeBuilder.stageNodeID(2), kind: .stage, content: "Stage 2", stageOrder: 2),
            layoutNode(id: branchStageID, kind: .branchStage, content: "Stage 3", stageOrder: 3, isActive: false),
            layoutNode(
                id: "active-process",
                kind: .process,
                content: "当前主树卡片",
                stageOrder: 3,
                isActive: true,
                timestamp: base.addingTimeInterval(0.25)
            ),
            layoutNode(
                id: "active-evidence",
                kind: .evidence,
                content: "当前依据卡片",
                stageOrder: 3,
                isActive: true,
                timestamp: base.addingTimeInterval(0.5)
            ),
            layoutNode(
                id: "archived-timeline-1",
                kind: .question,
                content: "旧问题 1",
                stageOrder: 3,
                isActive: false,
                branchAnchorID: branchStageID,
                timestamp: base
            ),
            layoutNode(
                id: "archived-timeline-2",
                kind: .revision,
                content: "旧判断 2",
                stageOrder: 3,
                isActive: false,
                branchAnchorID: branchStageID,
                timestamp: base.addingTimeInterval(1)
            ),
            layoutNode(
                id: "archived-timeline-3",
                kind: .evidence,
                content: "旧依据 3",
                stageOrder: 3,
                isActive: false,
                branchAnchorID: branchStageID,
                timestamp: base.addingTimeInterval(2)
            ),
            layoutNode(
                id: "archived-timeline-4",
                kind: .question,
                content: "旧问题 4",
                stageOrder: 3,
                isActive: false,
                branchAnchorID: branchStageID,
                timestamp: base.addingTimeInterval(3)
            ),
        ]

        let layout = TreeLayoutEngine(
            stageSpacing: 160,
            sideBranchSpacing: 340,
            topPadding: 82,
            bottomPadding: 132,
            contentWidth: 1_180
        ).layout(TreeData(nodes: nodes, edges: [], contentSize: .zero), in: CGSize(width: 1_180, height: 900))
        let timelineNodes = layout.nodes
            .filter { $0.branchAnchorID == branchStageID }
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

        #expect(timelineNodes.count == 4)
        let firstX = timelineNodes.first?.position.x ?? 0
        for node in timelineNodes {
            #expect(abs(node.position.x - firstX) < 0.5)
        }
        for index in 1..<timelineNodes.count {
            #expect(timelineNodes[index].position.y > timelineNodes[index - 1].position.y)
        }
        let activeNodes = layout.nodes.filter { $0.isActiveBranch && isMainSideCard($0) }
        #expect(activeNodes.allSatisfy { node in
            node.position.x < firstX - 220
        })
        let rects = timelineNodes.map { collisionRect(for: $0) }
        for lhsIndex in rects.indices {
            for rhsIndex in rects.indices where lhsIndex < rhsIndex {
                #expect(!rects[lhsIndex].intersects(rects[rhsIndex]))
            }
        }
        for activeNode in activeNodes {
            let activeRect = collisionRect(for: activeNode)
            for timelineRect in rects {
                #expect(!activeRect.intersects(timelineRect))
            }
        }
    }

    @MainActor private func moment(
        _ type: String,
        _ content: String,
        at timestamp: Date,
        parentID: UUID? = nil,
        isActive: Bool = true
    ) -> ThinkingMoment {
        ThinkingMoment(
            momType: type,
            content: content,
            stageOrder: 1,
            parentMomentID: parentID,
            timestamp: timestamp,
            isActiveBranch: isActive
        )
    }

    private func layoutNode(
        id: String,
        kind: TreeNodeKind,
        content: String,
        stageOrder: Int?,
        isActive: Bool = true,
        branchAnchorID: String? = nil,
        timestamp: Date? = nil
    ) -> TreeNode {
        TreeNode(
            id: id,
            kind: kind,
            content: content,
            subContent: nil,
            stageOrder: stageOrder,
            field: nil,
            momentID: nil,
            position: .zero,
            nodeColor: .primaryAccent,
            isActiveBranch: isActive,
            branchVersion: 1,
            richness: 0.4,
            isGhost: false,
            processLabel: nil,
            processIcon: nil,
            statusText: nil,
            resource: nil,
            timestamp: timestamp,
            branchAnchorID: branchAnchorID
        )
    }

    private func questionRect(center: CGPoint) -> CGRect {
        let size = TreeNodeMetrics.questionSize
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
            .insetBy(dx: -18, dy: -18)
    }

    private func isMainSideCard(_ node: TreeNode) -> Bool {
        switch node.kind {
        case .process, .evidence:
            return true
        case .root, .stage, .branchStage, .question, .field, .revision:
            return false
        }
    }

    private func collisionRect(for node: TreeNode) -> CGRect {
        let size = TreeNodeMetrics.size(for: node.kind)

        return CGRect(
            x: node.position.x - size.width / 2,
            y: node.position.y - size.height / 2,
            width: size.width,
            height: size.height
        ).insetBy(dx: -18, dy: -18)
    }
}
