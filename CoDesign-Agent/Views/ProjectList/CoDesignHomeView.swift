import SwiftUI
import SwiftData

struct CoDesignHomeView: View {
    @Binding var searchText: String

    let projects: [Project]
    let isFiltering: Bool
    let onCreateProject: () -> Void
    let onShowSettings: () -> Void
    let onDeleteProject: (Project) -> Void

    var body: some View {
        GeometryReader { geometry in
            let layout = HomeLayout(width: geometry.size.width)

            VStack(spacing: 0) {
                topBar(layout: layout)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection(layout: layout)

                        recentSection(layout: layout)
                            .padding(.top, layout.isCompact ? 24 : 30)
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

                    createProjectButton
                }

                HomeSearchBar(text: $searchText)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 14)
            .background(.white.opacity(0.94))
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

                createProjectButton

                HomeSearchBar(text: $searchText)
                    .frame(width: min(320, max(260, layout.width * 0.22)))
            }
            .padding(.horizontal, 28)
            .frame(height: 72)
            .background(.white.opacity(0.94))
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
            .background(.white)
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
        VStack(spacing: layout.isCompact ? 28 : 34) {
            if layout.isCompact {
                VStack(spacing: 28) {
                    heroCopy(layout: layout)
                    HeroTreeIllustration(isCompact: true)
                }
            } else {
                HStack(alignment: .center, spacing: 36) {
                    heroCopy(layout: layout)
                        .frame(maxWidth: 620, alignment: .leading)

                    Spacer(minLength: 18)

                    HeroTreeIllustration(isCompact: false)
                        .frame(maxWidth: 720)
                }
            }

            featureCards(layout: layout)
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, layout.isCompact ? 34 : 54)
        .padding(.bottom, layout.isCompact ? 28 : 42)
        .frame(minHeight: layout.isCompact ? nil : 660)
        .background(HeroBackground())
    }

    func heroCopy(layout: HomeLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.isCompact ? 20 : 24) {
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

            VStack(alignment: .leading, spacing: 6) {
                Text("把模糊想法，")

                if layout.isCompact {
                    Text("长成一棵")
                    HStack(spacing: 0) {
                        Text("可思考")
                            .foregroundStyle(HomePalette.accent)
                        Text("的设计树")
                    }
                } else {
                    HStack(spacing: 0) {
                        Text("长成一棵")
                        Text("可思考")
                            .foregroundStyle(HomePalette.accent)
                        Text("的设计树")
                    }
                }
            }
            .font(.system(size: layout.heroTitleSize, weight: .heavy, design: .rounded))
            .foregroundStyle(HomePalette.primaryText)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)

            Text("CoDesign 是你的 AI 设计澄清伙伴。在项目早期阶段，通过结构化追问、知识依据与工作台沉淀，帮助你把模糊想法转化为清晰、可执行的设计简报。")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(HomePalette.secondaryText)
                .lineSpacing(6)
                .frame(maxWidth: 590, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            heroActions(layout: layout)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    let isCompact: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isCompact ? 24 : 30, style: .continuous)
                .fill(.white.opacity(0.46))
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 24 : 30, style: .continuous)
                        .stroke(.white.opacity(0.84), lineWidth: 1)
                )
                .shadow(color: HomePalette.accent.opacity(0.10), radius: 32, y: 16)
                .frame(width: imageWidth + 36, height: imageHeight + 34)

            Image("hero_design_tree")
                .resizable()
                .scaledToFit()
                .frame(width: imageWidth, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: isCompact ? 22 : 28, style: .continuous))
                .shadow(color: HomePalette.accent.opacity(0.18), radius: 24, y: 14)

            if !isCompact {
                FloatingMiniCard(
                    title: "模糊想法",
                    lines: ["做一个帮助", "新生适应校园的应用"],
                    badge: "初始输入",
                    systemName: "lightbulb"
                )
                .offset(x: -250, y: -172)

                FloatingMiniCard(
                    title: "AI 追问与澄清",
                    lines: ["目标用户是谁？", "核心场景有哪些？", "成功的关键指标？"],
                    badge: "进行中",
                    systemName: "bubble.left.and.text.bubble.right"
                )
                .offset(x: -290, y: 92)

                FloatingStageCard()
                    .offset(x: 260, y: -136)

                FloatingBriefCard()
                    .offset(x: 248, y: 146)
            }
        }
        .frame(height: isCompact ? 430 : 560)
        .frame(maxWidth: .infinity)
    }

    private var imageWidth: CGFloat {
        isCompact ? 284 : 430
    }

    private var imageHeight: CGFloat {
        isCompact ? 356 : 536
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
        .background(.white.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 1)
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
                    .background(.white.opacity(0.66))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(width: 190)
        .background(.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 1)
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
        .background(.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 1)
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
        .background(.white.opacity(0.92))
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
        .background(.white)
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
        .background(.white)
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
                .background(.white)
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
            Color.white.opacity(0.92)
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
                    .white,
                    Color(homeHex: "#F7FAFF"),
                    Color(homeHex: "#F3F6FF")
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
    let width: CGFloat

    var isCompact: Bool {
        width < 760
    }

    var horizontalPadding: CGFloat {
        if isCompact {
            return 20
        }

        return width < 1100 ? 44 : 80
    }

    var heroTitleSize: CGFloat {
        isCompact ? 38 : 56
    }
}

private enum HomePalette {
    static let pageBackground = Color(homeHex: "#F7F9FD")
    static let primaryText = Color(homeHex: "#202638")
    static let secondaryText = Color(homeHex: "#667085")
    static let tertiaryText = Color(homeHex: "#98A2B3")
    static let border = Color(homeHex: "#E6EAF2")
    static let softFill = Color(homeHex: "#F7F8FB")

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
            onShowSettings: {},
            onDeleteProject: { _ in }
        )
    }
    .modelContainer(for: Project.self, inMemory: true)
}
