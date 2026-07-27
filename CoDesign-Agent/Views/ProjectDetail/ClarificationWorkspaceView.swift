import SwiftUI

// MARK: - ClarificationWorkspaceView

/// The v0.3 main workspace view that replaces ChatPanel as the primary interface.
/// Organizes the design clarification process into a structured workspace layout.
///
/// ChatViewModel is injected from ProjectDetailView so that Workspace and Chat tab
/// share the same instance and message state stays in sync across tab switches.
struct ClarificationWorkspaceView: View {
    let project: Project
    let chatViewModel: ChatViewModel
    var onReviewBrief: () -> Void = {}
    var onRevisitPreviousStage: () -> Void = {}
    var onExportBrief: () -> Void = {}

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var presentedAccessory: WorkspaceAccessory?

    private enum WorkspaceLayoutMode {
        case desktopWide
        case iPadLandscape
        case iPadStacked
        case narrow
    }

    var body: some View {
        GeometryReader { proxy in
            content(for: layoutMode(in: proxy.size), proxy: proxy)
        }
        .background(Color.clear)
        .sheet(item: $presentedAccessory) { accessory in
            accessorySheet(accessory)
                #if os(iOS)
                .presentationDetents(accessory.detents)
                .presentationDragIndicator(.visible)
                #endif
        }
    }

    private func layoutMode(in size: CGSize) -> WorkspaceLayoutMode {
        #if os(iOS)
        if size.width >= 980 && size.width > size.height {
            return .iPadLandscape
        }

        if size.width >= 640 {
            return .iPadStacked
        }

        return .narrow
        #else
        return horizontalSizeClass == .regular && size.width >= 860 ? .desktopWide : .narrow
        #endif
    }

    @ViewBuilder
    private func content(for mode: WorkspaceLayoutMode, proxy: GeometryProxy) -> some View {
        switch mode {
        case .desktopWide:
            desktopWideLayout(proxy: proxy)
        case .iPadLandscape:
            iPadLandscapeLayout(proxy: proxy)
        case .iPadStacked:
            iPadStackedLayout(proxy: proxy)
        case .narrow:
            narrowLayout(proxy: proxy)
        }
    }

    // MARK: - Desktop Wide Layout (thinking tree + workspace)

    private func desktopWideLayout(proxy: GeometryProxy) -> some View {
        wideDashboardLayout(proxy: proxy, treeFraction: 0.39, treeMinimum: 360, treeMaximum: 560)
    }

    // MARK: - iPad Landscape Layout (Mac-aligned tree + workspace)

    private func iPadLandscapeLayout(proxy: GeometryProxy) -> some View {
        wideDashboardLayout(proxy: proxy, treeFraction: 0.39, treeMinimum: 390, treeMaximum: 520)
    }

