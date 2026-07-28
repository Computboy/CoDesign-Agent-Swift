import SwiftUI
import SwiftData

struct CoDesignHomeView: View {
    @Binding var searchText: String

    let projects: [Project]
    let isFiltering: Bool
    let onCreateProject: () -> Void
    let onImportPackage: () -> Void
    let onShowSettings: () -> Void
    let onDeleteProject: (Project) -> Void

    var body: some View {
        GeometryReader { geometry in
            let layout = HomeLayout(size: geometry.size)

            VStack(spacing: 0) {
                topBar(layout: layout)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection(layout: layout)

                        recentSection(layout: layout)
                            .padding(.top, layout.recentTopPadding)
                            .padding(.bottom, 44)
                    }
                }
                .coDesignHideScrollIndicators()
                .background(HomePalette.pageBackground)
            }
            .background(HomePalette.pageBackground)
        }
    }

    private var visibleProjects: [Project] {
        if isFiltering {
            return projects
        }

        return Array(projects.prefix(3))
    }

    private var latestProject: Project? {
        projects.first
    }
}

// MARK: - Top Bar

private extension CoDesignHomeView {
    @ViewBuilder
    func topBar(layout: HomeLayout) -> some View {
        if layout.isCompact {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    brandTitle

                    Spacer()

                    HomeIconButton(systemName: "gearshape", title: "设置", action: onShowSettings)
                    HomeIconButton(systemName: "square.and.arrow.down", title: "导入 CoDesign 项目包", action: onImportPackage)

                    createProjectButton
                }

                HomeSearchBar(text: $searchText)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 14)
            .background(HomePalette.surface.opacity(0.94))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(HomePalette.border)
                    .frame(height: 1)
            }
        } else {
            HStack(spacing: 18) {
                brandTitle

                Spacer(minLength: 24)

                HomeIconButton(systemName: "gearshape", title: "设置", action: onShowSettings)
                HomeIconButton(systemName: "square.and.arrow.down", title: "导入 CoDesign 项目包", action: onImportPackage)

                createProjectButton

                HomeSearchBar(text: $searchText)
                    .frame(width: min(320, max(260, layout.width * 0.22)))
            }
            .padding(.horizontal, 28)
            .frame(height: 72)
            .background(HomePalette.surface.opacity(0.94))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(HomePalette.border)
                    .frame(height: 1)
            }
        }
    }

    var brandTitle: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(HomePalette.accent)

            Text("CoDesign")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(HomePalette.primaryText)
        }
        .accessibilityElement(children: .combine)
    }

    var createProjectButton: some View {
        Button(action: onCreateProject) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                Text("新建项目")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(HomePalette.primaryText)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(HomePalette.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(HomePalette.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .help("新建项目")
    }
}

// MARK: - Hero

private extension CoDesignHomeView {
    func heroSection(layout: HomeLayout) -> some View {
        VStack(spacing: layout.heroSectionSpacing) {
            if layout.usesStackedHero {
                VStack(spacing: 28) {
                    heroCopy(layout: layout)
                        .frame(maxWidth: layout.heroCopyMaxWidth, alignment: .leading)

                    HeroTreeIllustration(layout: layout)
                        .frame(maxWidth: layout.heroIllustrationFrameWidth)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: layout.heroColumnSpacing) {
                    heroCopy(layout: layout)
                        .frame(maxWidth: layout.heroCopyMaxWidth, alignment: .leading)

                    Spacer(minLength: 0)

                    HeroTreeIllustration(layout: layout)
                        .frame(width: layout.heroIllustrationFrameWidth)
                }
            }

            featureCards(layout: layout)
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, layout.heroTopPadding)
        .padding(.bottom, layout.heroBottomPadding)
        .frame(minHeight: layout.heroMinHeight)
        .background(HeroBackground())
    }

    func heroCopy(layout: HomeLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.heroCopySpacing) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))

                Text("AI 设计澄清助手")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(HomePalette.accent)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(HomePalette.accent.opacity(0.10))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(HomePalette.accent.opacity(0.16), lineWidth: 1)
            )

            heroTitle(layout: layout)

            Text("CoDesign 是你的 AI 设计澄清伙伴。在项目早期阶段，通过结构化追问、知识依据与工作台沉淀，帮助你把模糊想法转化为清晰、可执行的设计简报。")
                .font(.system(size: layout.heroBodySize, weight: .regular))
                .foregroundStyle(HomePalette.secondaryText)
                .lineSpacing(layout.heroBodyLineSpacing)
                .frame(maxWidth: layout.heroBodyMaxWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            heroActions(layout: layout)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func heroTitle(layout: HomeLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.heroTitleLineSpacing) {
            Text("把模糊想法，")

            if layout.usesThreeLineHeroTitle {
                Text("长成一棵")
                highlightedTitleText("可思考的设计树")
            } else {
                highlightedTitleText("长成一棵可思考的设计树")
            }
        }
        .font(.system(size: layout.heroTitleSize, weight: .heavy, design: .rounded))
        .foregroundStyle(HomePalette.primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.74)
        .allowsTightening(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    func highlightedTitleText(_ string: String) -> Text {
        var attributed = AttributedString(string)
        if let range = attributed.range(of: "可思考") {
            attributed[range].foregroundColor = HomePalette.accent
        }
        return Text(attributed)
    }

    @ViewBuilder
    func heroActions(layout: HomeLayout) -> some View {
        let actionStack = layout.isCompact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 16))

        actionStack {
            Button(action: onCreateProject) {
                HomeActionLabel(
                    title: "开始新的澄清",
                    systemName: "sparkles",
                    style: .primary
                )
            }
            .buttonStyle(.plain)

            if let latestProject {
                NavigationLink {
                    ProjectDetailView(project: latestProject)
                } label: {
                    HomeActionLabel(
                        title: "继续最近项目",
                        systemName: "clock",
                        style: .secondary
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onCreateProject) {
                    HomeActionLabel(
                        title: "创建第一个项目",
                        systemName: "lightbulb",
                        style: .secondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    func featureCards(layout: HomeLayout) -> some View {
        let columns = [
            GridItem(.adaptive(minimum: layout.isCompact ? 250 : 300), spacing: 18)
        ]

        return LazyVGrid(columns: columns, spacing: 18) {
            HomeFeatureCard(
                icon: "point.3.connected.trianglepath.dotted",
                title: "思维树生长",
                subtitle: "从模糊想法到清晰结构",
                tint: HomePalette.purple
            )

            HomeFeatureCard(
                icon: "book.closed.fill",
                title: "本地知识库依据",
                subtitle: "让 AI 追问更有方法论支撑",
                tint: HomePalette.accent
            )

            HomeFeatureCard(
                icon: "square.stack.3d.up.fill",
                title: "工作台沉淀",
                subtitle: "自动汇聚为 Design Brief",
                tint: HomePalette.teal
            )
        }
    }
}

// MARK: - Recent Projects

private extension CoDesignHomeView {
    func recentSection(layout: HomeLayout) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(isFiltering ? "搜索结果" : "最近项目")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(HomePalette.primaryText)

                Spacer()

                if projects.count > 3 && !isFiltering {
                    NavigationLink {
                        ProjectLibraryView(
                            searchText: $searchText,
                            onCreateProject: onCreateProject,
                            onImportPackage: onImportPackage,
                            onShowSettings: onShowSettings,
                            onDeleteProject: onDeleteProject
                        )
                    } label: {
                        HomeSeeAllLabel()
                    }
                    .buttonStyle(HomeSeeAllButtonStyle())
                }
            }

            if projects.isEmpty {
                HomeProjectEmptyState(
                    isFiltering: isFiltering,
                    onCreateProject: onCreateProject
                )
            } else {
                let columns = [
                    GridItem(.adaptive(minimum: layout.isCompact ? 280 : 350), spacing: 18)
                ]

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(visibleProjects) { project in
                        NavigationLink {
                            ProjectDetailView(project: project)
                        } label: {
                            HomeRecentProjectCard(project: project, isCompact: layout.isCompact)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDeleteProject(project)
                            } label: {
                                Label("删除项目", systemImage: "trash")
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.86), value: visibleProjects.map(\.id))
            }
        }
        .padding(.horizontal, layout.horizontalPadding)
    }
}

// MARK: - Hero Tree

private struct HeroTreeIllustration: View {
    let layout: HomeLayout

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: illustrationCornerRadius, style: .continuous)
                .fill(HomePalette.surface.opacity(0.46))
                .overlay(
                    RoundedRectangle(cornerRadius: illustrationCornerRadius, style: .continuous)
                        .stroke(HomePalette.surface.opacity(0.84), lineWidth: 1)
                )
                .shadow(color: HomePalette.accent.opacity(0.10), radius: 32, y: 16)
                .frame(width: imageWidth + 32, height: imageHeight + 32)

            Image("hero_design_tree")
                .resizable()
                .scaledToFit()
                .frame(width: imageWidth, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: illustrationCornerRadius - 2, style: .continuous))
                .shadow(color: HomePalette.accent.opacity(0.18), radius: 24, y: 14)

            if layout.showsFloatingHeroCards {
                FloatingMiniCard(
                    title: "模糊想法",
                    lines: ["做一个帮助", "新生适应校园的应用"],
                    badge: "初始输入",
                    systemName: "lightbulb"
                )
                .scaleEffect(floatingCardScale)
                .offset(x: -imageWidth * floatingCardLeadingOffset, y: -imageHeight * 0.32)

                FloatingMiniCard(
                    title: "AI 追问与澄清",
                    lines: ["目标用户是谁？", "核心场景有哪些？", "成功的关键指标？"],
                    badge: "进行中",
                    systemName: "bubble.left.and.text.bubble.right"
                )
                .scaleEffect(floatingCardScale)
                .offset(x: -imageWidth * floatingCardLeadingOffset, y: imageHeight * 0.20)

                FloatingStageCard()
                    .scaleEffect(floatingCardScale)
                    .offset(x: imageWidth * floatingCardTrailingOffset, y: -imageHeight * 0.25)

                FloatingBriefCard()
                    .scaleEffect(floatingCardScale)
                    .offset(x: imageWidth * floatingCardTrailingOffset, y: imageHeight * 0.28)
            }
        }
        .frame(height: layout.heroIllustrationHeight + 44)
        .frame(maxWidth: .infinity)
    }

    private var imageWidth: CGFloat {
        layout.heroIllustrationWidth
    }

    private var imageHeight: CGFloat {
        layout.heroIllustrationHeight
    }

    private var illustrationCornerRadius: CGFloat {
        layout.isNarrow ? 24 : 30
    }

    private var floatingCardScale: CGFloat {
        layout.floatingCardScale
    }

    private var floatingCardLeadingOffset: CGFloat {
        layout.isWideHero ? 0.52 : 0.36
    }

    private var floatingCardTrailingOffset: CGFloat {
        layout.isWideHero ? 0.49 : 0.36
    }
}

