import SwiftUI
import SwiftData

// MARK: - ProjectCard (v0.3)

/// A design-project dashboard card used in ProjectListView.
/// Shows project title, summary, current stage pill, maturity badge, and completion.
///
/// Layout:
/// ```
/// [项目标题]                       [成熟度 Badge]
/// 摘要 / 最近更新
/// [StagePill: 03 项目边界]          完成度 42%
/// ```
struct ProjectCard: View {
    let project: Project
    var fixedHeight: CGFloat? = nil

    // MARK: - Computed helpers

    /// The "current" stage to display: active → first notStarted → last completed → nil
    private var currentStage: ProgressStage? {
        let sorted = project.stages.sorted { $0.order < $1.order }
        if let active = sorted.first(where: { $0.status == "active" }) {
            return active
        }
        if let next = sorted.first(where: { $0.status == "notStarted" }) {
            return next
        }
        return sorted.last(where: { $0.status == "completed" })
    }

    /// Map ProgressStage status string → CoDesignStagePill.State
    private func pillState(for stage: ProgressStage) -> CoDesignStagePill.State {
        switch stage.status {
        case "active":      return .active
        case "completed":   return .complete
        case "needsReview": return .warning
        case "notStarted":  return .locked
        default:            return .locked
        }
    }

    /// Maturity badge status derived from completionRate
    private var maturityStatus: CoDesignStatusBadge.Status {
        let rate = project.completionRate
        if rate >= 1.0 { return .complete }
        if rate >= 0.5 { return .info }
        if rate > 0.0  { return .partial }
        return .locked
    }

    /// Maturity label text
    private var maturityText: String {
        let rate = project.completionRate
        if rate >= 1.0 { return "已澄清" }
        if rate >= 0.5 { return "探索中" }
        if rate > 0.0  { return "初期" }
        return "待澄清"
    }

    /// A one-line summary pulled from DesignBrief when available
    private var summaryText: String? {
        if let brief = project.brief {
            if let painPoint = brief.painPoint, !painPoint.isEmpty {
                return painPoint
            }
            if let targetUser = brief.targetUser, !targetUser.isEmpty {
                return "目标用户：\(targetUser)"
            }
        }
        if !project.briefDescription.isEmpty {
            return project.briefDescription
        }
        return nil
    }

    // MARK: - Body

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

                // Row 2: Summary or updated time
                if let summary = summaryText {
                    Text(summary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                } else {
                    Text("更新于 \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }

                if fixedHeight != nil {
                    Spacer(minLength: 0)
                }

                // Divider
                Rectangle()
                    .fill(Color.textTertiary.opacity(AppTheme.Opacity.medium))
                    .frame(height: 1)
                    .padding(.vertical, AppTheme.spacingXS)

                // Row 3: Stage pill + completion
                HStack {
                    if let stage = currentStage {
                        CoDesignStagePill(
                            order: stage.order,
                            name: stage.name,
                            state: pillState(for: stage)
                        )
                    } else {
                        // No stages yet — show a default "ready to start" pill
                        CoDesignStagePill(
                            order: 1,
                            name: "痛点与场景锚定",
                            state: .locked
                        )
                    }

                    Spacer()

                    // Completion percentage
                    HStack(spacing: AppTheme.spacingXS) {
                        Text("\(Int(project.completionRate * 100))%")
                            .font(AppTheme.Typography.captionMono)
                            .foregroundStyle(Color.primaryAccent)

                        ProgressView(value: project.completionRate)
                            .progressViewStyle(.linear)
                            .tint(.primaryAccent)
                            .frame(width: 56)
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: fixedContentHeight,
                maxHeight: fixedContentHeight,
                alignment: .topLeading
            )
        }
        .frame(
            maxWidth: .infinity,
            minHeight: fixedHeight,
            maxHeight: fixedHeight,
            alignment: .topLeading
        )
    }

    private var fixedContentHeight: CGFloat? {
        guard let fixedHeight else { return nil }
        return max(0, fixedHeight - AppTheme.Layout.cardPadding * 2)
    }
}

// MARK: - Preview

#Preview("ProjectCard") {
    ScrollView {
        VStack(spacing: AppTheme.spacingMedium) {
            // Brand new project (no stages, no brief)
            ProjectCard(project: {
                let p = Project(name: "校园导航助手", briefDescription: "帮助大一新生快速找到教室")
                return p
            }())

            // Project with active stage
            ProjectCard(project: {
                let p = Project(name: "智能课程表", briefDescription: "自动识别冲突并推荐最优排课方案")
                let brief = DesignBrief()
                brief.targetUser = "大学教务管理员"
                brief.painPoint = "手动排课容易冲突，效率低下"
                p.brief = brief
                p.stages = [
                    ProgressStage(order: 1, name: "痛点与场景锚定", status: "completed", completionRatio: 1.0),
                    ProgressStage(order: 2, name: "差异化价值提炼", status: "active", completionRatio: 0.6),
                    ProgressStage(order: 3, name: "项目边界定义", status: "notStarted", completionRatio: 0.0),
                ]
                return p
            }())

            // Near-complete project
            ProjectCard(project: {
                let p = Project(name: "设计评审 Agent", briefDescription: "AI 辅助设计稿评审与反馈")
                let brief = DesignBrief()
                brief.targetUser = "UI 设计师"
                brief.painPoint = "设计评审流程冗长，反馈不及时"
                p.brief = brief
                p.stages = (1...9).map { i in
                    ProgressStage(
                        order: i,
                        name: "阶段 \(i)",
                        status: i < 8 ? "completed" : (i == 8 ? "active" : "notStarted"),
                        completionRatio: i < 8 ? 1.0 : (i == 8 ? 0.4 : 0.0)
                    )
                }
                return p
            }())
        }
        .padding()
    }
    .background(Color.appBackground)
}
