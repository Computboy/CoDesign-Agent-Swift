import SwiftUI

struct DesignJourneyTimelineView: View {
    let project: Project

    private var stages: [ProgressStage] {
        project.stages.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "Design Journey Timeline", subtitle: "9 个阶段的澄清进度")

            VStack(spacing: AppTheme.spacingSmall) {
                ForEach(StageDefinition.all, id: \.order) { definition in
                    let stage = stages.first(where: { $0.order == definition.order })
                    timelineRow(definition: definition, stage: stage)
                }
            }
        }
        .padding(AppTheme.spacingLarge)
        .background(sectionBackground)
    }

    private func timelineRow(definition: StageDefinition, stage: ProgressStage?) -> some View {
        let status = stage?.stageStatusValue ?? .notStarted
        let isCurrent = definition.order == project.currentStageOrder
        let trace = project.learningTraces
            .sorted { $0.timestamp > $1.timestamp }
            .first { $0.stageOrder == definition.order }

        return HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
            ZStack {
                Circle()
                    .fill(Color.stageColor(for: status).opacity(isCurrent ? 1.0 : 0.18))
                    .frame(width: 32, height: 32)
                Text("\(definition.order)")
                    .font(AppTheme.Typography.caption.weight(.bold))
                    .foregroundStyle(isCurrent ? Color.white : Color.stageColor(for: status))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppTheme.spacingSmall) {
                    Text(definition.name)
                        .font(AppTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(statusDisplayName(status))
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.stageColor(for: status))
                }

                Text(trace?.detail ?? definition.compactPurpose)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isCurrent ? Color.primaryAccent.opacity(0.08) : Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isCurrent ? Color.primaryAccent.opacity(0.32) : AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
            .fill(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
            )
    }

    private func statusDisplayName(_ status: StageStatus) -> String {
        switch status {
        case .notStarted: return "未开始"
        case .active: return "进行中"
        case .completed: return "已完成"
        case .needsReview: return "需复查"
        }
    }
}
