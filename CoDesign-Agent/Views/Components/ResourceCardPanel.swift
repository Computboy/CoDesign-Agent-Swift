import SwiftUI

struct ResourceCardPanel: View {
    let project: Project
    var title: String = "AI 助教推荐"
    var subtitle: String = "根据当前阶段，为你补充可参考的方法、理论与案例。"

    private let recommendationService = ResourceRecommendationService()
    private let paperSearchService = FrontierPaperSearchService()

    @State private var onlinePapers: [ResourceCard] = []
    @State private var isSearchingPapers = false
    @State private var paperSearchFailed = false

    private var recommendations: [ResourceCard] {
        let local = recommendationService.recommend(
            currentStageOrder: project.currentStageOrder,
            brief: project.brief,
            recentMessage: project.latestConversationText
        )
        let combined = onlinePapers + local.filter { localResource in
            !onlinePapers.contains(where: { $0.id == localResource.id })
        }
        return Array(combined.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                CoDesignSectionHeader(title: title, subtitle: subtitle)

                Spacer(minLength: AppTheme.spacingSmall)

                if isSearchingPapers {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.orange)
                } else {
                    Image(systemName: onlinePapers.isEmpty ? "network" : "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(onlinePapers.isEmpty ? Color.orange : Color.success)
                }
            }

            if !onlinePapers.isEmpty {
                Label("已联网检索前沿论文", systemImage: "globe.asia.australia")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.orange)
            } else if paperSearchFailed {
                Label("论文检索暂不可用，先显示本地课程资源", systemImage: "wifi.slash")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
            }

            if recommendations.isEmpty {
                Text("当前阶段暂无推荐资源。继续对话后，系统会补充更贴近项目的参考内容。")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(AppTheme.spacingMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.elevatedCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: AppTheme.spacingSmall) {
                    ForEach(recommendations) { resource in
                        ResourceCardView(resource: resource)
                    }
                }
            }
        }
        .padding(AppTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.orange.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.62), lineWidth: AppTheme.Border.medium)
        )
        .coDesignShadow(.card)
        .task(id: "\(project.currentStageOrder)-\(project.latestConversationText ?? "")") {
            await loadOnlinePapers()
        }
    }

    private func loadOnlinePapers() async {
        isSearchingPapers = true
        paperSearchFailed = false
        do {
            onlinePapers = try await paperSearchService.searchPapers(
                stageOrder: project.currentStageOrder,
                brief: project.brief,
                recentMessage: project.latestConversationText
            )
            paperSearchFailed = onlinePapers.isEmpty
        } catch {
            onlinePapers = []
            paperSearchFailed = true
        }
        isSearchingPapers = false
    }
}

#Preview {
    ResourceCardPanel(project: Project(name: "校园导航助手", briefDescription: "帮助新生找到教室"))
        .padding()
        .background(Color.appBackground)
}
