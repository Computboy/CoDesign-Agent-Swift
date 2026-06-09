import SwiftUI

struct StageNodeView: View {
    let stage: ProgressStage

    private var statusColor: Color {
        switch stage.status {
        case "notStarted":
            return Color.stageNotStarted
        case "active":
            return Color.primaryAccent
        case "completed":
            return Color.success
        case "needsReview":
            return Color.warning
        default:
            return Color.stageNotStarted
        }
    }

    private var statusText: String {
        switch stage.status {
        case "notStarted":
            return "未开始"
        case "active":
            return "进行中"
        case "completed":
            return "已完成"
        case "needsReview":
            return "需复查"
        default:
            return "未知"
        }
    }

    private var stageNumber: String {
        String(format: "%02d", stage.order)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            // Header: stage number + name + status
            HStack(spacing: AppTheme.spacingMedium) {
                Text(stageNumber)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(statusColor)

                Text(stage.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text(statusText)
                    .font(AppTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(statusColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.stageNotStarted.opacity(AppTheme.Opacity.medium))
                        .frame(height: 6)

                    Capsule()
                        .fill(statusColor)
                        .frame(width: geometry.size.width * stage.completionRatio, height: 6)
                }
            }
            .frame(height: 6)

            // Completion ratio
            HStack {
                Spacer()
                Text("\(Int(stage.completionRatio * 100))%")
                    .font(AppTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(AppTheme.Layout.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 12) {
        StageNodeView(stage: ProgressStage(
            order: 1,
            name: "痛点与场景锚定",
            status: "completed",
            completionRatio: 1.0
        ))

        StageNodeView(stage: ProgressStage(
            order: 2,
            name: "利益相关者分析",
            status: "active",
            completionRatio: 0.6
        ))

        StageNodeView(stage: ProgressStage(
            order: 3,
            name: "价值主张设计",
            status: "notStarted",
            completionRatio: 0.0
        ))

        StageNodeView(stage: ProgressStage(
            order: 4,
            name: "原型设计",
            status: "needsReview",
            completionRatio: 0.8
        ))
    }
    .padding()
}
