import SwiftUI

// MARK: - DesignCompletionReviewCard

/// Shown in the centre column when all 9 stages are completed (or the assistant
/// has sent a completion / congratulations message).  Provides a lightweight
/// summary of the key Design Brief fields and offers export / review actions.
///
/// This is a pure UI-layer view — no new Model / DB fields.
struct DesignCompletionReviewCard: View {
    let project: Project
    let onSend: (String) -> Void
    let onExport: () -> Void
    var onReviewBrief: () -> Void = {}
    var onRevisitPreviousStage: () -> Void = {}

    // MARK: - Key fields

    private var keyFields: [(label: String, value: String)] {
        var fields: [(String, String)] = []
        if let v = project.brief?.targetUser, !v.isEmpty {
            fields.append((BriefField.targetUser.displayName, v))
        }
        if let v = project.brief?.painPoint, !v.isEmpty {
            fields.append((BriefField.painPoint.displayName, v))
        }
        if let v = project.brief?.mvpFeatures, !v.isEmpty {
            fields.append((BriefField.mvpFeatures.displayName, v))
        }
        let metricsCount = project.brief?.successMetrics.count ?? 0
        if metricsCount > 0 {
            fields.append((BriefField.successMetrics.displayName, "已定义 \(metricsCount) 项指标"))
        }
        return fields
    }

    // MARK: - Body

    var body: some View {
        CoDesignCard(style: .normal) {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {

                // Header
                headerSection

                // Key fields summary
                if !keyFields.isEmpty {
                    summarySection
                } else {
                    Text("暂无已提取的字段，请在 Insights 面板中查看你的设计简报。")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                // Updated time
                HStack(spacing: AppTheme.spacingXS) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                    Text("更新于 \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Divider()

                // Action buttons
                actionButtons
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.success.opacity(0.9))
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Color.success.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Text("设计简报已完成")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(Color.textPrimary)

                Text("9 阶段设计澄清已完成。你可以查看简报、导出、或继续优化。")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppTheme.spacingSmall)

            CoDesignStatusBadge(status: .complete, text: "100%")
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(spacing: AppTheme.spacingXS) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textTertiary)

                Text("Brief Snapshot")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(keyFields.enumerated()), id: \.offset) { index, field in
                    HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                        Circle()
                            .fill(Color.primaryAccent.opacity(0.35))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                            Text(field.value)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppTheme.spacingSmall)

                    if index < keyFields.count - 1 {
                        Divider()
                            .overlay(AppTheme.Border.color)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .fill(Color.panelBackground.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
            )
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            // Primary row
            HStack(spacing: AppTheme.spacingSmall) {
                Button {
                    onExport()
                } label: {
                    Label("导出简报", systemImage: "square.and.arrow.up")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: AppTheme.Layout.buttonHeightSmall)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primaryAccent)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onReviewBrief()
                } label: {
                    Label("查看简报", systemImage: "doc.text.magnifyingglass")
                        .secondaryCompletionButtonStyle(tint: .primaryAccent)
                }
                .buttonStyle(.plain)
            }

            // Secondary row
            HStack(spacing: AppTheme.spacingSmall) {
                Button {
                    onRevisitPreviousStage()
                } label: {
                    Label("回到上一阶段", systemImage: "arrow.counterclockwise")
                        .secondaryCompletionButtonStyle(tint: .textSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    onSend("继续优化")
                } label: {
                    Label("继续优化", systemImage: "bubble.left.and.bubble.right")
                        .secondaryCompletionButtonStyle(tint: .textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    func secondaryCompletionButtonStyle(tint: Color) -> some View {
        self
            .font(AppTheme.Typography.caption.weight(.medium))
            .foregroundStyle(tint.opacity(0.86))
            .padding(.horizontal, 12)
            .frame(height: AppTheme.Layout.buttonHeightSmall)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
            )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: AppTheme.spacingMedium) {
            DesignCompletionReviewCard(
                project: {
                    let p = Project(name: "校园导航助手", briefDescription: "帮助新生找到教室")
                    let brief = DesignBrief()
                    brief.targetUser = "大一新生，尤其是来自外地的学生"
                    brief.painPoint = "校园面积大、建筑命名混乱，新生经常找不到教室"
                    brief.mvpFeatures = "AR 导航、语音提示、离线地图缓存"
                    p.brief = brief
                    p.stages = StageDefinition.all.map {
                        ProgressStage(order: $0.order, name: $0.name, status: "completed", completionRatio: 1.0)
                    }
                    return p
                }(),
                onSend: { print("Send: \($0)") },
                onExport: { print("Export") }
            )

            // Empty brief variant
            DesignCompletionReviewCard(
                project: Project(name: "新项目", briefDescription: ""),
                onSend: { _ in },
                onExport: { }
            )
        }
        .padding()
    }
    .background(Color.appBackground)
}
