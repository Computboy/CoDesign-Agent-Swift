import SwiftUI

// MARK: - CurrentClarificationCard

/// The core visual component of v0.3 workspace.
/// Displays the current AI question, stage context, related fields, and explanation.
struct CurrentClarificationCard: View {
    let project: Project
    let isStreaming: Bool
    let streamingText: String
    let onQuickAction: (String) -> Void
    let onSend: (String) -> Void
    private let responseAreaHeight: CGFloat = 190

    // MARK: - State

    private enum CardState {
        case welcome      // No messages yet
        case streaming    // AI is generating
        case hasResponse  // Latest assistant message available
        case waitingUser  // Latest message is from user (waiting for next AI turn)
    }

    private var cardState: CardState {
        if isStreaming { return .streaming }
        let sorted = project.messages.sorted { $0.timestamp < $1.timestamp }
        if sorted.isEmpty { return .welcome }
        if sorted.last?.role == "assistant" { return .hasResponse }
        return .waitingUser
    }

    private var latestAssistantText: String {
        if isStreaming { return streamingText }
        let sorted = project.messages.sorted { $0.timestamp < $1.timestamp }
        return sorted.last(where: { $0.role == "assistant" })?.content ?? ""
    }

    /// Whether quick actions should be disabled (streaming or no conversation yet)
    private var quickActionsDisabled: Bool {
        isStreaming || cardState == .welcome
    }

    private var currentStage: ProgressStage? {
        let sorted = project.stages.sorted { $0.order < $1.order }
        return sorted.first(where: { $0.status == "active" })
            ?? sorted.first(where: { $0.status == "notStarted" })
    }

    private var stageOrder: Int {
        currentStage?.order ?? 1
    }

    private var currentDefinition: StageDefinition? {
        StageDefinition.all.first(where: { $0.order == stageOrder })
    }

    private var questionFont: Font {
        Font.system(.title3, design: .default)
    }

    private var relatedFields: [BriefField] {
        currentDefinition?.briefFields ?? []
    }

    private var whyAsk: String {
        currentDefinition?.compactPurpose ?? ""
    }

    private var quickActions: [ClarificationQuickAction] {
        [
            ClarificationQuickAction(
                title: "给我一个例子",
                icon: "lightbulb",
                tint: .primaryAccent,
                prompt: "给我一个例子：请基于当前阶段和问题，给我一个具体回答示例，帮助我理解应该怎么回答。"
            ),
            ClarificationQuickAction(
                title: "我还不确定",
                icon: "questionmark.circle",
                tint: .warning,
                prompt: "我还不确定：我现在还不确定，请你把这个问题拆得更简单一点，用更容易回答的方式继续引导我。"
            ),
            ClarificationQuickAction(
                title: "换个角度问",
                icon: "arrow.triangle.2.circlepath",
                tint: .info,
                prompt: "换个角度问：请换一个角度重新追问我这个问题，不要重复刚才的表达。"
            ),
            ClarificationQuickAction(
                title: "生成边界草稿",
                icon: "rectangle.dashed",
                tint: .secondaryAccent,
                prompt: "请基于我已有回答，先帮我草拟一个 MVP 范围，包括“现在做什么”和“暂时不做什么”，但不要替我最终决定。"
            ),
            ClarificationQuickAction(
                title: "跳过",
                icon: "forward",
                tint: .textSecondary,
                prompt: "这个问题先跳过，请基于已有信息继续推进到下一个最合理的澄清点。"
            ),
        ]
    }

    // MARK: - Body

    var body: some View {
        CoDesignCard(style: .normal) {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                stageHeader

                switch cardState {
                case .welcome:
                    welcomeContent
                case .streaming:
                    streamingContent
                case .hasResponse:
                    responseContent
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
                        .padding(.horizontal, 10)
                        .frame(height: AppTheme.Layout.badgeHeight)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primaryAccent.opacity(0.10))
                        )
                } else {
                    Text("设计澄清")
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            CoDesignStatusBadge(status: stateBadgeStatus, text: stateBadgeText)
        }
    }

    private var stateBadgeStatus: CoDesignStatusBadge.Status {
        switch cardState {
        case .welcome:     return .info
        case .streaming:   return .active
        case .hasResponse: return .complete
        case .waitingUser: return .partial
        }
    }

    private var stateBadgeText: String {
        switch cardState {
        case .welcome:     return "准备开始"
        case .streaming:   return "AI 思考中"
        case .hasResponse: return "已生成"
        case .waitingUser: return "等待回答"
        }
    }

    // MARK: - Content Variants

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("设计澄清工作台")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(Color.textPrimary)

            Text("在下方输入你的初始设计想法。CoDesign Agent 会将你的想法拆解为 9 个澄清阶段，通过追问帮你逐步明确目标用户、核心痛点、功能边界和实施方案。")
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var streamingContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if streamingText.isEmpty {
                HStack(spacing: AppTheme.spacingSmall) {
                    ProgressView()
                        .controlSize(.small)
                    Text("AI 正在准备下一轮澄清问题...")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: responseAreaHeight, alignment: .leading)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    if let attributed = try? AttributedString(markdown: streamingText) {
                        Text(attributed)
                            .font(questionFont)
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(streamingText)
                            .font(questionFont)
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, minHeight: responseAreaHeight, maxHeight: responseAreaHeight, alignment: .topLeading)

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

    private var responseContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if latestAssistantText.isEmpty {
                Text("AI 正在准备下一轮澄清问题...")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: responseAreaHeight, alignment: .leading)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    if let attributed = try? AttributedString(markdown: latestAssistantText) {
                        Text(attributed)
                            .font(questionFont)
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(latestAssistantText)
                            .font(questionFont)
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, minHeight: responseAreaHeight, maxHeight: responseAreaHeight, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var waitingContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("请在下方输入你的回答")
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Context

    private var contextSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
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
                                .fill(Color.primaryAccent.opacity(0.1))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.primaryAccent.opacity(0.045))
        )
    }

    // MARK: - Why Ask

    private var whyAskSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            Label("追问意图", systemImage: "questionmark.circle")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textSecondary)

            Text(whyAsk)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.softAccentBackground)
        )
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
                            .frame(height: AppTheme.Layout.buttonHeightSmall)
                            .background(
                                Capsule()
                                    .fill(action.tint.opacity(quickActionsDisabled ? 0.05 : 0.10))
                            )
                            .foregroundStyle(quickActionsDisabled ? Color.textTertiary : action.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(quickActionsDisabled)
                }
            }
        }
    }
}

private struct ClarificationQuickAction: Identifiable {
    let title: String
    let icon: String
    let tint: Color
    let prompt: String

    var id: String { title }
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
