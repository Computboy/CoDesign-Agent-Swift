import Foundation

enum ReportFlowLayout: Equatable {
    case horizontal
    case timeline
}

enum ReportBehaviorLayout: Equatable {
    case pending
    case compactList
    case matrix
}

enum ReportRiskLayout: Equatable {
    case compact
    case detailed
}

/// 只根据已经形成的文档语义选择布局，不读取项目业务模型。
struct ReportLayoutPolicy {
    func flowLayout(for flow: ReportFlow) -> ReportFlowLayout {
        let totalCharacters = flow.steps.reduce(0) { $0 + $1.text.count }
        return flow.steps.count <= 4 && totalCharacters <= 160 ? .horizontal : .timeline
    }

    func behaviorLayout(for groups: [ReportFieldGroup]) -> ReportBehaviorLayout {
        let count = groups.reduce(0) { $0 + $1.items.count }
        if count == 0 { return .pending }
        return groups.count == 3 && count >= 6 ? .matrix : .compactList
    }

    func riskLayout(for row: ReportRiskRow) -> ReportRiskLayout {
        row.availableDetails.count >= 3 ? .detailed : .compact
    }
}
