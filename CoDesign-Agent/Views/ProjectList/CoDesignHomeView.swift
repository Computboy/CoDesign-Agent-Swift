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
                    .zIndex(100)

                heroSection(layout: layout)

                recentSection(layout: layout)
                    .padding(.top, layout.recentSectionTopSpacing)
                    .padding(.bottom, layout.recentBottomPadding)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .zIndex(10)
            }
            .background(HomePalette.pageBackground)
        }
    }

    private var visibleProjects: [Project] {
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
            .padding(.vertical, 10)
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
            .padding(.horizontal, 24)
            .frame(height: layout.topBarHeight)
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
            Image(decorative: "HomeBrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)

            Text("CoDesign")
                .font(.system(size: 22, weight: .bold, design: .rounded))
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
            .frame(height: 40)
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
        Group {
            if layout.usesCompactHero {
                heroCopy(layout: layout)
                    .frame(maxWidth: layout.heroCopyMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: layout.heroColumnSpacing) {
                    heroCopy(layout: layout)
                        .frame(maxWidth: layout.heroCopyMaxWidth, alignment: .leading)

                    Spacer(minLength: 0)

                    HeroTreeIllustration(layout: layout)
                        .frame(width: layout.heroIllustrationFrameWidth)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, layout.heroTopPadding)
        .padding(.bottom, layout.heroBottomPadding)
        .offset(y: layout.contentVerticalOffset)
        .frame(height: layout.heroHeight, alignment: .center)
        .background(alignment: .top) {
            HeroBackground()
                .frame(height: layout.heroBackgroundHeight)
                .allowsHitTesting(false)
        }
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
                .padding(.top, 4)
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

}

// MARK: - Recent Projects

private extension CoDesignHomeView {
    func recentSection(layout: HomeLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.recentContentSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(isFiltering ? "搜索结果" : "最近项目")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(HomePalette.primaryText)

                Spacer()

                if projects.count > 3 {
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
                LazyVGrid(columns: layout.recentProjectColumns, spacing: 16) {
                    ForEach(visibleProjects) { project in
                        NavigationLink {
                            ProjectDetailView(project: project)
                        } label: {
                            HomeRecentProjectCard(
                                project: project,
                                isCompact: layout.usesCondensedProjectCards
                            )
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
            Image("hero_design_tree")
                .resizable()
                .scaledToFit()
                .frame(width: imageWidth, height: imageHeight)

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
        .accessibilityHidden(true)
    }

    private var imageWidth: CGFloat {
        layout.heroIllustrationWidth
    }

    private var imageHeight: CGFloat {
        layout.heroIllustrationHeight
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

private struct HomeRecentProjectCard: View {
    let project: Project
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: isCompact ? 12 : 18) {
            Image(systemName: iconName)
                .font(.system(size: isCompact ? 23 : 27, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: isCompact ? 52 : 60, height: isCompact ? 52 : 60)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
                Text(project.name)
                    .font(.system(size: isCompact ? 16 : 17, weight: .bold))
                    .foregroundStyle(HomePalette.primaryText)
                    .lineLimit(2)

                if let summaryText, !isCompact {
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

                if !isCompact {
                    Text(stageText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HomePalette.tertiaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            if isCompact {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HomePalette.accent)
            } else {
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
        }
        .padding(isCompact ? 16 : 20)
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
        isCompact ? 132 : 178
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
        .padding(.horizontal, style == .primary ? 26 : 24)
        .frame(height: 52)
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
        GeometryReader { geometry in
            ZStack {
                HomePalette.pageBackground

                Image("HomeBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .bottom
                    )
            }
            .clipped()
        }
        .accessibilityHidden(true)
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

    var usesCondensedProjectCards: Bool {
        width < 1320
    }

    var usesCompactHero: Bool {
        width < 900
    }

    var isWideHero: Bool {
        width >= 1320
    }

    var showsFloatingHeroCards: Bool {
        isWideHero || (!usesCompactHero && height >= 700)
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

    var topBarHeight: CGFloat {
        isCompact ? 122 : 64
    }

    var heroCopySpacing: CGFloat {
        isNarrow ? 14 : 18
    }

    var heroColumnSpacing: CGFloat {
        28
    }

    var heroTopPadding: CGFloat {
        isNarrow ? 18 : 22
    }

    var heroBottomPadding: CGFloat {
        isNarrow ? 14 : 18
    }

    var heroHeight: CGFloat {
        let available = height - topBarHeight - recentSectionReserve
        if usesCompactHero {
            return max(350, min(450, available))
        }
        return max(360, min(520, available))
    }

    private var recentSectionReserve: CGFloat {
        (usesCondensedProjectCards ? 202 : 248)
            + recentAdditionalTopSpacing
    }

    private var unusedVerticalSpace: CGFloat {
        max(0, height - topBarHeight - heroHeight - recentSectionReserve)
    }

    var contentVerticalOffset: CGFloat {
        min(48, unusedVerticalSpace * 0.55)
    }

    var heroBackgroundHeight: CGFloat {
        heroHeight + recentSectionTopSpacing + recentHeaderControlHeight
    }

    var recentTopPadding: CGFloat {
        isCompact ? 12 : 16
    }

    var recentAdditionalTopSpacing: CGFloat {
        isCompact ? 12 : 20
    }

    var recentSectionTopSpacing: CGFloat {
        recentTopPadding + contentVerticalOffset + recentAdditionalTopSpacing
    }

    private var recentHeaderControlHeight: CGFloat {
        36
    }

    var recentBottomPadding: CGFloat {
        isCompact ? 10 : 14
    }

    var recentContentSpacing: CGFloat {
        isCompact ? 12 : 14
    }

    var recentProjectColumns: [GridItem] {
        let columnCount: Int
        if width >= 900 {
            columnCount = 3
        } else if width >= 620 {
            columnCount = 2
        } else {
            columnCount = 1
        }
        return Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 16),
            count: columnCount
        )
    }

    var heroCopyMaxWidth: CGFloat {
        if usesCompactHero {
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
        isNarrow || (width < 900 && !usesCompactHero)
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
        if width < 900 {
            return 0
        }

        if width < 1050 {
            return 320
        }

        if width < 1220 {
            return 380
        }

        return showsFloatingHeroCards ? 520 : 430
    }

    var heroIllustrationWidth: CGFloat {
        heroIllustrationHeight * 0.8
    }

    var heroIllustrationHeight: CGFloat {
        let preferredHeight: CGFloat
        if isNarrow {
            preferredHeight = 356
        } else if width < 900 {
            preferredHeight = 376
        } else if width < 1220 {
            preferredHeight = 438
        } else {
            preferredHeight = 536
        }

        return min(preferredHeight, max(270, heroHeight + 32))
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
