import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ProjectListViewModel {
    var searchText: String = ""

    /// 根据搜索关键词过滤并排序项目
    func filteredProjects(_ projects: [Project]) -> [Project] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return projects.sorted { $0.updatedAt > $1.updatedAt }
        }

        return projects
            .filter {
                $0.name.localizedCaseInsensitiveContains(keyword)
                || $0.briefDescription.localizedCaseInsensitiveContains(keyword)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// 删除指定索引的项目
    func deleteProjects(
        at offsets: IndexSet,
        from projects: [Project],
        context: ModelContext
    ) {
        let sortedProjects = filteredProjects(projects)
        for index in offsets {
            guard index < sortedProjects.count else { continue }
            context.delete(sortedProjects[index])
        }
        try? context.save()
    }
}