private struct FloatingMiniCard: View {
    let title: String
    let lines: [String]
    let badge: String
    let systemName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HomePalette.accent)

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HomePalette.primaryText)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Circle()
                            .fill(HomePalette.accent.opacity(0.65))
                            .frame(width: 4, height: 4)

                        Text(line)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(HomePalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text(badge)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HomePalette.teal)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(HomePalette.teal.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(16)
        .frame(width: 190, alignment: .leading)
        .background(HomePalette.surface.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(HomePalette.surface.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 20, y: 10)
    }
}

private struct FloatingStageCard: View {
    private let stages = [
        ("校园导航", "location.fill", HomePalette.purple),
        ("信息发现", "tray.fill", HomePalette.accent),
        ("社交互助", "person.2.fill", HomePalette.green),
        ("活动参与", "sparkles", HomePalette.orange)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("分支探索", systemImage: "square.grid.2x2")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HomePalette.primaryText)

                Spacer()

                Text("4")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HomePalette.accent)
                    .frame(width: 24, height: 24)
                    .background(HomePalette.accent.opacity(0.12))
                    .clipShape(Circle())
            }

            VStack(spacing: 8) {
                ForEach(stages, id: \.0) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.1)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(item.2)
                            .frame(width: 24, height: 24)
                            .background(item.2.opacity(0.10))
                            .clipShape(Circle())

                        Text(item.0)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(HomePalette.secondaryText)

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(HomePalette.surface.opacity(0.66))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(width: 190)
        .background(HomePalette.surface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(HomePalette.surface.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 22, y: 10)
    }
}

