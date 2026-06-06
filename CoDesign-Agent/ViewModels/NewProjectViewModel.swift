import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class NewProjectViewModel {
    var name: String = ""
    var briefDescription: String = ""
    var errorMessage: String?

    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func createProject(context: ModelContext) -> Project? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = briefDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "请输入项目名称"
            return nil
        }

        // 创建 Project
        let project = Project(
            name: trimmedName,
            briefDescription: trimmedDescription
        )
        context.insert(project)

        // 创建 DesignBrief
        let brief = DesignBrief()
        context.insert(brief)
        project.brief = brief

        // 创建 9 个 ProgressStage
        let stages = StageDefinition.all.map { def in
            ProgressStage(order: def.order, name: def.name)
        }
        for stage in stages {
            context.insert(stage)
        }
        project.stages = stages
        if let firstStage = stages.first {
            firstStage.status = "active"
            firstStage.lastUpdated = Date()
        }

        let openingQuestion = Self.openingQuestion(
            projectName: trimmedName,
            briefDescription: trimmedDescription
        )
        let openingMessage = ChatMessage(role: "assistant", content: openingQuestion)
        context.insert(openingMessage)
        project.messages.append(openingMessage)

        let openingMoment = ThinkingMoment(
            momType: "question",
            content: Self.truncatedMomentText(openingQuestion),
            stageOrder: 1,
            relatedField: nil
        )
        context.insert(openingMoment)
        project.thinkingMoments.append(openingMoment)

        project.updatedAt = Date()

        // 保存
        do {
            try context.save()
            return project
        } catch {
            errorMessage = "创建项目失败，请重试"
            return nil
        }
    }

    private static func openingQuestion(projectName: String, briefDescription: String) -> String {
        let seed = briefDescription
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let idea = (seed?.isEmpty == false ? seed : projectName) ?? projectName

        return """
        我已经收到你的初始想法：「\(idea)」。

        我们先从 Stage 1「痛点与场景锚定」开始，不需要重复描述需求。请你先选一个真实发生的使用场景：是谁，在什么时候、什么地点，遇到了什么具体不方便？
        """
    }

    private static func truncatedMomentText(_ text: String, limit: Int = 60) -> String {
        let flattened = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        guard flattened.count > limit else { return flattened }
        return String(flattened.prefix(limit)) + "..."
    }
}
