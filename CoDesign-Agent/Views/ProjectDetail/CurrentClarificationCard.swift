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
                ResourceCardPanel(
                    project: project,
                    title: "当前方法",
                    subtitle: "轻量显示 Agent 本轮参考的方法依据。"
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
                                .fill(Color.primaryAccent.opacity(0.07))
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
            Text("我们先从 Stage 1 开始。")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(Color.textPrimary)

            Text(initialStageQuestion)
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
                    Text("AI 正在准备下一轮澄清问题...")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: responseAreaHeight, alignment: .leading)
            } else {
                AssistantResponseViewport(
                    text: streamingText,
                    isStreaming: true,
                    font: questionFont,
                    height: responseAreaHeight
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

    private var responseContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if latestAssistantText.isEmpty {
                Text("AI 正在准备下一轮澄清问题...")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: responseAreaHeight, alignment: .leading)
            } else {
                AssistantResponseViewport(
                    text: latestAssistantText,
                    isStreaming: false,
                    font: questionFont,
                    height: responseAreaHeight
                )
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
                                .fill(Color.primaryAccent.opacity(0.07))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.panelBackground.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
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
                .fill(Color.panelBackground.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
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
                                    .fill(action.tint.opacity(quickActionsDisabled ? 0.04 : 0.07))
                            )
                            .foregroundStyle(quickActionsDisabled ? Color.textTertiary : action.tint.opacity(0.88))
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

// MARK: - AssistantResponseViewport

private struct AssistantResponseViewport: View {
    let text: String
    let isStreaming: Bool
    let font: Font
    let height: CGFloat

    private let bottomID = "assistant-response-bottom"

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if isStreaming {
                            StreamingPlainAssistantText(text: text, font: font)
                                .frame(width: proxy.size.width, alignment: .topLeading)
                        } else {
                            StructuredAssistantText(text: text, font: font)
                                .frame(width: proxy.size.width, alignment: .topLeading)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .frame(width: proxy.size.width, alignment: .topLeading)
                }
                .coDesignHideScrollIndicators()
                .onAppear {
                    scrollToBottom(scrollProxy)
                }
                .onChange(of: text) { _, _ in
                    scrollToBottom(scrollProxy)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(.linear(duration: 0.08)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
}

private struct StreamingPlainAssistantText: View {
    let text: String
    let font: Font

    @State private var displayedText = ""
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        Text(displayedText)
            .font(font)
            .foregroundStyle(Color.textPrimary)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onAppear {
                reveal(toward: text)
            }
            .onChange(of: text) { _, newValue in
                reveal(toward: newValue)
            }
            .onDisappear {
                revealTask?.cancel()
            }
    }

    private func reveal(toward target: String) {
        revealTask?.cancel()

        guard target.hasPrefix(displayedText) else {
            displayedText = target
            return
        }

        let suffix = String(target.dropFirst(displayedText.count))
        guard !suffix.isEmpty else { return }

        revealTask = Task { @MainActor in
            var buffer = displayedText
            var index = suffix.startIndex

            while index < suffix.endIndex && !Task.isCancelled {
                let nextIndex = suffix.index(index, offsetBy: suffix.count > 80 ? 4 : 1, limitedBy: suffix.endIndex) ?? suffix.endIndex
                buffer.append(contentsOf: suffix[index..<nextIndex])
                displayedText = buffer
                index = nextIndex
                try? await Task.sleep(for: .milliseconds(suffix.count > 80 ? 6 : 10))
            }
        }
    }
}

private struct StructuredAssistantText: View {
    let text: String
    let font: Font

    var body: some View {
        let lines = formattedLines
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.isSpacer {
                    Color.clear.frame(height: 2)
                } else if let label = line.label {
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(labelTint(for: label).opacity(0.72))
                            .frame(width: 5, height: 5)
                            .padding(.top, 10)

                        Text(line.body)
                            .font(font)
                            .foregroundStyle(Color.textPrimary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let attributed = try? AttributedString(markdown: line.body) {
                    Text(attributed)
                        .font(font)
                        .foregroundStyle(Color.textPrimary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(line.body)
                        .font(font)
                        .foregroundStyle(Color.textPrimary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var formattedLines: [StructuredAssistantLine] {
        let rawLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        if rawLines.count <= 1 {
            return splitLongParagraph(text)
        }

        return rawLines.map { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return StructuredAssistantLine(isSpacer: true) }
            if let parsed = parseTaggedLine(trimmed) {
                return parsed
            } else {
                return StructuredAssistantLine(body: trimmed)
            }
        }
    }

    private func splitLongParagraph(_ value: String) -> [StructuredAssistantLine] {
        let separators = CharacterSet(charactersIn: "。？！；")
        let chunks = value
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard chunks.count > 1 else {
            return [StructuredAssistantLine(body: value)]
        }

        return chunks.prefix(6).map { StructuredAssistantLine(body: $0) }
    }

    private func parseTaggedLine(_ line: String) -> StructuredAssistantLine? {
        let knownLabels = ["理解", "线索", "选项", "追问", "例子", "下一步", "这个问题会决定"]
        for separator in ["｜", "|", "：", ":"] {
            guard let range = line.range(of: separator) else { continue }
            let label = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let body = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard knownLabels.contains(label), !body.isEmpty else { continue }
            return StructuredAssistantLine(label: label, body: naturalSentence(label: label, body: body))
        }
        return nil
    }

    private func naturalSentence(label: String, body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)

        switch label {
        case "理解":
            return prefixedSentence("我先确认一下：", body: trimmed)
        case "线索":
            return prefixedSentence("现在缺的线索是：", body: trimmed)
        case "这个问题会决定":
            return prefixedSentence("这个问题会决定：", body: trimmed)
        case "选项":
            return prefixedSentence("可以这样看：", body: trimmed)
        case "追问":
            return prefixedSentence("所以这轮只问一个问题：", body: trimmed)
        case "例子":
            return prefixedSentence("比如：", body: trimmed)
        case "下一步":
            return prefixedSentence("接下来：", body: trimmed)
        default:
            return trimmed
        }
    }

    private func prefixedSentence(_ prefix: String, body: String) -> String {
        guard !body.hasPrefix(prefix) else { return body }
        return prefix + body
    }

    private func labelTint(for label: String) -> Color {
        switch label {
        case "理解": return .primaryAccent
        case "线索": return .warning
        case "这个问题会决定": return .primaryAccent
        case "选项", "例子": return .secondaryAccent
        case "追问": return .success
        default: return .textSecondary
        }
    }
}

private struct StructuredAssistantLine {
    var label: String?
    var body: String
    var isSpacer: Bool

    init(label: String? = nil, body: String = "", isSpacer: Bool = false) {
        self.label = label
        self.body = body
        self.isSpacer = isSpacer
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
