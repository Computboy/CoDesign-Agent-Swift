import SwiftUI

// MARK: - StageRailPanel

/// A wide-screen vertical stage rail for the clarification workspace.
struct StageRailPanel: View {
    let project: Project

    private var sortedStages: [ProgressStage] {
        project.stages.sorted { $0.order < $1.order }
    }

    private var activeStage: ProgressStage? {
        sortedStages.first(where: { $0.status == "active" })
            ?? sortedStages.first(where: { $0.status == "notStarted" })
            ?? sortedStages.last(where: { $0.status == "completed" })
    }

    private var completedCount: Int {
        sortedStages.filter { $0.status == "completed" }.count
    }

    private var currentDefinition: StageDefinition? {
        guard let activeStage else { return nil }
        return StageDefinition.all.first(where: { $0.order == activeStage.order })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            panelHeader

            if sortedStages.isEmpty {
                emptyState
            } else {
                VStack(spacing: AppTheme.spacingSmall) {
                    ForEach(Array(sortedStages.enumerated()), id: \.element.id) { index, stage in
                        StageRailRow(
                            stage: stage,
                            definition: StageDefinition.all.first(where: { $0.order == stage.order }),
                            isActive: stage.id == activeStage?.id,
                            isLast: index == sortedStages.count - 1
                        )
                    }
                }
            }

            progressFooter
                .padding(.top, AppTheme.spacingSmall)
        }
        .padding(AppTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
        .coDesignShadow(.card)
    }

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            Text("阶段面板")
                .font(AppTheme.Typography.captionMono)
                .foregroundStyle(Color.textTertiary)

            Text("9 阶段设计流程")
                .font(AppTheme.Typography.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private var emptyState: some View {
        Text("暂无阶段数据")
            .font(AppTheme.Typography.caption)
            .foregroundStyle(Color.textTertiary)
            .padding(.vertical, AppTheme.spacingLarge)
    }

    private var progressFooter: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack {
                Text("阶段进度")
                    .font(AppTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                Text("\(completedCount) of 9")
                    .font(AppTheme.Typography.captionMono)
                    .foregroundStyle(Color.primaryAccent)
            }

            ProgressView(value: Double(completedCount), total: 9)
                .tint(.primaryAccent)

            if let activeStage, let currentDefinition {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text("当前阶段：\(currentDefinition.shortSubtitle)")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(currentDefinition.compactPurpose)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppTheme.spacingMedium)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .fill(Color.primaryAccent.opacity(activeStage.status == "active" ? 0.045 : 0.03))
                )
            }
        }
    }
}

private struct StageRailRow: View {
    let stage: ProgressStage
    let definition: StageDefinition?
    let isActive: Bool
    let isLast: Bool

    private var tint: Color {
        switch stage.status {
        case "completed": return .success
        case "active": return .primaryAccent
        case "needsReview": return .warning
        default: return .stageNotStarted
        }
    }

    private var statusIcon: String {
        switch stage.status {
        case "completed": return "checkmark.circle.fill"
        case "active": return "circle.fill"
        case "needsReview": return "exclamationmark.triangle.fill"
        default: return "circle"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.primaryAccent.opacity(0.08) : tint.opacity(0.08))
                        .frame(width: 34, height: 34)

                    Image(systemName: definition?.iconName ?? "circle.grid.3x3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isActive ? Color.primaryAccent.opacity(0.9) : tint.opacity(0.8))
                }

                if !isLast {
                    Rectangle()
                        .fill(Color.black.opacity(0.045))
                        .frame(width: 1, height: 16)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppTheme.spacingXS) {
                    Text("Stage \(stage.order)")
                        .font(AppTheme.Typography.captionMono)
                        .foregroundStyle(isActive ? Color.primaryAccent : Color.textTertiary)

                    Image(systemName: statusIcon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Text(stage.name)
                    .font(AppTheme.Typography.caption.weight(isActive ? .semibold : .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(definition?.shortSubtitle ?? "设计澄清")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spacingSmall)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(isActive ? Color.primaryAccent.opacity(0.045) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(isActive ? Color.primaryAccent.opacity(0.18) : Color.clear, lineWidth: AppTheme.Border.thin)
        )
    }
}

#Preview {
    StageRailPanel(project: {
        let project = Project(name: "校园导航助手", briefDescription: "帮助新生找到教室")
        project.stages = StageDefinition.all.map {
            ProgressStage(
                order: $0.order,
                name: $0.name,
                status: $0.order < 3 ? "completed" : ($0.order == 3 ? "active" : "notStarted"),
                completionRatio: $0.order < 3 ? 1 : 0
            )
        }
        return project
    }())
    .padding()
    .background(Color.appBackground)
}