    private func wideDashboardLayout(
        proxy: GeometryProxy,
        treeFraction: CGFloat,
        treeMinimum: CGFloat,
        treeMaximum: CGFloat
    ) -> some View {
        let railWidth: CGFloat = 72
        let availableWidth = max(proxy.size.width - railWidth - 36, 1)
        let treeWidth = clamp(
            availableWidth * treeFraction,
            min: treeMinimum,
            max: treeMaximum
        )
        let dashboardActions = WorkspaceDashboardActions(
            showResources: {
                presentedAccessory = .resources
            },
            showBrief: {
                presentedAccessory = .brief
            },
            showLearning: {
                presentedAccessory = .learning
            }
        )

        return HStack(spacing: AppTheme.spacingMedium) {
            WorkspaceSideRail(
                onShowResources: {
                    presentedAccessory = .resources
                },
                onShowBrief: {
                    presentedAccessory = .brief
                },
                onShowProgress: onRevisitPreviousStage,
                onExport: onExportBrief
            )
            .frame(width: railWidth)

            VStack(spacing: AppTheme.spacingMedium) {
                HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                    ThinkingTreeView(project: project, mode: .embedded, chatViewModel: chatViewModel)
                        .frame(width: treeWidth)
                        .frame(maxHeight: .infinity)

                    ScrollView(.vertical, showsIndicators: false) {
                        CurrentWorkspaceColumn(
                            project: project,
                            chatViewModel: chatViewModel,
                            includesHeader: false,
                            showsResourcePanel: false,
                            dashboardActions: dashboardActions,
                            onReviewBrief: onReviewBrief,
                            onRevisitPreviousStage: onRevisitPreviousStage,
                            onExportBrief: onExportBrief
                        )
                        .frame(
                            minHeight: max(proxy.size.height - 124, 0),
                            alignment: .top
                        )
                    }
                    .coDesignInteractiveKeyboardDismissal()
                    .coDesignHideScrollIndicators()
                }
                .frame(maxHeight: .infinity)

                WorkspaceStageTimeline(stages: project.stages)
                    .frame(height: 76)
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - iPad Stacked Layout

    private func iPadStackedLayout(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            StageRail(stages: project.stages)
                .frame(minHeight: 56)
                .padding(.vertical, AppTheme.spacingXS)
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppTheme.Border.color)
                        .frame(height: AppTheme.Border.thin)
                }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingMedium) {
                    WorkspaceAccessoryBar { accessory in
                        presentedAccessory = accessory
                    }

                    CurrentWorkspaceColumn(
                        project: project,
                        chatViewModel: chatViewModel,
                        onReviewBrief: onReviewBrief,
                        onRevisitPreviousStage: onRevisitPreviousStage,
                        onExportBrief: onExportBrief
                    )
                }
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.vertical, AppTheme.spacingSmall)
                .padding(.bottom, AppTheme.spacingXXL)
                .frame(minHeight: max(proxy.size.height - 72, 0), alignment: .top)
            }
            .coDesignInteractiveKeyboardDismissal()
            .coDesignHideScrollIndicators()
        }
    }

    private func narrowLayout(proxy: GeometryProxy) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppTheme.spacingMedium) {
                StageRail(stages: project.stages)

                WorkspaceAccessoryBar { accessory in
                    presentedAccessory = accessory
                }

                CurrentWorkspaceColumn(
                    project: project,
                    chatViewModel: chatViewModel,
                    includesHeader: true,
                    onReviewBrief: onReviewBrief,
                    onRevisitPreviousStage: onRevisitPreviousStage,
                    onExportBrief: onExportBrief
                )

                DesignBriefDisclosurePanel(project: project)
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
            .padding(.bottom, AppTheme.spacingXL)
        }
        .coDesignInteractiveKeyboardDismissal()
        .coDesignHideScrollIndicators()
    }

    @ViewBuilder
    private func accessorySheet(_ accessory: WorkspaceAccessory) -> some View {
        NavigationStack {
            Group {
                switch accessory {
                case .mindTree:
                    ThinkingTreeView(project: project, mode: .standalone, chatViewModel: chatViewModel)
                case .resources:
                    ScrollView(.vertical, showsIndicators: false) {
                        ResourceCardPanel(
                            project: project,
                            title: "资源线索 / 线索 + 提问",
                            subtitle: "保留本轮 AI 提问背后的依据、追问策略和可能追问。",
                            startsExpanded: true
                        )
                        .padding(AppTheme.spacingMedium)
                    }
                    .coDesignHideScrollIndicators()
                    .background(Color.appBackground)
                case .brief:
                    ScrollView(.vertical, showsIndicators: false) {
                        InsightCardsPanel(project: project)
                            .padding(AppTheme.spacingMedium)
                    }
                    .coDesignHideScrollIndicators()
                    .background(Color.appBackground)
                case .learning:
                    ScrollView(.vertical, showsIndicators: false) {
                        LearningTraceSection(project: project)
                            .padding(AppTheme.spacingMedium)
                    }
                    .coDesignHideScrollIndicators()
                    .background(Color.appBackground)
                }
            }
            .navigationTitle(accessory.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - Workspace Accessory

private enum WorkspaceAccessory: String, Identifiable {
    case mindTree
    case resources
    case brief
    case learning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mindTree: return "思维树"
        case .resources: return "资源线索"
        case .brief: return "Design Brief"
        case .learning: return "学习轨迹"
        }
    }

    var icon: String {
        switch self {
        case .mindTree: return "tree"
        case .resources: return "books.vertical"
        case .brief: return "rectangle.stack"
        case .learning: return "clock.arrow.2.circlepath"
        }
    }

    #if os(iOS)
    var detents: Set<PresentationDetent> {
        switch self {
        case .mindTree:
            return [.large]
        case .resources, .brief, .learning:
            return [.medium, .large]
        }
    }
    #endif
}

private struct WorkspaceAccessoryBar: View {
    let onSelect: (WorkspaceAccessory) -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            ForEach([WorkspaceAccessory.mindTree, .resources, .brief]) { accessory in
                Button {
                    onSelect(accessory)
                } label: {
                    Label(accessory.title, systemImage: accessory.icon)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.primaryAccent)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                                .fill(Color.primaryAccent.opacity(AppTheme.Opacity.light))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Wide Workspace Navigation

private struct WorkspaceDashboardActions {
    let showResources: () -> Void
    let showBrief: () -> Void
    let showLearning: () -> Void
}

private struct WorkspaceSideRail: View {
    let onShowResources: () -> Void
    let onShowBrief: () -> Void
    let onShowProgress: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            sideRailItem(
                title: "澄清",
                icon: "sparkles",
                isSelected: true,
                action: {}
            )

            sideRailItem(
                title: "资源",
                icon: "books.vertical",
                action: onShowResources
            )

            sideRailItem(
                title: "简报",
                icon: "rectangle.stack",
                action: onShowBrief
            )

            sideRailItem(
                title: "阶段",
                icon: "point.bottomleft.forward.to.point.topright.scurvepath",
                action: onShowProgress
            )

            Spacer(minLength: 12)

            sideRailItem(
                title: "导出",
                icon: "square.and.arrow.up",
                action: onExport
            )
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 10)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.08), lineWidth: 1)
        )
        .coDesignShadow(.card)
    }

    private func sideRailItem(
        title: String,
        icon: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))

                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.34, green: 0.28, blue: 0.96),
                                        Color(red: 0.47, green: 0.38, blue: 0.96),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
        .accessibilityIdentifier("workspace.sideRail.\(title)")
    }
}