private struct FloatingBriefCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("结构化沉淀", systemImage: "doc.text")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(HomePalette.primaryText)

            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HomePalette.accent)
                    .frame(width: 46, height: 46)
                    .background(HomePalette.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text("Design Brief")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(HomePalette.primaryText)

                    ProgressView(value: 0.78)
                        .tint(HomePalette.accent)
                }
            }

            HStack {
                ProgressView(value: 0.78)
                    .tint(HomePalette.accent)

                Text("78%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HomePalette.secondaryText)
            }
        }
        .padding(16)
        .frame(width: 188)
        .background(HomePalette.surface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(HomePalette.surface.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 22, y: 10)
    }
}

// MARK: - Cards

private struct HomeFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 58, height: 58)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(HomePalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HomePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(HomePalette.surface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HomePalette.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 20, y: 9)
    }
}

private struct HomeRecentProjectCard: View {
    let project: Project
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: isCompact ? 14 : 18) {
            Image(systemName: iconName)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 60, height: 60)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(project.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(HomePalette.primaryText)
                    .lineLimit(2)

                if let summaryText {
                    Text(summaryText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(HomePalette.secondaryText)
                        .lineLimit(2)
                }

                HStack(alignment: .center, spacing: 10) {
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomePalette.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(HomePalette.accent.opacity(0.10))
                        .clipShape(Capsule())

                    ProgressView(value: project.completionRate)
                        .tint(HomePalette.accent)
                        .frame(width: progressWidth)

                    Text("\(Int(project.completionRate * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomePalette.secondaryText)
                }
                .lineLimit(1)

                Text(stageText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HomePalette.tertiaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Text("继续")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomePalette.accent)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HomePalette.accent)
            }
            .layoutPriority(1)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight)
        .background(HomePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HomePalette.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cardHeight: CGFloat {
        isCompact ? 206 : 188
    }

    private var progressWidth: CGFloat {
        isCompact ? 56 : 70
    }

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

    private var statusText: String {
        let rate = project.completionRate
        if rate >= 1.0 { return "已澄清" }
        if rate >= 0.5 { return "探索中" }
        if rate > 0.0 { return "初期" }
        return "待澄清"
    }

    private var stageText: String {
        if let currentStage {
            return "Stage \(currentStage.order) · \(currentStage.name)"
        }

        return "等待开始澄清"
    }

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

        return "更新于 \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private var tint: Color {
        let palette = [
            HomePalette.accent,
            HomePalette.purple,
            HomePalette.teal,
            HomePalette.green,
            HomePalette.orange
        ]
        let scalarSum = project.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[scalarSum % palette.count]
    }

    private var iconName: String {
        let text = project.name + project.briefDescription
        if text.contains("校园") || text.contains("课程") || text.contains("学生") {
            return "graduationcap.fill"
        }
        if text.contains("宠物") || text.contains("健康") {
            return "leaf.fill"
        }
        if text.contains("预约") || text.contains("协作") {
            return "person.2.fill"
        }
        return "sparkles"
    }
}

