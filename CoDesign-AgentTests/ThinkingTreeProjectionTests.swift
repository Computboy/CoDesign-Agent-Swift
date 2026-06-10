import Foundation
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
}
