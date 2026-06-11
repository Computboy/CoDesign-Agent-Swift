import SwiftUI

struct ResourceCardPanel: View {
    let project: Project
    var title: String
    var subtitle: String
    var allowsOnlineSearch: Bool

    private let recommendationService = ResourceRecommendationService()
    private let paperSearchService = FrontierPaperSearchService()

    @State private var onlinePapers: [ResourceCard] = []
    @State private var isSearchingPapers = false
    @State private var paperSearchFailed = false
    @State private var isExpanded: Bool

    init(
        project: Project,
        title: String = "本轮设计依据",
        subtitle: String = "Agent 会调用本地知识库辅助本轮追问。",
        allowsOnlineSearch: Bool = false,
        startsExpanded: Bool = false
    ) {
        self.project = project
        self.title = title
        self.subtitle = subtitle
        self.allowsOnlineSearch = allowsOnlineSearch
        _isExpanded = State(initialValue: startsExpanded)
    }

    private var recommendations: [ResourceCard] {
        let local = recommendationService.recommend(
            currentStageOrder: project.currentStageOrder,
            brief: project.brief,
            recentMessage: latestSearchContext
        )
        let combined: [ResourceCard]
        if allowsOnlineSearch {
            combined = onlinePapers + local.filter { localResource in
                !onlinePapers.contains(where: { $0.id == localResource.id })
            }
        } else {
            combined = local
        }
        return Array(combined.prefix(3))
    }

    var body: some View {
        let panelRecommendations = recommendations

        VStack(alignment: .leading, spacing: isExpanded ? AppTheme.spacingSmall : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: AppTheme.spacingSmall) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                        Text(title)
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(statusText(for: panelRecommendations))
                            .font(AppTheme.Typography.micro)
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: AppTheme.spacingSmall)

                    if isSearchingPapers {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.warning)
                    } else {
                        Image(systemName: panelIconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(allowsOnlineSearch && !onlinePapers.isEmpty ? Color.success : Color.warning)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
                .frame(minHeight: headerMinHeight)
            }
            .buttonStyle(.plain)

            if isExpanded {
                if panelRecommendations.isEmpty {
                    Text("当前阶段暂无本地知识库依据。继续对话后，系统会补充更贴近项目的设计依据。")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                        .padding(AppTheme.spacingMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.elevatedCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                } else {
                    VStack(spacing: AppTheme.spacingSmall) {
                        ForEach(panelRecommendations) { resource in
                            ResourceCardView(resource: resource)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, isExpanded ? AppTheme.spacingMedium : AppTheme.spacingSmall)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? AppTheme.cornerRadiusLarge : AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? AppTheme.cornerRadiusLarge : AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(Color.warning.opacity(isExpanded ? AppTheme.Opacity.soft : AppTheme.Opacity.noticeable), lineWidth: AppTheme.Border.thin)
        )
        .coDesignShadow(.card)
        .task(id: "\(project.currentStageOrder)-\(latestSearchContext)") {
            guard allowsOnlineSearch else { return }
            await loadOnlinePapers()
        }
    }

    private var headerMinHeight: CGFloat {
        #if os(iOS)
        return 44
        #else
        return AppTheme.Layout.buttonHeightSmall
        #endif
    }

    private func statusText(for recommendations: [ResourceCard]) -> String {
        if !allowsOnlineSearch {
            if let first = recommendations.first {
                let second = recommendations.dropFirst().first.map { " · \($0.title)" } ?? ""
                return "依据：\(first.title)\(second) · 查看 AI 为什么这样问"
            }
            return subtitle
        }
        if isSearchingPapers {
            return "正在检索与你主题相关的外部论文..."
        }
        if !onlinePapers.isEmpty {
            return "已联网找到 \(onlinePapers.count) 篇相关论文，点击展开"
        }
        if paperSearchFailed {
            return "论文检索暂不可用，点击查看本地知识库依据"
        }
        return subtitle
    }

    private var panelIconName: String {
        if allowsOnlineSearch {
            return onlinePapers.isEmpty ? "network" : "checkmark.circle.fill"
        }
        return "books.vertical"
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