private struct HomeProjectEmptyState: View {
    let isFiltering: Bool
    let onCreateProject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: isFiltering ? "magnifyingglass" : "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(HomePalette.accent)
                    .frame(width: 50, height: 50)
                    .background(HomePalette.accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(isFiltering ? "没有找到匹配的项目" : "还没有项目")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(HomePalette.primaryText)

                    Text(isFiltering ? "试试换个关键词，或者开启一个新的澄清。" : "先写下一个模糊想法，让 CoDesign 陪你把它拆清楚。")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(HomePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !isFiltering {
                Button(action: onCreateProject) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("创建第一个项目")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(HomePalette.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HomePalette.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
    }
}

// MARK: - Small Components

private struct HomeSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HomePalette.tertiaryText)

            TextField("搜索项目", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(HomePalette.softFill)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(HomePalette.border, lineWidth: 1)
        )
    }
}

private struct HomeIconButton: View {
    let systemName: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HomePalette.primaryText)
                .frame(width: 44, height: 44)
                .background(HomePalette.surface)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(HomePalette.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct HomeActionLabel: View {
    enum Style: Equatable {
        case primary
        case secondary
    }

    let title: String
    let systemName: String
    let style: Style

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))

            Text(title)
                .font(.system(size: 18, weight: style == .primary ? .bold : .semibold))
        }
        .foregroundStyle(style == .primary ? .white : HomePalette.primaryText)
        .padding(.horizontal, style == .primary ? 28 : 26)
        .frame(height: 58)
        .background(background)
        .clipShape(Capsule())
        .overlay(overlay)
        .shadow(
            color: style == .primary ? HomePalette.accent.opacity(0.28) : .black.opacity(0.05),
            radius: style == .primary ? 18 : 16,
            y: style == .primary ? 10 : 8
        )
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            LinearGradient(
                colors: [HomePalette.accent, HomePalette.accentDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            HomePalette.surface.opacity(0.92)
        }
    }

    @ViewBuilder
    private var overlay: some View {
        if style == .secondary {
            Capsule()
                .stroke(HomePalette.border, lineWidth: 1)
        }
    }
}

