#if DEBUG
import Foundation
import SwiftData

@MainActor
struct PresentationDemoDataFactory {
    static func resetProject(context: ModelContext) -> Project {
        let descriptor = FetchDescriptor<Project>()
        let projects = (try? context.fetch(descriptor)) ?? []
        for project in projects where project.name == PresentationMode.projectName {
            context.delete(project)
        }

        let project = Project(
            name: PresentationMode.projectName,
            briefDescription: "面向大学生的传统文化短视频 AI 共创工具：用苏格拉底式追问把模糊课程选题澄清为可展示、可验证的 Design Brief。",
            createdAt: Date().addingTimeInterval(-3_600),
            updatedAt: Date()
        )
        context.insert(project)

        let brief = DesignBrief()
        context.insert(brief)
        project.brief = brief

        let stages = StageDefinition.all.map { definition in
            ProgressStage(
                order: definition.order,
                name: definition.name,
                status: definition.order == 1 ? "active" : "notStarted",
                completionRatio: 0,
                lastUpdated: definition.order == 1 ? Date() : nil
            )
        }
        stages.forEach(context.insert)
        project.stages = stages

        let openingQuestion = """
        我已经收到你的初始想法：「传统文化短视频 AI 共创工具」。

        我们先从 Stage 1「痛点与场景锚定」开始。请直接补充一个真实发生的使用场景：是谁，在什么时候，为什么会觉得传统文化内容难以被记住或传播？
        """
        let openingMessage = ChatMessage(
            role: "assistant",
            content: openingQuestion,
            timestamp: Date().addingTimeInterval(-180)
        )
        context.insert(openingMessage)
        project.messages.append(openingMessage)

        let rootMoment = ThinkingMoment(
            momType: "seed",
            content: "提出非遗 AI 短视频共创方向",
            stageOrder: 0,
            timestamp: Date().addingTimeInterval(-240)
        )
        context.insert(rootMoment)
        project.thinkingMoments.append(rootMoment)

        let openingMoment = ThinkingMoment(
            momType: "question",
            content: openingQuestion.replacingOccurrences(of: "\n", with: " "),
            stageOrder: 1,
            parentMomentID: rootMoment.id,
            timestamp: Date().addingTimeInterval(-170)
        )
        context.insert(openingMoment)
        project.thinkingMoments.append(openingMoment)

        let starterTrace = LearningTrace(
            stageOrder: 1,
            actionType: "seed",
            title: "进入问题框定",
            detail: "展示模式从一个真实课程选题开始，通过对话逐步沉淀 Design Brief。"
        )
        context.insert(starterTrace)
        project.learningTraces.append(starterTrace)

        try? context.save()
        return project
    }
}
#endif
