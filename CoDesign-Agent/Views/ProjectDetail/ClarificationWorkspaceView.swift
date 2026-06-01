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
    var onExportBrief: () -> Void = {}

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// System size-class driven: compact → single-column scroll, regular → three-column workspace.
    /// No hardcoded pixel threshold — adapts to iPad split-screen and window resizing automatically.
    private var useWideLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if useWideLayout {
                wideLayout
            } else {
                narrowLayout
            }
        }
        .background(Color.appBackground)
    }

    // MARK: - Wide Layout (three-column)

    private var wideLayout: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let sideWidth = clamp(availableWidth * 0.23, min: 240, max: 340)

            VStack(spacing: AppTheme.spacingLarge) {
                HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                    StageRailPanel(project: project)
                        .frame(width: sideWidth)
                        .frame(maxHeight: .infinity)

                    ScrollView {
                        CurrentWorkspaceColumn(
                            project: project,
                            chatViewModel: chatViewModel,
                            onExportBrief: onExportBrief
                        )
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ScrollView {
                        InsightCardsPanel(project: project)
                            .padding(.bottom, AppTheme.spacingLarge)
                    }
                    .scrollIndicators(.hidden)
                    .frame(width: sideWidth)
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)

                ProcessLogDisclosure(
                    messages: project.messages,
                    isStreaming: chatViewModel.isStreaming,
                    streamingText: chatViewModel.currentStreamingText
                )
            }
            .padding(AppTheme.spacingLarge)
        }
    }

    private var narrowLayout: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingMedium) {
                WorkspaceHeader(project: project)
                StageRail(stages: project.stages)

                CurrentWorkspaceColumn(
                    project: project,
                    chatViewModel: chatViewModel,
                    includesHeader: false,
                    onExportBrief: onExportBrief
                )

                InsightCardsPanel(project: project)

                ProcessLogDisclosure(
                    messages: project.messages,
                    isStreaming: chatViewModel.isStreaming,
                    streamingText: chatViewModel.currentStreamingText
                )
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - CurrentWorkspaceColumn

private struct CurrentWorkspaceColumn: View {
    let project: Project
    let chatViewModel: ChatViewModel
    var includesHeader: Bool = true
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

    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            if includesHeader {
                WorkspaceHeader(project: project)
            }

            if isProjectComplete {
                DesignCompletionReviewCard(
                    project: project,
                    onSend: send,
                    onExport: onExportBrief
                )
            } else {
                AIContextNotice {
                    print("[AIContextNotice] Undo tapped")
                }

                CurrentClarificationCard(
                    project: project,
                    isStreaming: chatViewModel.isStreaming,
                    streamingText: chatViewModel.currentStreamingText,
                    onQuickAction: send
                )

                AnswerComposer(
                    isStreaming: chatViewModel.isStreaming,
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
        }
    }

    private func send(_ text: String) {
        Task {
            await chatViewModel.sendMessage(text)
        }
    }
}

// MARK: - Preview

/// Clamp a value to [min, max]. Used to keep proportional layout widths within sensible bounds.
private func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, lower), upper)
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
