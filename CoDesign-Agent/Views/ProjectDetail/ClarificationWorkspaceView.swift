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
        .background(Color.appBackground)
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
        let availableWidth = proxy.size.width
        let treeWidth = clamp(availableWidth * 0.44, min: 360, max: 620)

        return HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
            ThinkingTreeView(project: project, mode: .embedded)
                .frame(width: treeWidth)
                .frame(maxHeight: .infinity)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingMedium) {
                    CurrentWorkspaceColumn(
                        project: project,
                        chatViewModel: chatViewModel,
                        onReviewBrief: onReviewBrief,
                        onRevisitPreviousStage: onRevisitPreviousStage,
                        onExportBrief: onExportBrief
                    )

                    DesignBriefDisclosurePanel(project: project)
                }
                .frame(
                    minHeight: max(proxy.size.height - AppTheme.spacingLarge * 2, 0),
                    alignment: .top
                )
            }
            .coDesignHideScrollIndicators()
        }
        .padding(AppTheme.spacingLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - iPad Landscape Layout (Mac-aligned tree + workspace)

    private func iPadLandscapeLayout(proxy: GeometryProxy) -> some View {
        let width = proxy.size.width
        let treeWidth = clamp(width * 0.42, min: 420, max: 560)

        return HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
            ThinkingTreeView(project: project, mode: .embedded)
                .frame(width: treeWidth)
                .frame(maxHeight: .infinity)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingMedium) {
                    CurrentWorkspaceColumn(
                        project: project,
                        chatViewModel: chatViewModel,
                        onReviewBrief: onReviewBrief,
                        onRevisitPreviousStage: onRevisitPreviousStage,
                        onExportBrief: onExportBrief
                    )

                    DesignBriefDisclosurePanel(project: project)
                }
                .frame(minHeight: max(proxy.size.height - AppTheme.spacingMedium * 2, 0), alignment: .top)
            }
            .coDesignInteractiveKeyboardDismissal()
            .coDesignHideScrollIndicators()
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
                    ThinkingTreeView(project: project, mode: .standalone)
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mindTree: return "思维树"
        case .resources: return "资源线索"
        case .brief: return "Design Brief"
        }
    }

    var icon: String {
        switch self {
        case .mindTree: return "tree"
        case .resources: return "books.vertical"
        case .brief: return "rectangle.stack"
        }
    }

    #if os(iOS)
    var detents: Set<PresentationDetent> {
        switch self {
        case .mindTree:
            return [.large]
        case .resources, .brief:
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
                    showsResourcePanel: showsResourcePanel,
                    onQuickAction: send,
                    onSend: send
                )
            }

            // Learning trace — shown in both completed and uncompleted states
            LearningTraceSection(project: project)

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
