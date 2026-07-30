import SwiftUI

// MARK: - CurrentClarificationCard

/// The core visual component of v0.3 workspace.
/// Displays the current AI question, stage context, related fields, and explanation.
struct CurrentClarificationCard: View {
    private static let assistantResponseBaseFontSize: CGFloat = 18

    let project: Project
    let isStreaming: Bool
    let streamingText: String
    var streamingSnapshot: StreamingMarkdownSnapshot?
    var activityText: String = "正在分析回答……"
    var showsResourcePanel: Bool = true
    let onQuickAction: (String) -> Void
    let onSend: (String) -> Void
    @State private var showsExampleAction = false
    @State private var isContextExpanded = false

    // MARK: - State

    private enum CardState {
        case welcome      // No messages yet
        case streaming    // AI is generating
        case hasResponse  // Latest assistant message available
        case interrupted  // Partial output was preserved after failure/cancellation
        case waitingUser  // Latest message is from user (waiting for next AI turn)
    }

    private var cardState: CardState {
        if isStreaming { return .streaming }
        if let streamingSnapshot,
           streamingSnapshot.hasVisibleContent,
           streamingSnapshot.phase == .failed || streamingSnapshot.phase == .cancelled {
            return .interrupted
        }
        let sorted = project.messages.sorted { $0.timestamp < $1.timestamp }
        if sorted.isEmpty { return .welcome }
        if sorted.last?.role == "assistant" { return .hasResponse }
        return .waitingUser
    }

    private var latestAssistantText: String {
        if isStreaming || cardState == .interrupted {
            return streamingSnapshot?.markdown ?? streamingText
        }
        let sorted = project.messages.sorted { $0.timestamp < $1.timestamp }
        return sorted.last(where: { $0.role == "assistant" })?.content ?? ""
    }

    private var latestAssistantMessage: ChatMessage? {
        project.messages
            .filter { $0.role == "assistant" }
            .sorted { $0.timestamp < $1.timestamp }
            .last
    }

    private var usesMethodScaffold: Bool {
        if let assistant = latestAssistantMessage {
            let recentMethodMoment = project.thinkingMoments
                .filter { $0.momType == "method" && abs($0.timestamp.timeIntervalSince(assistant.timestamp)) < 12 }
                .sorted { $0.timestamp < $1.timestamp }
                .last
            if recentMethodMoment != nil {
                return true
            }

            let recentMethodTrace = project.learningTraces
                .filter { $0.actionType == "methodCard" && abs($0.timestamp.timeIntervalSince(assistant.timestamp)) < 12 }
                .sorted { $0.timestamp < $1.timestamp }
                .last
            if recentMethodTrace != nil {
                return true
            }
        }

        return (latestAssistantText.contains("线索：") && latestAssistantText.contains("追问：")) ||
            latestAssistantText.contains("本轮 Agent 使用") ||
            latestAssistantText.contains("本地设计依据")
    }

    /// Whether quick actions should be disabled (streaming or no conversation yet)
    private var quickActionsDisabled: Bool {
        isStreaming || cardState == .welcome
    }

    private var currentStage: ProgressStage? {
        let sorted = project.stages.sorted { $0.order < $1.order }
        return sorted.first(where: { $0.status == "needsReview" })
            ?? sorted.first(where: { $0.status == "active" })
            ?? sorted.first(where: { $0.status == "notStarted" })
    }

    private var stageOrder: Int {
        currentStage?.order ?? 1
    }

    private var currentDefinition: StageDefinition? {
        StageDefinition.all.first(where: { $0.order == stageOrder })
    }

    private var relatedFields: [BriefField] {
        currentDefinition?.briefFields ?? []
    }

    private var whyAsk: String {
        currentDefinition?.compactPurpose ?? ""
    }

    private var quickActions: [ClarificationQuickAction] {
        var actions: [ClarificationQuickAction] = []

        if showsExampleAction {
            actions.append(ClarificationQuickAction(
                title: "给我一个例子",
                icon: "lightbulb",
                tint: .primaryAccent,
                prompt: "给我一个例子：我需要一点参考。请基于当前阶段给 2-3 个很短的例子作为启发，但不要替我直接决定最终答案。"
            ))
        }

        actions.append(contentsOf: [
            ClarificationQuickAction(
                title: "我还不确定",
                icon: "questionmark.circle",
                tint: .warning,
                prompt: "我还不确定。请先给我一条能帮助理解当前问题的设计线索，再只问一个开放问题。不要给选项，不要替我回答。"
            ),
            ClarificationQuickAction(
                title: "换个角度问",
                icon: "arrow.triangle.2.circlepath",
                tint: .info,
                prompt: "换个角度问：请换一个角度重新追问我这个问题，不要重复刚才的表达，也不要给 A/B/C 选项。"
            ),
            ClarificationQuickAction(
                title: "跳过",
                icon: "forward",
                tint: .textSecondary,
                prompt: "这个问题先跳过，请基于已有信息继续推进到下一个最合理的澄清点。"
            ),
        ])

        return actions
    }