private struct HomeSeeAllLabel: View {
    var body: some View {
        HStack(spacing: 7) {
            Text("查看全部")
                .font(.system(size: 15, weight: .semibold))

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(HomePalette.accent)
        .padding(.horizontal, 13)
        .frame(height: 36)
        .background(HomePalette.accent.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(HomePalette.accent.opacity(0.13), lineWidth: 1)
        )
    }
}

private struct HomeSeeAllButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .offset(x: configuration.isPressed ? 2 : 0)
            .shadow(
                color: HomePalette.accent.opacity(configuration.isPressed ? 0.10 : 0.16),
                radius: configuration.isPressed ? 5 : 12,
                y: configuration.isPressed ? 2 : 6
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.76), value: configuration.isPressed)
    }
}

// MARK: - Background

private struct HeroBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    HomePalette.surface,
                    HomePalette.pageBackground,
                    HomePalette.softFill
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            DotGrid()
                .opacity(0.30)
        }
    }
}

private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            let dotSize: CGFloat = 1.2

            for x in stride(from: 0, through: size.width, by: spacing) {
                for y in stride(from: 0, through: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(HomePalette.accent.opacity(0.18))
                    )
                }
            }
        }
    }
}

// MARK: - Layout & Palette

private struct HomeLayout {
    let size: CGSize

    var width: CGFloat {
        size.width
    }

    var height: CGFloat {
        size.height
    }

    var isNarrow: Bool {
        width < 640
    }

    var isCompact: Bool {
        width < 760
    }

    var usesStackedHero: Bool {
        isCompact
    }

    var isWideHero: Bool {
        width >= 1320
    }

    var showsFloatingHeroCards: Bool {
        isWideHero || (!usesStackedHero && height >= 700)
    }

    var floatingCardScale: CGFloat {
        if isWideHero { return 1.0 }
        if width < 900 { return 0.66 }
        if width < 1220 { return 0.76 }
        return 0.88
    }

