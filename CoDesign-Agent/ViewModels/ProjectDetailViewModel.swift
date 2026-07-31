import Foundation
import Observation

// MARK: - Tab 定义

enum ProjectDetailTab: String, CaseIterable, Identifiable {
    case workspace
    case mindTree
    case visualBoard

    var id: String { rawValue }

    /// Stable visual order used to determine the direction of workspace transitions.
    var navigationOrder: Int {
        switch self {
        case .workspace: return 0
        case .mindTree: return 1
        case .visualBoard: return 2
        }
    }

    var title: String {
        switch self {
        case .workspace: return "工作台"
        case .mindTree: return "思维树"
        case .visualBoard: return "成果"
        }
    }

    var systemImage: String {
        switch self {
        case .workspace: return "square.grid.2x2"
        case .mindTree: return "tree"
        case .visualBoard: return "chart.xyaxis.line"
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class ProjectDetailViewModel {
    var selectedTab: ProjectDetailTab = .workspace
}