// MARK: - Wide Workspace Summary

private struct WorkspaceSummaryCards: View {
    let project: Project
    let actions: WorkspaceDashboardActions

    private var currentDefinition: StageDefinition {
        StageDefinition.all.first(where: { $0.order == project.currentStageOrder })
            ?? StageDefinition.all[0]
    }

    private var recommendedResources: [ResourceCard] {
        ResourceRecommendationService().recommend(
            currentStageOrder: project.currentStageOrder,
            brief: project.brief,
            recentMessage: project.latestConversationText,
            limit: 3
        )
    }

    private var currentFields: [BriefField] {
        let fields = currentDefinition.briefFields
        return fields.isEmpty ? [.targetUser, .painPoint, .useScenario] : fields
    }

    private var snapshot: DesignBriefSnapshot {
        project.brief?.toSnapshot() ?? DesignBriefSnapshot()
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            summaryCard(
                title: "本轮设计依据",
                icon: "books.vertical.fill",
                tint: Color.primaryAccent,
                actionTitle: "查看详情",
                action: actions.showResources
            ) {
                if let first = recommendedResources.first {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(first.title)
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.primaryAccent)
                            .lineLimit(1)

                        Text(first.whyRelevant)
                            .font(AppTheme.Typography.tiny)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }
                } else {
                    Text("当前阶段暂无资源建议")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            summaryCard(
                title: "可能更新的字段",
                icon: "list.bullet.rectangle",
                tint: Color.warning,
                actionTitle: "查看全部字段",
                action: actions.showBrief
            ) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(currentFields.prefix(3)), id: \.rawValue) { field in
                        HStack(spacing: 6) {
                            Image(systemName: field.isFilled(in: snapshot) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(field.isFilled(in: snapshot) ? Color.success : Color.warning)

                            Text(field.displayName)
                                .font(AppTheme.Typography.tiny.weight(.medium))
                                .foregroundStyle(Color.textPrimary)

                            Spacer(minLength: 4)

                            Text(field.isFilled(in: snapshot) ? "已提取" : "待输入")
                                .font(AppTheme.Typography.micro)
                                .foregroundStyle(field.isFilled(in: snapshot) ? Color.success : Color.warning)
                        }
                    }
                }
            }

            summaryCard(
                title: "学习轨迹",
                icon: "clock.arrow.2.circlepath",
                tint: Color.primaryAccent,
                actionTitle: "查看学习记录",
                action: actions.showLearning
            ) {
                VStack(alignment: .leading, spacing: 5) {
                    metricRow("已完成追问", value: "\(completedQuestionCount)")
                    metricRow("学习记录", value: "\(project.learningTraces.count)")
                    metricRow("已确认字段", value: "\(filledCurrentFieldCount)")
                }
            }
        }
    }

    private var completedQuestionCount: Int {
        project.messages.filter { $0.role == "user" }.count
    }

    private var filledCurrentFieldCount: Int {
        currentFields.filter { $0.isFilled(in: snapshot) }.count
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.tiny)
                .foregroundStyle(Color.textSecondary)
            Spacer(minLength: 4)
            Text(value)
                .font(AppTheme.Typography.tiny.weight(.bold))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func summaryCard<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        actionTitle: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(AppTheme.Typography.caption.weight(.bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer(minLength: 0)
            }

            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: action) {
                HStack(spacing: 5) {
                    Text(actionTitle)
                    Image(systemName: "arrow.right")
                }
                .font(AppTheme.Typography.tiny.weight(.semibold))
                .foregroundStyle(Color.primaryAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.09), lineWidth: 1)
        )
        .coDesignShadow(.card)
    }
}