    // MARK: - Body

    var body: some View {
        CoDesignCard(
            style: .imageBackground([
                CoDesignCardBackgroundLayer(
                    name: "background_orange",
                    opacity: 0.18,
                    alignment: .topTrailing,
                    scale: 0.72
                ),
                CoDesignCardBackgroundLayer(
                    name: "background_purple",
                    opacity: 0.18,
                    alignment: .bottomLeading,
                    scale: 0.72
                ),
            ])
        ) {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                stageHeader

                if showsResourcePanel {
                    ResourceCardPanel(
                        project: project,
                        title: "本轮设计依据",
                        subtitle: "查看 AI 为什么这样问。"
                    )
                }

                if usesMethodScaffold {
                    Label("本轮使用本地设计依据辅助追问", systemImage: "sparkles")
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(Color.primaryAccent)
                        .padding(.horizontal, AppTheme.spacingSmall)
                        .frame(height: AppTheme.Layout.badgeHeight)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primaryAccent.opacity(AppTheme.Opacity.light))
                        )
                }

                switch cardState {
                case .welcome:
                    welcomeContent
                case .streaming:
                    streamingContent
                case .hasResponse:
                    responseContent
                case .interrupted:
                    interruptedContent
                case .waitingUser:
                    waitingContent
                }

                contextSection
                AnswerComposer(
                    isStreaming: isStreaming,
                    onSend: onSend
                )
                quickActionsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: delayedExampleRevealKey) {
            showsExampleAction = false
            guard cardState == .hasResponse else { return }
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            showsExampleAction = true
        }
    }

    private var delayedExampleRevealKey: String {
        let latestAssistantID = latestAssistantMessage?.id.uuidString ?? "none"
        return "\(isStreaming)-\(project.messages.count)-\(latestAssistantID)"
    }

    // MARK: - Stage Header

    private var stageHeader: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Text("当前澄清")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(Color.textPrimary)

                if let stage = currentStage {
                    Text("Stage \(stage.order) · \(stage.name)")
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(Color.primaryAccent)
                        .padding(.horizontal, AppTheme.spacingSmall)
                        .frame(height: AppTheme.Layout.badgeHeight)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primaryAccent.opacity(AppTheme.Opacity.light))
                        )
                } else {
                    Text("设计澄清")
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            CoDesignStatusBadge(
                status: stateBadgeStatus,
                text: stateBadgeText,
                tint: stateBadgeTint
            )
        }
    }

    private var stateBadgeStatus: CoDesignStatusBadge.Status {
        switch cardState {
        case .welcome:     return .info
        case .streaming:   return .active
        case .hasResponse: return .complete
        case .interrupted: return .partial
        case .waitingUser: return .partial
        }
    }

    private var stateBadgeText: String {
        switch cardState {
        case .welcome:     return "准备开始"
        case .streaming:   return "AI 思考中"
        case .hasResponse: return "已生成"
        case .interrupted: return "已保留草稿"
        case .waitingUser: return "等待回答"
        }
    }

    private var stateBadgeTint: Color? {
        cardState == .hasResponse ? .primaryAccent : nil
    }

    // MARK: - Content Variants

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("我们先从 Stage 1 开始。")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(Color.textPrimary)

            Text(initialStageQuestion)
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var initialStageQuestion: String {
        let seed = project.briefDescription
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let idea = seed?.isEmpty == false ? seed! : project.name

        return "我已经收到你的初始想法：「\(idea)」。不用重复需求，请直接补充一个真实发生的使用场景：是谁，在什么时候、什么地点，遇到了什么具体不方便？"
    }

    private var streamingContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if streamingText.isEmpty {
                HStack(spacing: AppTheme.spacingSmall) {
                    ProgressView()
                        .controlSize(.small)
                    Text(resolvedActivityText)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                AssistantResponseBlock(
                    text: streamingText,
                    streamingSnapshot: streamingSnapshot,
                    baseFontSize: Self.assistantResponseBaseFontSize
                )

                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在生成回复...")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resolvedActivityText: String {
        activityText.isEmpty ? "正在分析回答……" : activityText
    }

    private var responseContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if latestAssistantText.isEmpty {
                Text("AI 正在准备下一轮澄清问题...")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                AssistantResponseBlock(
                    text: latestAssistantText,
                    baseFontSize: Self.assistantResponseBaseFontSize
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var interruptedContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AssistantResponseBlock(
                text: latestAssistantText,
                streamingSnapshot: streamingSnapshot,
                baseFontSize: Self.assistantResponseBaseFontSize
            )

            Label("生成已中断，已保留当前内容", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var waitingContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("请在下方输入你的回答")
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Context

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(AppTheme.Animation.spring) {
                    isContextExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppTheme.spacingSmall) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.primaryAccent)

                    Text("为什么这样问")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Spacer(minLength: AppTheme.spacingMedium)

                    Text(isContextExpanded ? "收起" : "展开")
                        .font(AppTheme.Typography.tiny.weight(.medium))
                        .foregroundStyle(Color.textTertiary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.primaryAccent)
                        .rotationEffect(.degrees(isContextExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isContextExpanded ? "收起追问说明" : "展开追问说明")
            .accessibilityIdentifier("clarification.context.toggle")

            if isContextExpanded {
                Divider()
                    .padding(.vertical, AppTheme.spacingMedium)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                        if !whyAsk.isEmpty {
                            whyAskSection
                        }

                        if !relatedFields.isEmpty {
                            relatedFieldsSection
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                        if !whyAsk.isEmpty {
                            whyAskSection
                        }

                        if !relatedFields.isEmpty {
                            relatedFieldsSection
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
    }

    private var relatedFieldsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            Text("可能更新")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textSecondary)

            CoDesignFlowLayout(spacing: AppTheme.spacingXS) {
                ForEach(relatedFields, id: \.self) { field in
                    Text(field.displayName)
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(Color.primaryAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primaryAccent.opacity(0.07))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Why Ask

    private var whyAskSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            Text("追问意图")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textSecondary)

            Text(whyAsk)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Divider()
                .padding(.vertical, AppTheme.spacingXS)

            CoDesignFlowLayout(spacing: AppTheme.spacingSmall) {
                ForEach(quickActions) { action in
                    Button {
                        onQuickAction(action.prompt)
                    } label: {
                        Label(action.title, systemImage: action.icon)
                            .font(AppTheme.Typography.caption.weight(.medium))
                            .padding(.horizontal, AppTheme.spacingMedium)
                            .frame(height: quickActionHeight)
                            .background(
                                Capsule()
                                    .fill(action.tint.opacity(quickActionsDisabled ? AppTheme.Opacity.hairline : AppTheme.Opacity.light))
                            )
                            .foregroundStyle(quickActionsDisabled ? Color.textTertiary : action.tint.opacity(0.88))
                    }
                    .buttonStyle(.plain)
                    .disabled(quickActionsDisabled)
                }
            }
        }
    }

    private var quickActionHeight: CGFloat {
        #if os(iOS)
        return 40
        #else
        return AppTheme.Layout.buttonHeightSmall
        #endif
    }
}

private struct ClarificationQuickAction: Identifiable {
    let title: String
    let icon: String
    let tint: Color
    let prompt: String

    var id: String { title }
}

// MARK: - AssistantResponseBlock

private struct AssistantResponseBlock: View {
    let text: String
    var streamingSnapshot: StreamingMarkdownSnapshot?
    var baseFontSize: CGFloat

    var body: some View {
        AssistantResponseTextView(
            text: text,
            streamingSnapshot: streamingSnapshot,
            baseFontSize: baseFontSize
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: AppTheme.spacingMedium) {
            // Welcome state (completely empty project)
            CurrentClarificationCard(
                project: Project(name: "新项目", briefDescription: ""),
                isStreaming: false,
                streamingText: "",
                onQuickAction: { text in print("Quick action: \(text)") },
                onSend: { text in print("Send: \(text)") }
            )

            // Has response
            CurrentClarificationCard(
                project: {
                    let p = Project(name: "校园导航", briefDescription: "")
                    let msg = ChatMessage(role: "assistant", content: "你的设计对象到底是谁？他们在什么具体场景下遇到这个问题？")
                    p.messages.append(msg)
                    p.stages = [
                        ProgressStage(order: 1, name: "痛点与场景锚定", status: "active", completionRatio: 0.3),
                    ]
                    return p
                }(),
                isStreaming: false,
                streamingText: "",
                onQuickAction: { text in print("Quick action: \(text)") },
                onSend: { text in print("Send: \(text)") }
            )

            // Streaming with text
            CurrentClarificationCard(
                project: {
                    let p = Project(name: "校园导航", briefDescription: "")
                    p.stages = [
                        ProgressStage(order: 2, name: "差异化价值提炼", status: "active", completionRatio: 0.5),
                    ]
                    return p
                }(),
                isStreaming: true,
                streamingText: "让我想想你的核心价值主张...",
                onQuickAction: { text in print("Quick action: \(text)") },
                onSend: { text in print("Send: \(text)") }
            )

            // Streaming with empty text (safety check)
            CurrentClarificationCard(
                project: {
                    let p = Project(name: "校园导航", briefDescription: "")
                    p.stages = [
                        ProgressStage(order: 3, name: "项目边界定义", status: "active", completionRatio: 0.0),
                    ]
                    return p
                }(),
                isStreaming: true,
                streamingText: "",
                onQuickAction: { text in print("Quick action: \(text)") },
                onSend: { text in print("Send: \(text)") }
            )
        }
        .padding()
    }
    .background(Color.appBackground)
}
