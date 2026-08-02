import Foundation
import SwiftUI
import SwiftData
import Testing
@testable import CoDesign_Agent

struct ThinkingTreeProjectionTests {
    @Test func dottedBackgroundScalesSpacingAndDotSizeTogether() {
        let baseSpacing = MindTreeDottedBackgroundMetrics.spacing(for: 1)
        let baseDiameter = MindTreeDottedBackgroundMetrics.dotDiameter(for: 1)

        #expect(
            MindTreeDottedBackgroundMetrics.spacing(for: 1.8)
                == baseSpacing * 1.8
        )
        #expect(
            MindTreeDottedBackgroundMetrics.dotDiameter(for: 0.6)
                == baseDiameter * 0.6
        )
    }

    @Test func dottedBackgroundPhaseFollowsCanvasOffset() {
        let phase = MindTreeDottedBackgroundMetrics.phase(
            for: CGSize(width: 37, height: -22),
            scale: 1
        )

        #expect(phase.x == 1)
        #expect(phase.y == -4)
    }

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
        #expect(!expandedTree.nodes.contains {
            $0.content == "旧答案影响的判断"
        })
        #expect(project.thinkingMoments.contains {
            $0.id == oldDecision.id && !$0.isActiveBranch
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

        #expect(tree.nodes.contains { $0.kind == .branchStage && $0.stageOrder == 1 })
        #expect(tree.nodes.filter { $0.kind == .branchStage }.count == 1)
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
        #expect(tree.nodes.contains { $0.kind == .branchStage && $0.stageOrder == 2 })
        #expect(tree.nodes.filter { $0.kind == .branchStage }.count == 1)
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
            expandedArchivedStageOrders: [2],
            visibleStageLimit: 2
        )
        let archivedStage = tree.nodes.first { $0.kind == .branchStage && $0.stageOrder == 2 }
        let archivedQuestion = tree.nodes.first { $0.kind == .question && $0.stageOrder == 3 && !$0.isActiveBranch }

        #expect(archivedStage != nil)
        #expect(archivedQuestion?.branchAnchorID == archivedStage?.id)
        #expect(tree.edges.contains { $0.fromID == archivedStage?.id && $0.toID == archivedQuestion?.id })
        #expect(!tree.nodes.contains { $0.id == "moment-\(oldStage3Decision.id)" })
        #expect(project.thinkingMoments.contains { $0.id == oldStage3Decision.id })
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

    @Test func questionSummaryKeepsFullQuestionSeparateFromCompactTreeLabel() {
        let question = "所以这轮我只想先确认：主人离家时，智能狗窝首先应该帮助他确认哪一种最关键的状态？"
        let summary = QuestionTreeSummary.make(from: question)

        #expect(summary.count <= QuestionTreeSummary.preferredCharacterLimit)
        #expect(summary != question)
        #expect(summary.contains("主人离家"))
    }

    @Test @MainActor func expandedArchivedBranchKeepsForkQuestionSharedAndAffectedNodesOnOldBranch() {
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
        #expect(archivedStage != nil)
        #expect(tree.nodes.filter { $0.momentID == question.id && $0.kind == .question }.count == 1)
        #expect(!tree.nodes.contains { $0.id == "moment-\(oldDecision.id)" })
        #expect(project.thinkingMoments.contains {
            $0.id == oldDecision.id && !$0.isActiveBranch
        })
    }

    @Test @MainActor func persistedResourcesRemainLocalToTheirBoundQuestion() {
        let base = Date()
        let project = Project(name: "资源连接测试", briefDescription: "测试 RAG 连线")
        project.stages = [
            ProgressStage(order: 1, name: "痛点与场景锚定", status: "active", completionRatio: 0.4)
        ]
        let firstQuestion = moment("question", "第一个问题", at: base)
        let latestQuestion = moment("question", "最新问题", at: base.addingTimeInterval(2))
        let resource = ResourceLibrary.all[0]
        let method = ThinkingMoment(
            momType: "method",
            content: "调用依据：\(resource.title)",
            stageOrder: 1,
            resourceCardID: resource.id,
            parentMomentID: latestQuestion.id,
            timestamp: base.addingTimeInterval(3)
        )
        project.thinkingMoments = [firstQuestion, latestQuestion, method]

        let tree = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            visibleStageLimit: 1
        )

        #expect(!tree.nodes.contains { $0.momentID == method.id })
        #expect(!tree.edges.contains { $0.id.contains(method.id.uuidString) })
        #expect(tree.nodes.first { $0.id == "moment-\(firstQuestion.id)" }?.boundResources.isEmpty == true)
        #expect(tree.nodes.first { $0.id == "moment-\(latestQuestion.id)" }?.boundResources.map(\.card.id) == [resource.id])

        let layout = MindTreeCanonicalLayout.layout(
            tree,
            visibleStageLimit: 1,
            in: CGSize(width: 1_000, height: 800)
        )
        let attachment = QuestionResourceDeckLayout.presentations(
            graph: layout,
            progressByQuestionID: [
                "moment-\(latestQuestion.id)": 1
            ]
        ).first
        let owner = layout.node(for: "moment-\(latestQuestion.id)")

        #expect(attachment?.questionID == owner?.id)
        #expect(attachment?.center.y == owner?.position.y)
        #expect((attachment?.center.x ?? 0) > (owner?.position.x ?? 0))
    }

    @Test @MainActor func fiveResourceCardsStayCollapsedBehindOwnerAndExpandInOneHorizontalBand() {
        let base = Date()
        let project = Project(name: "五卡横向卡组", briefDescription: "")
        project.stages = [
            ProgressStage(
                order: 1,
                name: "阶段 1",
                status: "active",
                completionRatio: 0.4
            )
        ]
        let question = moment("question", "用户最担心什么？", at: base)
        let resources = ResourceType.allCases.compactMap { type in
            ResourceLibrary.all.first { $0.type == type }
        }
        #expect(resources.count == ResourceType.allCases.count)

        let methods = resources.enumerated().map { index, resource in
            ThinkingMoment(
                momType: "method",
                content: "调用依据：\(resource.title)",
                stageOrder: 1,
                resourceCardID: resource.id,
                parentMomentID: question.id,
                timestamp: base.addingTimeInterval(Double(index + 1))
            )
        }
        project.thinkingMoments = [question] + methods

        let graph = MindTreeCanonicalLayout.layout(
            TreeBuilder().build(
                project: project,
                expandedTransitionOrders: [1],
                visibleStageLimit: 1
            ),
            visibleStageLimit: 1,
            in: CGSize(width: 1_000, height: 800)
        )
        let questionID = "moment-\(question.id)"
        let owner = graph.node(for: questionID)!
        let collapsed = QuestionResourceDeckLayout.presentations(
            graph: graph,
            progressByQuestionID: [questionID: 0]
        )
        let expanded = QuestionResourceDeckLayout.presentations(
            graph: graph,
            progressByQuestionID: [questionID: 1]
        )

        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)
        #expect(owner.boundResources.count == resources.count)
        #expect(collapsed.count == resources.count)
        #expect(expanded.count == resources.count)
        #expect(collapsed.allSatisfy { $0.center.y == owner.position.y })
        #expect(expanded.allSatisfy { $0.center.y == owner.position.y })

        let ownerTrailing = owner.position.x
            + TreeNodeMetrics.questionSize.width / 2
        let reveals = collapsed.map {
            $0.center.x
                + QuestionResourceDeckMetrics.cardSize.width / 2
                - ownerTrailing
        }
        #expect(reveals == [8, 16, 24, 24, 24])

        for index in 1..<expanded.count {
            let delta = expanded[index].center.x
                - expanded[index - 1].center.x
            #expect(
                abs(
                    delta
                        - QuestionResourceDeckMetrics.cardSize.width
                        - QuestionResourceDeckMetrics.cardSpacing
                ) < 0.001
            )
        }

        let expandedCanvas = QuestionResourceDeckLayout.canvasContentSize(
            graph: graph,
            progressByQuestionID: [questionID: 1]
        )
        let annotationFrames = Dictionary(
            uniqueKeysWithValues: QuestionResourceDeckLayout.annotationFrames(
                graph: graph
            ).map { ($0.anchor, $0) }
        )
        #expect(expandedCanvas.width > graph.contentSize.width)
        #expect(graph.node(for: questionID)?.position == owner.position)
        #expect(!graph.nodes.contains { methods.map(\.id).contains($0.momentID) })
        for (method, presentation) in zip(methods, expanded) {
            let anchor = MindTreeAnnotationAnchor.moment(
                id: method.id,
                branchVersion: presentation.questionBranchVersion,
                stageOrder: presentation.questionStageOrder
            )
            #expect(
                annotationFrames[anchor]?.x
                    == Double(presentation.center.x)
            )
            #expect(
                annotationFrames[anchor]?.y
                    == Double(presentation.center.y)
            )
        }
    }

    @Test func resourceAnnotationOpacityFadesOnlyNearExpandedPosition() {
        let hidden = QuestionResourceDeckLayout.annotationOpacity(
            cardProgress: 0.72
        )
        let fading = QuestionResourceDeckLayout.annotationOpacity(
            cardProgress: 0.86
        )
        let visible = QuestionResourceDeckLayout.annotationOpacity(
            cardProgress: 1
        )

        #expect(hidden == 0)
        #expect(fading > 0 && fading < 1)
        #expect(visible == 1)
    }

    @Test func resourceDeckDragProgressUsesDirectionalThresholdsAndStableY() {
        let half = QuestionResourceDeckLayout.progress(
            isExpanded: false,
            translationX:
                QuestionResourceDeckMetrics.expansionDragDistance / 2
        )
        let clampedLeft = QuestionResourceDeckLayout.progress(
            isExpanded: false,
            translationX: -200
        )
        let clampedRight = QuestionResourceDeckLayout.progress(
            isExpanded: true,
            translationX: 200
        )

        #expect(abs(half - 0.5) < 0.001)
        #expect(clampedLeft == 0)
        #expect(clampedRight == 1)
        #expect(
            QuestionResourceDeckLayout.shouldExpand(
                isExpanded: false,
                translationX: 82,
                predictedTranslationX: 100
            )
        )
        #expect(
            !QuestionResourceDeckLayout.shouldExpand(
                isExpanded: false,
                translationX: 40,
                predictedTranslationX: 40
            )
        )
        #expect(
            !QuestionResourceDeckLayout.shouldExpand(
                isExpanded: true,
                translationX: -58,
                predictedTranslationX: -120
            )
        )
        #expect(
            !QuestionResourceDeckLayout.shouldExpand(
                isExpanded: true,
                translationX: -58,
                predictedTranslationX: -20
            )
        )
        #expect(
            QuestionResourceDeckLayout.shouldExpand(
                isExpanded: true,
                translationX: -40,
                predictedTranslationX: -42
            )
        )

        for index in 0..<5 {
            #expect(
                QuestionResourceDeckLayout.localCenterOffset(
                    cardIndex: index,
                    cardCount: 5,
                    deckProgress: 0.63
                ).y == 0
            )
        }
    }

    @Test func resourceDeckDragSourcesUseDirectManipulationDirections() {
        let rightward = CGSize(width: 96, height: 8)
        let leftward = CGSize(width: -96, height: 8)
        let vertical = CGSize(width: 8, height: 96)

        #expect(
            QuestionResourceDeckInteraction.acceptsDrag(
                source: .questionNode,
                isExpanded: false,
                translation: rightward
            )
        )
        #expect(
            !QuestionResourceDeckInteraction.acceptsDrag(
                source: .questionNode,
                isExpanded: true,
                translation: leftward
            )
        )
        #expect(
            QuestionResourceDeckInteraction.acceptsDrag(
                source: .resourceCard,
                isExpanded: true,
                translation: leftward
            )
        )
        #expect(
            !QuestionResourceDeckInteraction.acceptsDrag(
                source: .resourceCard,
                isExpanded: false,
                translation: leftward
            )
        )
        #expect(
            !QuestionResourceDeckInteraction.acceptsDrag(
                source: .resourceCard,
                isExpanded: true,
                translation: vertical
            )
        )
    }

    @Test @MainActor func resourceDecksForDifferentQuestionsKeepIndependentProgress() {
        let base = Date()
        let project = Project(name: "独立卡组", briefDescription: "")
        project.stages = [
            ProgressStage(
                order: 1,
                name: "阶段 1",
                status: "active",
                completionRatio: 0.4
            )
        ]
        let firstQuestion = moment("question", "问题 01", at: base)
        let secondQuestion = moment(
            "question",
            "问题 02",
            at: base.addingTimeInterval(2)
        )
        let firstResource = ResourceLibrary.all[0]
        let secondResource = ResourceLibrary.all[1]
        let firstMethod = ThinkingMoment(
            momType: "method",
            content: firstResource.title,
            stageOrder: 1,
            resourceCardID: firstResource.id,
            parentMomentID: firstQuestion.id,
            timestamp: base.addingTimeInterval(1)
        )
        let secondMethod = ThinkingMoment(
            momType: "evidence",
            content: secondResource.title,
            stageOrder: 1,
            resourceCardID: secondResource.id,
            parentMomentID: secondQuestion.id,
            timestamp: base.addingTimeInterval(3)
        )
        project.thinkingMoments = [
            firstQuestion,
            firstMethod,
            secondQuestion,
            secondMethod,
        ]

        let graph = MindTreeCanonicalLayout.layout(
            TreeBuilder().build(
                project: project,
                expandedTransitionOrders: [1],
                visibleStageLimit: 1
            ),
            visibleStageLimit: 1,
            in: .zero
        )
        let firstID = "moment-\(firstQuestion.id)"
        let secondID = "moment-\(secondQuestion.id)"
        let presentations = QuestionResourceDeckLayout.presentations(
            graph: graph,
            progressByQuestionID: [
                firstID: 0,
                secondID: 1,
            ]
        )
        let firstDeck = presentations.filter { $0.questionID == firstID }
        let secondDeck = presentations.filter { $0.questionID == secondID }

        #expect(firstDeck.map(\.binding.momentID) == [firstMethod.id])
        #expect(secondDeck.map(\.binding.momentID) == [secondMethod.id])
        #expect(firstDeck.allSatisfy { $0.deckProgress == 0 })
        #expect(secondDeck.allSatisfy { $0.deckProgress == 1 })
        #expect(firstDeck.first?.center.y == graph.node(for: firstID)?.position.y)
        #expect(secondDeck.first?.center.y == graph.node(for: secondID)?.position.y)
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

    @Test func rollbackLayoutPlacesOldPathLeftAndNewPathRight() {
        let branchID = "branch-stage-1-1"
        let nodes = [
            layoutNode(id: TreeBuilder.rootID, kind: .root, content: "根节点", stageOrder: nil),
            layoutNode(id: TreeBuilder.stageNodeID(1), kind: .stage, content: "Stage 1", stageOrder: 1),
            layoutNode(id: branchID, kind: .branchStage, content: "回溯", stageOrder: 1),
            layoutNode(
                id: "old-question",
                kind: .question,
                content: "旧问题",
                stageOrder: 1,
                isActive: false,
                branchAnchorID: branchID
            ),
            layoutNode(
                id: "new-question",
                kind: .question,
                content: "新问题",
                stageOrder: 1,
                isActive: true,
                branchAnchorID: branchID
            ),
        ]

        let layout = TreeLayoutEngine(
            stageSpacing: 420,
            sideBranchSpacing: 330,
            topPadding: 82,
            bottomPadding: 132,
            contentWidth: 1_240
        ).layout(
            TreeData(nodes: nodes, edges: [], contentSize: .zero),
            in: CGSize(width: 1_240, height: 900)
        )

        let forkX = layout.node(for: branchID)?.position.x ?? 0
        let oldX = layout.node(for: "old-question")?.position.x ?? 0
        let newX = layout.node(for: "new-question")?.position.x ?? 0
        #expect(oldX < forkX)
        #expect(newX > forkX)
    }

    @Test @MainActor func activeTrunkNumbersStayCanonicalWhenOldBranchCoexists() {
        let fixture = rollbackFixture(stageStatus: "needsReview")
        let tree = TreeBuilder().build(
            project: fixture.project,
            expandedTransitionOrders: [1],
            visibleStageLimit: 1
        )

        let activeNumbers = tree.nodes
            .filter { $0.kind == .question && $0.isActiveBranch }
            .sorted { ($0.questionNumber ?? 0) < ($1.questionNumber ?? 0) }
            .compactMap(\.questionNumber)
        #expect(activeNumbers == [1, 2, 3, 4, 5, 6])

        let oldNumbers = tree.nodes
            .filter { $0.kind == .question && !$0.isActiveBranch }
            .sorted { ($0.questionNumber ?? 0) < ($1.questionNumber ?? 0) }
            .compactMap(\.questionNumber)
        #expect(oldNumbers == [4, 5, 6])
        #expect(
            tree.nodes.contains {
                $0.isActiveBranch && $0.questionNumber == 4
            }
        )
        #expect(
            tree.nodes.contains {
                !$0.isActiveBranch && $0.questionNumber == 4
            }
        )
    }

    @Test @MainActor func legacyArchivedParentStillSharesNumberWithActiveTrunk() {
        let base = Date()
        let archivedAt = base.addingTimeInterval(10)
        let project = stageProject(stageOneStatus: "needsReview")
        let activeFirst = question("当前问题 01", stage: 1, at: base)
        let archivedAnchor = question(
            "旧分叉锚点",
            stage: 1,
            at: base.addingTimeInterval(1),
            isActive: false,
            archivedAt: archivedAt
        )
        let archivedAnswer = ThinkingMoment(
            momType: "answer",
            content: "旧回答",
            stageOrder: 1,
            parentMomentID: archivedAnchor.id,
            timestamp: base.addingTimeInterval(1.5),
            isActiveBranch: false,
            archivedAt: archivedAt
        )
        let archivedFollowup = question(
            "旧问题 02",
            stage: 1,
            at: base.addingTimeInterval(2),
            parentID: archivedAnchor.id,
            isActive: false,
            archivedAt: archivedAt
        )
        let activeReplacement = question(
            "当前问题 02",
            stage: 1,
            at: base.addingTimeInterval(3),
            branchVersion: 2
        )
        project.thinkingMoments = [
            activeFirst,
            archivedAnchor,
            archivedAnswer,
            archivedFollowup,
            activeReplacement,
        ]

        let tree = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            visibleStageLimit: 1
        )

        #expect(
            tree.nodes.contains {
                $0.momentID == activeReplacement.id
                    && $0.questionNumber == 2
                    && $0.isActiveBranch
            }
        )
        #expect(
            tree.nodes.contains {
                $0.momentID == archivedFollowup.id
                    && $0.questionNumber == 2
                    && !$0.isActiveBranch
            }
        )
    }

    @Test @MainActor func repeatedRollbacksCreateNestedBinaryForks() {
        let base = Date()
        let firstRollback = base.addingTimeInterval(10)
        let secondRollback = base.addingTimeInterval(20)
        let project = Project(name: "连续回溯", briefDescription: "测试嵌套二叉分支")
        project.stages = [
            ProgressStage(order: 1, name: "阶段 1", status: "needsReview", completionRatio: 0.4)
        ]

        let firstQuestion = moment("question", "第一次回溯前的问题？", at: base)
        let firstOldAnswer = ThinkingMoment(
            momType: "answer",
            content: "第一次旧答案",
            stageOrder: 1,
            parentMomentID: firstQuestion.id,
            timestamp: base.addingTimeInterval(1),
            isActiveBranch: false,
            branchVersion: 1,
            archivedAt: firstRollback
        )
        let firstOldDecision = ThinkingMoment(
            momType: "decision",
            content: "第一次旧判断",
            stageOrder: 1,
            parentMomentID: firstOldAnswer.id,
            timestamp: base.addingTimeInterval(2),
            isActiveBranch: false,
            branchVersion: 1,
            archivedAt: firstRollback
        )
        let secondQuestion = moment(
            "question",
            "第一次修改后的新问题？",
            at: base.addingTimeInterval(11)
        )
        let secondOldAnswer = ThinkingMoment(
            momType: "answer",
            content: "第二次旧答案",
            stageOrder: 1,
            parentMomentID: secondQuestion.id,
            timestamp: base.addingTimeInterval(12),
            isActiveBranch: false,
            branchVersion: 2,
            archivedAt: secondRollback
        )
        let secondOldDecision = ThinkingMoment(
            momType: "decision",
            content: "第二次旧判断",
            stageOrder: 1,
            parentMomentID: secondOldAnswer.id,
            timestamp: base.addingTimeInterval(13),
            isActiveBranch: false,
            branchVersion: 2,
            archivedAt: secondRollback
        )
        let latestQuestion = moment(
            "question",
            "第二次修改后的新问题？",
            at: base.addingTimeInterval(21)
        )
        project.thinkingMoments = [
            firstQuestion,
            firstOldAnswer,
            firstOldDecision,
            secondQuestion,
            secondOldAnswer,
            secondOldDecision,
            latestQuestion
        ]

        let rawTree = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            expandedArchivedStageOrders: [1],
            visibleStageLimit: 1
        )
        let forks = rawTree.nodes
            .filter { $0.kind == .branchStage }
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

        #expect(forks.count == 2)
        #expect(forks.map(\.branchDepth) == [0, 1])
        #expect(!rawTree.nodes.contains { $0.id == "moment-\(firstOldDecision.id)" })
        #expect(!rawTree.nodes.contains { $0.id == "moment-\(secondOldDecision.id)" })

        let layout = TreeLayoutEngine(
            stageSpacing: 620,
            sideBranchSpacing: 330,
            topPadding: 82,
            bottomPadding: 132,
            contentWidth: 1_520
        ).layout(
            rawTree,
            in: CGSize(width: 1_520, height: 1_260)
        )

        let firstForkX = layout.node(for: forks[0].id)?.position.x ?? 0
        let secondForkX = layout.node(for: forks[1].id)?.position.x ?? 0
        let secondQuestionX = layout.node(for: "moment-\(secondQuestion.id)")?.position.x ?? 0
        let latestQuestionX = layout.node(for: "moment-\(latestQuestion.id)")?.position.x ?? 0

        #expect(secondQuestionX > firstForkX)
        #expect(secondForkX > firstForkX)
        #expect(latestQuestionX > secondForkX)
    }

    @Test @MainActor func archivedQuestionsNeverExposeResourceCards() {
        let base = Date()
        let project = Project(name: "旧资源测试", briefDescription: "")
        project.stages = [
            ProgressStage(order: 1, name: "阶段 1", status: "needsReview", completionRatio: 0.4)
        ]
        let archivedQuestion = ThinkingMoment(
            momType: "question",
            content: "旧问题？",
            stageOrder: 1,
            timestamp: base,
            isActiveBranch: false
        )
        let archivedAnswer = ThinkingMoment(
            momType: "answer",
            content: "旧答案",
            stageOrder: 1,
            parentMomentID: archivedQuestion.id,
            timestamp: base.addingTimeInterval(1),
            isActiveBranch: false
        )
        let resource = ResourceLibrary.all[0]
        let archivedMethod = ThinkingMoment(
            momType: "method",
            content: "调用依据：\(resource.title)",
            stageOrder: 1,
            resourceCardID: resource.id,
            parentMomentID: archivedQuestion.id,
            timestamp: base.addingTimeInterval(2),
            isActiveBranch: false
        )
        project.thinkingMoments = [archivedQuestion, archivedAnswer, archivedMethod]

        let tree = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            expandedArchivedStageOrders: [1],
            visibleStageLimit: 1
        )

        #expect(tree.nodes.filter { $0.kind == .question && !$0.isActiveBranch }
            .allSatisfy { $0.boundResources.isEmpty })
        #expect(!tree.nodes.contains { $0.momentID == archivedMethod.id })
    }

    @Test @MainActor func layoutPlacesExpandedArchivedStageContentInSingleTimelineColumn() {
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
                kind: .process,
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
                kind: .revision,
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
            .filter {
                $0.branchAnchorID == branchStageID
                    && $0.kind == .question
                    && $0.isArchived
            }
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

        #expect(timelineNodes.count == 2)
        let firstX = timelineNodes.first?.position.x ?? 0
        for node in timelineNodes {
            #expect(abs(node.position.x - firstX) < 0.5)
        }
        for index in 1..<timelineNodes.count {
            #expect(timelineNodes[index].position.y < timelineNodes[index - 1].position.y)
        }
        let activeNodes = layout.nodes.filter { $0.isActiveBranch && isMainSideCard($0) }
        #expect(activeNodes.allSatisfy { node in
            node.position.x > firstX + 220
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

    @Test @MainActor func scenarioAInProgressStageHasQuestionsButNoStageCardOrCollapseEdge() {
        let base = Date()
        let project = stageProject(stageOneStatus: "active")
        let q1 = question("问题 01", stage: 1, at: base)
        let q2 = question(
            "问题 02",
            stage: 1,
            at: base.addingTimeInterval(1),
            parentID: q1.id
        )
        let q3 = question(
            "问题 03",
            stage: 1,
            at: base.addingTimeInterval(2),
            parentID: q2.id
        )
        project.thinkingMoments = [q1, q2, q3]

        let raw = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [],
            visibleStageLimit: 2
        )
        let layout = MindTreeCanonicalLayout.layout(
            raw,
            visibleStageLimit: 2,
            in: CGSize(width: 1_000, height: 800)
        )

        #expect(!raw.nodes.contains { $0.kind == .stage })
        #expect(raw.nodes.filter { $0.kind == .question }.count == 3)
        #expect(!raw.edges.contains { $0.togglesTransitionOrder != nil })
        #expect(layout.node(for: "moment-\(q3.id)")!.position.y
            < layout.node(for: "moment-\(q2.id)")!.position.y)
        #expect(layout.node(for: "moment-\(q2.id)")!.position.y
            < layout.node(for: "moment-\(q1.id)")!.position.y)
        #expect(layout.node(for: "moment-\(q1.id)")!.position.y
            < layout.node(for: TreeBuilder.rootID)!.position.y)
    }

    @Test @MainActor func scenarioBRollbackKeepsOldLeftAndMovesActiveTrunkRightWithoutStageCard() {
        let fixture = rollbackFixture(stageStatus: "needsReview")
        let raw = TreeBuilder().build(
            project: fixture.project,
            expandedTransitionOrders: [],
            visibleStageLimit: 1
        )
        let layout = MindTreeCanonicalLayout.layout(
            raw,
            visibleStageLimit: 1,
            in: CGSize(width: 1_000, height: 900)
        )
        let fork = raw.nodes.first { $0.kind == .branchStage }!
        let oldLeaf = layout.node(for: "moment-\(fixture.oldLeaf.id)")!
        let newLeaf = layout.node(for: "moment-\(fixture.newLeaf.id)")!
        let forkNode = layout.node(for: fork.id)!

        #expect(!raw.nodes.contains { $0.kind == .stage })
        #expect(oldLeaf.position.x < forkNode.position.x)
        #expect(newLeaf.position.x > forkNode.position.x)
        #expect(
            ThinkingTreeTopology.activeLeafNode(
                for: 1,
                in: fixture.project.thinkingMoments
            )?.id == fixture.newLeaf.id
        )
    }

    @Test @MainActor func scenarioCCompletedStageCardAnchorsAboveRightActiveLeaf() {
        let fixture = rollbackFixture(stageStatus: "completed")
        let raw = TreeBuilder().build(
            project: fixture.project,
            expandedTransitionOrders: [1],
            visibleStageLimit: 1
        )
        let layout = MindTreeCanonicalLayout.layout(
            raw,
            visibleStageLimit: 1,
            in: CGSize(width: 1_000, height: 900)
        )
        let stage = layout.node(for: TreeBuilder.stageNodeID(1))!
        let activeLeaf = layout.node(for: "moment-\(fixture.newLeaf.id)")!
        let oldLeaf = layout.node(for: "moment-\(fixture.oldLeaf.id)")!

        #expect(stage.stageTreeState == .completedExpanded)
        #expect(abs(stage.position.x - activeLeaf.position.x) < 0.5)
        #expect(stage.position.y < activeLeaf.position.y)
        #expect(stage.position.x != oldLeaf.position.x)
        #expect(raw.edges.contains {
            $0.fromID == activeLeaf.id
                && $0.toID == stage.id
                && $0.style == .active
                && $0.togglesTransitionOrder == 1
        })
    }

    @Test @MainActor func scenarioDCollapseHidesStageSubtreeAndRestoresBindingsWithoutMovingStage() {
        let base = Date()
        let project = stageProject(stageOneStatus: "completed")
        let q1 = question("问题 01", stage: 1, at: base)
        let q2 = question(
            "问题 02",
            stage: 1,
            at: base.addingTimeInterval(1),
            parentID: q1.id
        )
        let card = ResourceLibrary.all[0]
        let method = ThinkingMoment(
            momType: "method",
            content: "调用依据：\(card.title)",
            stageOrder: 1,
            resourceCardID: card.id,
            parentMomentID: q2.id,
            timestamp: base.addingTimeInterval(2)
        )
        project.thinkingMoments = [q1, q2, method]
        let expandedIDs = Set(["moment-\(q2.id)"])

        let expandedRaw = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            visibleStageLimit: 1
        )
        let collapsedRaw = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [],
            visibleStageLimit: 1
        )
        let restoredRaw = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            visibleStageLimit: 1
        )
        let expanded = MindTreeCanonicalLayout.layout(
            expandedRaw,
            visibleStageLimit: 1,
            in: .zero
        )
        let collapsed = MindTreeCanonicalLayout.layout(
            collapsedRaw,
            visibleStageLimit: 1,
            in: .zero
        )

        #expect(collapsedRaw.nodes.filter { $0.kind == .stage }.count == 1)
        #expect(!collapsedRaw.nodes.contains { $0.kind == .question })
        #expect(!collapsedRaw.nodes.contains { $0.kind == .branchStage })
        #expect(!expandedRaw.nodes.contains { $0.momentID == method.id })
        #expect(
            expandedRaw.node(for: "moment-\(q2.id)")?
                .boundResources.map(\.momentID) == [method.id]
        )
        #expect(
            restoredRaw.node(for: "moment-\(q2.id)")?
                .boundResources.map(\.momentID) == [method.id]
        )
        #expect(expandedIDs == ["moment-\(q2.id)"])
        #expect(
            expanded.node(for: TreeBuilder.stageNodeID(1))?.position
                == collapsed.node(for: TreeBuilder.stageNodeID(1))?.position
        )
    }

    @Test @MainActor func scenarioENextStageGrowsAbovePreviousCompletionBoundary() {
        let base = Date()
        let project = stageProject(
            stageOneStatus: "completed",
            stageTwoStatus: "active"
        )
        let stageOneQuestion = question(
            "Stage 1 问题",
            stage: 1,
            at: base
        )
        let stageTwoQuestion = question(
            "Stage 2 问题",
            stage: 2,
            at: base.addingTimeInterval(1)
        )
        project.thinkingMoments = [stageOneQuestion, stageTwoQuestion]

        let raw = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: [1],
            visibleStageLimit: 2
        )
        let layout = MindTreeCanonicalLayout.layout(
            raw,
            visibleStageLimit: 2,
            in: .zero
        )
        let stageOneID = TreeBuilder.stageNodeID(1)
        let stageTwoQuestionID = "moment-\(stageTwoQuestion.id)"

        #expect(raw.nodes.contains { $0.id == stageOneID })
        #expect(!raw.nodes.contains { $0.id == TreeBuilder.stageNodeID(2) })
        #expect(raw.edges.contains {
            $0.fromID == stageOneID && $0.toID == stageTwoQuestionID
        })
        #expect(layout.node(for: stageTwoQuestionID)!.position.y
            < layout.node(for: stageOneID)!.position.y)
    }

    @Test @MainActor func activeLeafUsesExplicitTopologyBeforeTimestamp() {
        let base = Date()
        let q1 = question(
            "父问题",
            stage: 1,
            at: base.addingTimeInterval(3)
        )
        let q2 = question(
            "子问题",
            stage: 1,
            at: base.addingTimeInterval(1),
            parentID: q1.id
        )
        let q3 = question(
            "叶问题",
            stage: 1,
            at: base.addingTimeInterval(2),
            parentID: q2.id
        )

        #expect(
            ThinkingTreeTopology.activeLeafNode(
                for: 1,
                in: [q1, q2, q3]
            )?.id == q3.id
        )
    }

    @Test @MainActor func scenarioFPackageRoundTripPreservesStageLifecycleAndTopology() throws {
        let container = try ExportTestFixtures.makeInMemoryContainer()
        let context = container.mainContext
        let project = stageProject(
            stageOneStatus: "completed",
            stageTwoStatus: "active"
        )
        context.insert(project)
        for stage in project.stages {
            context.insert(stage)
        }
        let q1 = question("Stage 1 问题", stage: 1, at: Date())
        let q2 = question(
            "Stage 2 问题",
            stage: 2,
            at: Date().addingTimeInterval(1)
        )
        let resource = ResourceLibrary.all[0]
        let method = ThinkingMoment(
            momType: "method",
            content: "调用依据：\(resource.title)",
            stageOrder: 2,
            resourceCardID: resource.id,
            parentMomentID: q2.id,
            timestamp: Date().addingTimeInterval(2)
        )
        context.insert(q1)
        context.insert(q2)
        context.insert(method)
        project.thinkingMoments = [q1, q2, method]
        try context.save()

        let package = CoDesignPackageBuilder().build(project: project)
        let imported = try CoDesignPackageImporter().importAsNewProject(
            package: package,
            context: context
        )
        let graph = TreeBuilder().build(
            project: imported,
            expandedTransitionOrders: [1],
            visibleStageLimit: 2
        )

        #expect(imported.stages.first { $0.order == 1 }?.status == "completed")
        #expect(imported.stages.first { $0.order == 2 }?.status == "active")
        #expect(graph.nodes.contains { $0.id == TreeBuilder.stageNodeID(1) })
        #expect(!graph.nodes.contains { $0.id == TreeBuilder.stageNodeID(2) })
        #expect(graph.nodes.filter { $0.kind == .question }.count == 2)
        let importedMethodID = imported.thinkingMoments.first {
            $0.momType == "method"
        }?.id
        #expect(!graph.nodes.contains { $0.momentID == importedMethodID })
        #expect(
            graph.nodes
                .first { $0.kind == .question && $0.stageOrder == 2 }?
                .boundResources.map(\.card.id) == [resource.id]
        )
    }

    @MainActor
    private func stageProject(
        stageOneStatus: String,
        stageTwoStatus: String = "notStarted"
    ) -> Project {
        let project = Project(name: "阶段语义测试", briefDescription: "")
        project.stages = [
            ProgressStage(
                order: 1,
                name: "痛点与场景锚定",
                status: stageOneStatus,
                completionRatio: stageOneStatus == "completed" ? 1 : 0.5
            ),
            ProgressStage(
                order: 2,
                name: "价值主张与差异化",
                status: stageTwoStatus,
                completionRatio: stageTwoStatus == "completed" ? 1 : 0.2
            ),
        ]
        return project
    }

    @MainActor
    private func question(
        _ content: String,
        stage: Int,
        at timestamp: Date,
        parentID: UUID? = nil,
        isActive: Bool = true,
        archivedAt: Date? = nil,
        branchVersion: Int = 1
    ) -> ThinkingMoment {
        ThinkingMoment(
            momType: "question",
            content: content,
            summary: content,
            stageOrder: stage,
            parentMomentID: parentID,
            timestamp: timestamp,
            isActiveBranch: isActive,
            branchVersion: branchVersion,
            archivedAt: archivedAt
        )
    }

    @MainActor
    private func rollbackFixture(
        stageStatus: String
    ) -> (
        project: Project,
        oldLeaf: ThinkingMoment,
        newLeaf: ThinkingMoment
    ) {
        let base = Date()
        let archivedAt = base.addingTimeInterval(10)
        let project = stageProject(stageOneStatus: stageStatus)
        let q1 = question("问题 01", stage: 1, at: base)
        let q2 = question(
            "问题 02",
            stage: 1,
            at: base.addingTimeInterval(1),
            parentID: q1.id
        )
        let q3 = question(
            "问题 03",
            stage: 1,
            at: base.addingTimeInterval(2),
            parentID: q2.id
        )
        let old4 = question(
            "旧问题 04",
            stage: 1,
            at: base.addingTimeInterval(3),
            parentID: q3.id,
            isActive: false,
            archivedAt: archivedAt
        )
        let old5 = question(
            "旧问题 05",
            stage: 1,
            at: base.addingTimeInterval(4),
            parentID: old4.id,
            isActive: false,
            archivedAt: archivedAt
        )
        let old6 = question(
            "旧问题 06",
            stage: 1,
            at: base.addingTimeInterval(5),
            parentID: old5.id,
            isActive: false,
            archivedAt: archivedAt
        )
        let new4 = question(
            "新问题 04",
            stage: 1,
            at: base.addingTimeInterval(11),
            parentID: q3.id,
            branchVersion: 2
        )
        let new5 = question(
            "新问题 05",
            stage: 1,
            at: base.addingTimeInterval(12),
            parentID: new4.id,
            branchVersion: 2
        )
        let new6 = question(
            "新问题 06",
            stage: 1,
            at: base.addingTimeInterval(13),
            parentID: new5.id,
            branchVersion: 2
        )
        project.thinkingMoments = [
            q1, q2, q3,
            old4, old5, old6,
            new4, new5, new6,
        ]
        return (project, old6, new6)
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
        case .process:
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