// MARK: - Wide Workspace Stage Timeline

private struct WorkspaceStageTimeline: View {
    let stages: [ProgressStage]
    @State private var selectedStage: ProgressStage?
    @State private var selectedDefinition: StageDefinition?

    private var sortedStages: [ProgressStage] {
        stages.sorted { $0.order < $1.order }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(sortedStages.enumerated()), id: \.element.id) { index, stage in
                stageButton(stage)

                if index < sortedStages.count - 1 {
                    Rectangle()
                        .fill(connectorColor(after: stage))
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)
                        .padding(.horizontal, 3)
                        .padding(.bottom, 20)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.08), lineWidth: 1)
        )
        .coDesignShadow(.card)
        .overlay {
            if let selectedStage, let selectedDefinition {
                StageExplanationPopover(
                    stage: selectedStage,
                    definition: selectedDefinition,
                    onDismiss: dismissExplanation
                )
            }
        }
    }

    private func stageButton(_ stage: ProgressStage) -> some View {
        let definition = StageDefinition.all.first(where: { $0.order == stage.order })
        let tint = stageTint(stage)
        let isCurrent = stage.status == "active" || stage.status == "needsReview"

        return Button {
            guard let definition else { return }
            withAnimation(AppTheme.Animation.spring) {
                selectedStage = stage
                selectedDefinition = definition
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? tint : tint.opacity(0.12))
                        .frame(width: 27, height: 27)

                    if stage.status == "completed" {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isCurrent ? Color.white : tint)
                    } else {
                        Text("\(stage.order)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(isCurrent ? Color.white : tint)
                    }
                }

                Text(definition?.shortSubtitle ?? stage.name)
                    .font(.system(size: 8, weight: isCurrent ? .bold : .medium))
                    .foregroundStyle(isCurrent ? Color.primaryAccent : Color.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("阶段 \(stage.order)，\(stage.name)")
    }

    private func stageTint(_ stage: ProgressStage) -> Color {
        switch stage.status {
        case "completed": return .success
        case "active": return .primaryAccent
        case "needsReview": return .warning
        default: return .textTertiary
        }
    }

    private func connectorColor(after stage: ProgressStage) -> Color {
        stage.status == "completed"
            ? Color.primaryAccent.opacity(0.42)
            : Color.textTertiary.opacity(0.18)
    }

    private func dismissExplanation() {
        withAnimation(AppTheme.Animation.spring) {
            selectedStage = nil
            selectedDefinition = nil
        }
    }
}

// MARK: - DesignBriefDisclosurePanel

private struct DesignBriefDisclosurePanel: View {
    let project: Project
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            InsightCardsPanel(
                project: project,
                showsPanelChrome: false,
                showsSectionHeader: false
            )
            .padding(.top, AppTheme.spacingMedium)
        } label: {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryAccent)

                VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                    Text("设计产物 / Design Brief")
                        .font(AppTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(summaryText)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()
            }
        }
        .tint(Color.primaryAccent)
        .padding(AppTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
        .coDesignShadow(.card)
    }

    private var summaryText: String {
        guard let brief = project.brief else { return "暂无结构化字段" }
        let snapshot = brief.toSnapshot()
        let fields: [BriefField] = [
            .targetUser,
            .painPoint,
            .useScenario,
            .coreValue,
            .mvpFeatures,
            .successMetrics,
        ]
        let filled = fields.filter { $0.isFilled(in: snapshot) }.count
        return "\(filled)/\(fields.count) 已提取，展开查看和编辑"
    }
}

// MARK: - CurrentWorkspaceColumn

