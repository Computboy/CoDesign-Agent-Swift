import SwiftUI

// MARK: - CurrentClarificationCard

/// The core visual component of v0.3 workspace.
/// Displays the current AI question, stage context, related fields, and explanation.
struct CurrentClarificationCard: View {
    let project: Project
    let isStreaming: Bool
    let streamingText: String

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
        case 1: return ["目标用户", "核心痛点", "使用场景"]
        case 2: return ["核心价值", "差异化"]
        case 3: return ["项目边界", "MVP 功能"]
        case 4: return ["技术模块", "交互流程"]
        case 5: return ["运行逻辑"]
        case 6: return ["硬性约束"]
        case 7: return ["验收标准"]
        case 8: return ["风险预案"]
        case 9: return ["里程碑"]
        default: return []
        }
    }

    private var whyAsk: String {
        switch stageOrder {
        case 1: return "如果目标用户和使用场景不清楚，后续功能边界会变得非常泛。"
        case 2: return "没有清晰的价值主张，设计方案容易沦为通用方案的翻版。"
        case 3: return "不划定边界，MVP 会无限膨胀，导致无法交付。"
        case 4: return "功能和技术方案需要与边界对齐，否则会出现过度设计。"
        case 5: return "运行逻辑不清晰会导致用户体验断裂或异常处理缺失。"
        case 6: return "硬性约束（时间、预算、技术栈）决定了方案的可行性。"
        case 7: return "没有可量化指标，就无法判断设计是否成功。"
        case 8: return "提前识别风险可以降低项目失败的概率。"
        case 9: return "里程碑帮助拆解大任务，避免最后一刻赶工。"
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
            Text("你好！我是 CoDesign Agent")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(Color.textPrimary)

            Text("在下面输入你的设计想法，我会通过追问帮你逐步澄清目标用户、核心痛点、功能边界和方案。不用一次想清楚，我们一步步来。")
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var streamingContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
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

    private var responseContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
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
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: AppTheme.spacingMedium) {
            // Welcome state
            CurrentClarificationCard(
                project: Project(name: "新项目", briefDescription: ""),
                isStreaming: false,
                streamingText: ""
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
                streamingText: ""
            )

            // Streaming
            CurrentClarificationCard(
                project: {
                    let p = Project(name: "校园导航", briefDescription: "")
                    p.stages = [
                        ProgressStage(order: 2, name: "差异化价值提炼", status: "active", completionRatio: 0.5),
                    ]
                    return p
                }(),
                isStreaming: true,
                streamingText: "让我想想你的核心价值主张..."
            )
        }
        .padding()
    }
    .background(Color.appBackground)
}
