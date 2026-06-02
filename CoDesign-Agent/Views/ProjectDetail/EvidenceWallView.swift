import SwiftUI

struct EvidenceWallView: View {
    let project: Project

    private let recommendationService = ResourceRecommendationService()

    private var resources: [ResourceCard] {
        recommendationService.recommend(
            currentStageOrder: project.currentStageOrder,
            brief: project.brief,
            recentMessage: project.latestConversationText
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "Evidence Wall", subtitle: "当前阶段参考资源")

            Text("当前阶段参考资源")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textTertiary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: AppTheme.spacingMedium)], spacing: AppTheme.spacingMedium) {
                ForEach(resources) { resource in
                    ResourceCardView(resource: resource)
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