private struct CurrentWorkspaceColumn: View {
    let project: Project
    let chatViewModel: ChatViewModel
    var includesHeader: Bool = true
    var showsResourcePanel: Bool = true
    var dashboardActions: WorkspaceDashboardActions?
    var onReviewBrief: () -> Void = {}
    var onRevisitPreviousStage: () -> Void = {}
    var onExportBrief: () -> Void = {}

    // MARK: - Completion Detection

    /// True when the project has reached 100 % completion OR the latest assistant
    /// message contains an unambiguous wrap-up phrase.
    private var isProjectComplete: Bool {
        if project.completionRate >= 1.0 { return true }

        let sorted = project.stages.sorted { $0.order < $1.order }
        if !sorted.isEmpty && sorted.allSatisfy({ $0.status == "completed" }) {
            return true
        }

        // Text-based heuristic — only very specific wrap-up phrases
        // (no bare "完成" to avoid false positives)
        let latestAssistant = project.messages
            .sorted { $0.timestamp < $1.timestamp }
            .last(where: { $0.role == "assistant" })
        if let content = latestAssistant?.content {
            let phrases = ["所有阶段", "所有 9 个阶段", "祝你项目顺利"]
            if phrases.contains(where: { content.contains($0) }) {
                return true
            }
        }

        return false
    }

    private var needsReviewStage: ProgressStage? {
        project.stages
            .sorted { $0.order < $1.order }
            .first { $0.status == "needsReview" }
    }

    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            if includesHeader {
                WorkspaceHeader(project: project)
            }

            if let needsReviewStage {
                reviewContinuationNotice(stage: needsReviewStage)
            }

            if isProjectComplete {
                DesignCompletionReviewCard(
                    project: project,
                    onSend: send,
                    onExport: onExportBrief,
                    onReviewBrief: onReviewBrief,
                    onRevisitPreviousStage: onRevisitPreviousStage
                )
            } else {
                CurrentClarificationCard(
                    project: project,
                    isStreaming: chatViewModel.isStreaming,
                    streamingText: chatViewModel.currentStreamingText,
                    activityText: chatViewModel.assistantActivityText,
                    showsResourcePanel: showsResourcePanel,
                    onQuickAction: send,
                    onSend: send
                )
            }

            if let dashboardActions {
                WorkspaceSummaryCards(
                    project: project,
                    actions: dashboardActions
                )
            } else {
                // The stacked and narrow layouts retain the full learning trace.
                LearningTraceSection(project: project)
            }

            if let errorMessage = chatViewModel.errorMessage {
                CoDesignCard(style: .highlighted(.danger)) {
                    HStack(spacing: AppTheme.spacingSmall) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.danger)
                        Text(errorMessage)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color.danger)
                    }
                }
            }

            ProcessLogDisclosure(
                messages: project.messages,
                methodMoments: project.thinkingMoments,
                isStreaming: chatViewModel.isStreaming,
                streamingText: chatViewModel.currentStreamingText
            )
        }
    }

    private func send(_ text: String) {
        Task {
            await chatViewModel.sendMessage(text)
        }
    }

    private func reviewContinuationNotice(stage: ProgressStage) -> some View {
        CoDesignCard(style: .normal) {
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text("已回溯到 Stage \(stage.order)，请从该阶段继续澄清。")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(stage.name)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Preview

/// Clamp a value to [min, max]. Used to keep proportional layout widths within sensible bounds.
private func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, lower), upper)
}

private extension View {
    @ViewBuilder
    func coDesignInteractiveKeyboardDismissal() -> some View {
        #if os(iOS)
        self.scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}

#Preview {
    NavigationStack {
        ClarificationWorkspaceView(
            project: {
                let p = Project(
                    name: "校园导航助手",
                    briefDescription: "帮助大一新生快速找到教室"
                )
                p.stages = [
                    ProgressStage(order: 1, name: "痛点与场景锚定", status: "active", completionRatio: 0.3),
                    ProgressStage(order: 2, name: "差异化价值提炼", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 3, name: "项目边界定义", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 4, name: "功能与技术拆解", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 5, name: "运行逻辑与规则", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 6, name: "硬性约束设计", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 7, name: "量化验收标准", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 8, name: "风险识别与预案", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 9, name: "项目阶段排期", status: "notStarted", completionRatio: 0.0),
                ]
                return p
            }(),
            chatViewModel: ChatViewModel(
                project: Project(name: "Preview", briefDescription: ""),
                llmService: MockLLMService(),
                extractor: MockStructuredExtractor()
            )
        )
    }
}
