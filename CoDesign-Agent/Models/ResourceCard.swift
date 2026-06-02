import Foundation

enum ResourceType: String, CaseIterable, Identifiable {
    case paper
    case method
    case caseStudy
    case designPrinciple
    case courseFramework

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paper: return "论文"
        case .method: return "方法"
        case .caseStudy: return "案例"
        case .designPrinciple: return "设计原则"
        case .courseFramework: return "课程框架"
        }
    }
}

struct ResourceCard: Identifiable, Hashable {
    let id: String
    let title: String
    let type: ResourceType
    let relatedStages: [Int]
    let tags: [String]
    let summary: String
    let whyRelevant: String
    let howToUse: String
    var sourceURL: URL? = nil
    var year: Int? = nil
    var venue: String? = nil
}
