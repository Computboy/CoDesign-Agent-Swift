import SwiftUI

struct VisualPortfolioView: View {
    let project: Project

    private var sortedLearningTraces: [LearningTrace] {
        project.learningTraces.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                portfolioIntro
                DesignPortfolioCanvasView(project: project)
                DesignBriefPosterView(project: project)
                DesignJourneyTimelineView(project: project)
                thinkingActionCards
                EvidenceWallView(project: project)
                LearningReflectionSummaryView(project: project)
            }
            .padding(AppTheme.spacingLarge)
            .padding(.bottom, 40)
        }
        .coDesignHideScrollIndicators()
        .background(Color.appBackground)
    }

    private var portfolioIntro: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Label("作品档案", systemImage: "rectangle.stack")
                .font(AppTheme.Typography.title)
                .foregroundStyle(Color.textPrimary)

            Text("这个作品档案记录你在本项目中的设计思考轨迹，可用于课程汇报与后续反思。")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var thinkingActionCards: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "Thinking Action Cards", subtitle: "对话中沉淀的设计思维动作")

            if sortedLearningTraces.isEmpty {
                Text("当你完成澄清、重构问题或收敛边界后，这里会记录你的设计思维动作。")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textTertiary)
                    .padding(AppTheme.spacingLarge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.elevatedCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: AppTheme.spacingMedium)], spacing: AppTheme.spacingMedium) {
                    ForEach(sortedLearningTraces) { trace in
                        ReflectionCard(trace: trace)
                    }
                }
            }
        }
        .padding(AppTheme.spacingLarge)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
    }
}

#Preview {
    VisualPortfolioView(project: Project(name: "校园导航助手", briefDescription: "帮助新生快速找到教室"))
}
