import Foundation
import Observation

// MARK: - Tab 定义

enum ProjectDetailTab: String, CaseIterable, Identifiable {
    case workspace
    case chat
    case progress
    case insights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workspace: return "工作台"
        case .chat: return "对话"
        case .progress: return "进度"
        case .insights: return "洞察"
        }
    }

    var systemImage: String {
        switch self {
        case .workspace: return "square.grid.2x2"
        case .chat: return "bubble.left.and.bubble.right"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .insights: return "sparkles"
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class ProjectDetailViewModel {
    var selectedTab: ProjectDetailTab = .workspace

    func sortedStages(for project: Project) -> [ProgressStage] {
        project.stages.sorted { $0.order < $1.order }
    }

    func sortedMessages(for project: Project) -> [ChatMessage] {
        project.messages.sorted { $0.timestamp < $1.timestamp }
    }

    func sortedLearningTraces(for project: Project) -> [LearningTrace] {
        project.learningTraces.sorted { $0.timestamp < $1.timestamp }
    }

    func completionPercent(for project: Project) -> Int {
        Int(project.completionRate * 100)
    }
}
