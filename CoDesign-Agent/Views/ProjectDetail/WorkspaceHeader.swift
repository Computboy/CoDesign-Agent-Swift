import SwiftUI

// MARK: - WorkspaceHeader

/// The top information bar of the Clarification Workspace.
/// Displays project name, current stage, completion rate, and updated status.
struct WorkspaceHeader: View {
    let project: Project

    private var currentStage: ProgressStage? {
        let sorted = project.stages.sorted { $0.order < $1.order }
        return sorted.first(where: { $0.status == "active" })
            ?? sorted.first(where: { $0.status == "notStarted" })
            ?? sorted.last(where: { $0.status == "completed" })
    }

    private var pillState: CoDesignStagePill.State {
        guard let stage = currentStage else { return .locked }
        switch stage.status {
        case "active":      return .active
        case "completed":   return .complete
        case "needsReview": return .warning
        case "notStarted":  return .locked
        default:            return .locked
        }
    }

    private var maturityText: String {
        let rate = project.completionRate
        if rate >= 1.0 { return "已澄清" }
        if rate >= 0.5 { return "探索中" }
        if rate > 0.0  { return "初期" }
        return "待澄清"
    }

    private var maturityStatus: CoDesignStatusBadge.Status {
        let rate = project.completionRate
        if rate >= 1.0 { return .complete }
        if rate >= 0.5 { return .info }
        if rate > 0.0  { return .partial }
        return .locked
    }

    var body: some View {
        CoDesignCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                // Row 1: Title + maturity badge
                HStack(alignment: .top) {
                    Text(project.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: AppTheme.spacingSmall)

                    CoDesignStatusBadge(
                        status: maturityStatus,
                        text: maturityText
                    )
                }

                // Row 2: Current stage + completion
                HStack {
                    if let stage = currentStage {
                        CoDesignStagePill(
                            order: stage.order,
                            name: stage.name,
                            state: pillState
                        )
                    }

                    Spacer()

                    HStack(spacing: AppTheme.spacingXS) {
                        Text("\(Int(project.completionRate * 100))%")
                            .font(AppTheme.Typography.captionMono)
                            .foregroundStyle(Color.primaryAccent)

                        ProgressView(value: project.completionRate)
                            .progressViewStyle(.linear)
                            .tint(.primaryAccent)
                            .frame(width: 72)
                    }
                }

                // Row 3: Updated time
                HStack {
                    Text("更新于 \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: AppTheme.spacingMedium) {
        WorkspaceHeader(project: {
            let p = Project(name: "校园导航助手", briefDescription: "帮助大一新生找到教室")
            p.stages = [
                ProgressStage(order: 1, name: "痛点与场景锚定", status: "completed", completionRatio: 1.0),
                ProgressStage(order: 2, name: "差异化价值提炼", status: "active", completionRatio: 0.6),
                ProgressStage(order: 3, name: "项目边界定义", status: "notStarted", completionRatio: 0.0),
            ]
            return p
        }())

        WorkspaceHeader(project: Project(name: "新项目", briefDescription: ""))
    }
    .padding()
    .background(Color.appBackground)
}
