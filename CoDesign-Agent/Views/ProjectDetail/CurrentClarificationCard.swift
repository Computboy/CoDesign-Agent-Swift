import SwiftUI

// MARK: - CurrentClarificationCard

/// The core visual component of v0.3 workspace.
/// Displays the current AI question, stage context, related fields, and explanation.
struct CurrentClarificationCard: View {
    let project: Project
    let isStreaming: Bool
    let streamingText: String
    let onQuickAction: (String) -> Void

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

    // MARK: - Static Mapping

    private var relatedFields: [String] {
        switch stageOrder {
        case 1: return ["targetUser", "painPoint", "useScenario"]
        case 2: return ["coreValue", "differentiation"]
        case 3: return ["mvpFeatures", "boundaryItems"]
        case 4: return ["interactionFlow", "userActions"]
        case 5: return ["risks", "failureCases"]
        case 6: return ["successMetrics", "evaluationCriteria"]
        case 7: return ["prototypePlan", "visualEvidence"]
        case 8: return ["implementationPlan", "technicalConstraints"]
        case 9: return ["finalBrief", "reflection", "nextSteps"]
        default: return []
        }
    }

    private var whyAsk: String {
        switch stageOrder {
        case 1: return "如果目标用户、痛点和使用场景不清楚，后续功能边界会变得非常泛。"
        case 2: return "这一阶段需要明确产品真正提供的价值，以及它和普通聊天工具或表单工具的区别。"
        case 3: return "明确 MVP 边界可以避免功能膨胀，让当前版本更容易完成和展示。"
        case 4: return "交互流程决定用户如何一步步参与澄清，而不是只被动等待 AI 输出。"
        case 5: return "提前识别风险可以帮助系统设计降级方案，避免 AI 追问跑偏或越界。"
        case 6: return "设计项目需要可评价的标准，否则很难判断方案是否真正有效。"
        case 7: return "课程展示需要能被看见的过程和产物，而不仅是文字说明。"
        case 8: return "技术实现路径会影响 MVP 的取舍，需要尽早和设计目标对齐。"
        case 9: return "最后阶段需要把前面的澄清结果整合为可展示、可复盘的设计方案。"
        default: return ""
        }
    }

    // MARK: - Body

    var body: some View {
        CoDesignCard(style: .highlighted(.primaryAccent)) {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {

                // Stage header
                stageHeader

                // Content area
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

                // Related fields
                if !relatedFields.isEmpty {
                    relatedFieldsSection
                }

                // Why ask
                if !whyAsk.isEmpty {
                    whyAskSection
                }

                // Quick action buttons (always visible, disabled during streaming)
                quickActionsSection
            }
        }
    }

    // MARK: - Stage Header

    private var stageHeader: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            if let stage = currentStage {
                Text("阶段 \(stage.order)")
                    .font(AppTheme.Typography.captionMono)
                    .foregroundStyle(Color.primaryAccent)

                Text(stage.name)
                    .font(AppTheme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            } else {
                Text("设计澄清")
                    .font(AppTheme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
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
            } else {
                if let attributed = try? AttributedString(markdown: streamingText) {
                    Text(attributed)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(streamingText)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在生成回复...")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }

    private var responseContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if latestAssistantText.isEmpty {
                Text("AI 正在准备下一轮澄清问题...")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let attributed = try? AttributedString(markdown: latestAssistantText) {
                    Text(attributed)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(latestAssistantText)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var waitingContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("请在下方输入你的回答")
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Related Fields

    private var relatedFieldsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            Text("本轮可能更新")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textTertiary)

            CoDesignFlowLayout(spacing: AppTheme.spacingXS) {
                ForEach(relatedFields, id: \.self) { field in
                    Text(field)
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
    }

    // MARK: - Why Ask

    private var whyAskSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            Label("为什么问", systemImage: "questionmark.circle")
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundStyle(Color.textTertiary)

            Text(whyAsk)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Divider()
                .padding(.vertical, AppTheme.spacingXS)

            CoDesignFlowLayout(spacing: AppTheme.spacingSmall) {
                Button {
                    onQuickAction("给我一个例子：请基于当前阶段和问题，给我一个具体回答示例，帮助我理解应该怎么回答。")
                } label: {
                    Label("给我一个例子", systemImage: "lightbulb")
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .padding(.horizontal, AppTheme.spacingMedium)
                        .padding(.vertical, AppTheme.spacingSmall)
                        .background(
                            Capsule()
                                .fill(Color.primaryAccent.opacity(quickActionsDisabled ? 0.05 : 0.1))
                        )
                        .foregroundStyle(quickActionsDisabled ? Color.textTertiary : Color.primaryAccent)
                }
                .buttonStyle(.plain)
                .disabled(quickActionsDisabled)

                Button {
                    onQuickAction("我还不确定：我现在还不确定，请你把这个问题拆得更简单一点，用更容易回答的方式继续引导我。")
                } label: {
                    Label("我还不确定", systemImage: "questionmark.circle")
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .padding(.horizontal, AppTheme.spacingMedium)
                        .padding(.vertical, AppTheme.spacingSmall)
                        .background(
                            Capsule()
                                .fill(Color.warning.opacity(quickActionsDisabled ? 0.05 : 0.1))
                        )
                        .foregroundStyle(quickActionsDisabled ? Color.textTertiary : Color.warning)
                }
                .buttonStyle(.plain)
                .disabled(quickActionsDisabled)

                Button {
                    onQuickAction("换个角度问：请换一个角度重新追问我这个问题，不要重复刚才的表达。")
                } label: {
                    Label("换个角度问", systemImage: "arrow.triangle.2.circlepath")
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .padding(.horizontal, AppTheme.spacingMedium)
                        .padding(.vertical, AppTheme.spacingSmall)
                        .background(
                            Capsule()
                                .fill(Color.info.opacity(quickActionsDisabled ? 0.05 : 0.1))
                        )
                        .foregroundStyle(quickActionsDisabled ? Color.textTertiary : Color.info)
                }
                .buttonStyle(.plain)
                .disabled(quickActionsDisabled)
            }
        }
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
                onQuickAction: { text in print("Quick action: \(text)") }
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
                onQuickAction: { text in print("Quick action: \(text)") }
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
                onQuickAction: { text in print("Quick action: \(text)") }
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
                onQuickAction: { text in print("Quick action: \(text)") }
            )
        }
        .padding()
    }
    .background(Color.appBackground)
}
