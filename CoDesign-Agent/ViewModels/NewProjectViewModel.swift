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
}
