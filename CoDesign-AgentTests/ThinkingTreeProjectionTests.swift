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

    @Test @MainActor func treeBuilderHidesAnswerNodesButKeepsArchivedBranchNodes() {
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
        #expect(tree.nodes.contains { $0.content == "旧答案影响的判断" && !$0.isActiveBranch })
        #expect(!tree.nodes.contains { $0.processLabel == "答案节点" })
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
        let oldDecision = ThinkingMoment(
            momType: "decision",
            content: "旧 Stage 2 判断",
            stageOrder: 2,
            parentMomentID: oldAnswer.id,
            timestamp: base.addingTimeInterval(2),
            isActiveBranch: false
        )
        project.thinkingMoments = [question, oldAnswer, oldDecision]

        let tree = TreeBuilder().build(project: project, expandedTransitionOrders: [], visibleStageLimit: 3)

        #expect(tree.nodes.contains { $0.kind == .branchStage && $0.stageOrder == 2 })
        #expect(tree.nodes.contains { $0.kind == .branchStage && $0.stageOrder == 3 })
    }

    @Test @MainActor func expandedTreeAnchorsArchivedNodesToQuestionBranch() {
        let base = Date()
        let project = Project(name: "回溯项目", briefDescription: "测试展开回溯")
        project.stages = [
            ProgressStage(order: 1, name: "痛点与场景锚定", status: "needsReview", completionRatio: 0.4)
        ]
        let question = moment("question", "核心问题：用户是谁？", at: base)
        let oldAnswer = moment("answer", "旧答案", at: base.addingTimeInterval(1), parentID: question.id, isActive: false)
        let oldDecision = moment("decision", "旧判断", at: base.addingTimeInterval(2), parentID: oldAnswer.id, isActive: false)
        project.thinkingMoments = [question, oldAnswer, oldDecision]

        let tree = TreeBuilder().build(project: project, expandedTransitionOrders: [1], visibleStageLimit: 1)
        let archivedQuestion = tree.nodes.first {
            $0.kind == .question &&
            !$0.isActiveBranch &&
            $0.branchAnchorID == "moment-\(question.id)"
        }

        #expect(archivedQuestion != nil)
        #expect(tree.edges.contains { edge in
            edge.fromID == archivedQuestion?.id &&
            edge.toID == "moment-\(oldDecision.id)"
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
        branchAnchorID: String? = nil
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
            timestamp: nil,
            branchAnchorID: branchAnchorID
        )
    }

    private func questionRect(center: CGPoint) -> CGRect {
        CGRect(x: center.x - 92, y: center.y - 28, width: 184, height: 56)
            .insetBy(dx: -18, dy: -18)
    }
}
