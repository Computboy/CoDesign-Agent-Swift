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
    @State private var isExpanded = false

    private var recommendations: [ResourceCard] {
        let local = recommendationService.recommend(
            currentStageOrder: project.currentStageOrder,
            brief: project.brief,
            recentMessage: latestSearchContext
        )
        let combined = onlinePapers + local.filter { localResource in
            !onlinePapers.contains(where: { $0.id == localResource.id })
        }
        return Array(combined.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            Button {
                withAnimation(AppTheme.Animation.spring) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: AppTheme.spacingSmall) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(Color.textPrimary)
                        Text(statusText)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color.textTertiary)
                    }

                    Spacer(minLength: AppTheme.spacingSmall)

                    if isSearchingPapers {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.orange)
                    } else {
                        Image(systemName: onlinePapers.isEmpty ? "network" : "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(onlinePapers.isEmpty ? Color.orange : Color.success)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if recommendations.isEmpty {
                    Text("当前阶段暂无推荐资源。继续对话后，系统会补充更贴近项目的参考内容。")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                        .padding(AppTheme.spacingMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    VStack(spacing: AppTheme.spacingSmall) {
                        ForEach(recommendations) { resource in
                            ResourceCardView(resource: resource)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(AppTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.52), lineWidth: AppTheme.Border.medium)
        )
        .coDesignShadow(.card)
        .task(id: "\(project.currentStageOrder)-\(latestSearchContext)") {
            await loadOnlinePapers()
        }
    }

    private var statusText: String {
        if isSearchingPapers {
            return "正在联网检索与你主题相关的论文..."
        }
        if !onlinePapers.isEmpty {
            return "已联网找到 \(onlinePapers.count) 篇相关论文，点击展开"
        }
        if paperSearchFailed {
            return "论文检索暂不可用，点击查看本地课程资源"
        }
        return subtitle
    }

    private func loadOnlinePapers() async {
        isSearchingPapers = true
        paperSearchFailed = false
        do {
            onlinePapers = try await paperSearchService.searchPapers(
                stageOrder: project.currentStageOrder,
                brief: project.brief,
                recentMessage: latestSearchContext
            )
            paperSearchFailed = onlinePapers.isEmpty
        } catch {
            onlinePapers = []
            paperSearchFailed = true
        }
        isSearchingPapers = false
    }

    private var latestSearchContext: String {
        [project.name, project.briefDescription, project.latestConversationText]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

#Preview {
    ResourceCardPanel(project: Project(name: "校园导航助手", briefDescription: "帮助新生找到教室"))
        .padding()
        .background(Color.appBackground)
}