    var horizontalPadding: CGFloat {
        if isNarrow {
            return 20
        }

        if width < 900 {
            return 44
        }

        return width < 1220 ? 54 : 80
    }

    var heroSectionSpacing: CGFloat {
        isNarrow ? 28 : 34
    }

    var heroCopySpacing: CGFloat {
        isNarrow ? 20 : 24
    }

    var heroColumnSpacing: CGFloat {
        28
    }

    var heroTopPadding: CGFloat {
        if isNarrow { return 34 }
        return usesStackedHero ? 46 : 54
    }

    var heroBottomPadding: CGFloat {
        isNarrow ? 28 : 42
    }

    var heroMinHeight: CGFloat? {
        usesStackedHero ? nil : 660
    }

    var recentTopPadding: CGFloat {
        isCompact ? 24 : 30
    }

    var heroCopyMaxWidth: CGFloat {
        if usesStackedHero {
            return min(width - horizontalPadding * 2, 760)
        }

        if width < 900 {
            return min(360, width * 0.42)
        }

        if width < 1220 {
            return min(470, width * 0.45)
        }

        return min(590, width * 0.44)
    }

    var heroTitleSize: CGFloat {
        if isNarrow { return 38 }
        if width < 900 { return 42 }
        if width < 1220 { return 52 }
        return 56
    }

    var usesThreeLineHeroTitle: Bool {
        isNarrow || (width < 900 && !usesStackedHero)
    }

    var heroTitleLineSpacing: CGFloat {
        isNarrow ? 6 : 8
    }

    var heroBodySize: CGFloat {
        isNarrow ? 16 : 17
    }

    var heroBodyLineSpacing: CGFloat {
        isNarrow ? 5 : 6
    }

    var heroBodyMaxWidth: CGFloat {
        min(heroCopyMaxWidth, 620)
    }

    var heroIllustrationFrameWidth: CGFloat {
        if usesStackedHero {
            return min(width - horizontalPadding * 2, heroIllustrationWidth + 48)
        }

        if width < 900 {
            return 340
        }

        if width < 1220 {
            return 400
        }

        return showsFloatingHeroCards ? 520 : 430
    }

    var heroIllustrationWidth: CGFloat {
        if isNarrow { return 284 }
        if width < 900 { return 300 }
        if width < 1220 { return 350 }
        return 430
    }

    var heroIllustrationHeight: CGFloat {
        if isNarrow { return 356 }
        if width < 900 { return 376 }
        if width < 1220 { return 438 }
        return 536
    }
}

private enum HomePalette {
    static let pageBackground = Color.appBackground
    static let surface = Color.elevatedCardBackground
    static let primaryText = Color.textPrimary
    static let secondaryText = Color.textSecondary
    static let tertiaryText = Color.textTertiary
    static let border = AppTheme.Border.color
    static let softFill = Color.panelBackground

    static let accent = Color(homeHex: "#5B75F0")
    static let accentDeep = Color(homeHex: "#4963DF")
    static let purple = Color(homeHex: "#7C68F2")
    static let teal = Color(homeHex: "#3DB9C5")
    static let green = Color(homeHex: "#55B66D")
    static let orange = Color(homeHex: "#F5A33B")
}

private extension Color {
    init(homeHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (
                255,
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17
            )
        case 6:
            (a, r, g, b) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        case 8:
            (a, r, g, b) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CoDesignHomeView(
            searchText: .constant(""),
            projects: [
                Project(name: "智能校园导航助手", briefDescription: "新生校园适应与导航方案设计"),
                Project(name: "宠物主人行为研究项目", briefDescription: "宠物健康管理与行为洞察"),
                Project(name: "自习室预约系统设计", briefDescription: "高校自习室预约与管理优化")
            ],
            isFiltering: false,
            onCreateProject: {},
            onImportPackage: {},
            onShowSettings: {},
            onDeleteProject: { _ in }
        )
    }
    .modelContainer(for: Project.self, inMemory: true)
}
