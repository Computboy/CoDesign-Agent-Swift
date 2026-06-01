import SwiftUI

// MARK: - ProcessLogDisclosure

/// A collapsible section that displays the conversation history as a timeline-style process log.
/// Default state is collapsed to keep the workspace focused on current clarification task.
/// Shows compact message rows (not chat bubbles) to emphasize audit/process nature.
/// Features smooth expand/collapse animation with rotation and fade effects.
struct ProcessLogDisclosure: View {
    let messages: [ChatMessage]
    let isStreaming: Bool
    let streamingText: String

    @State private var isExpanded: Bool = false
    @State private var rotationAngle: Double = 0

    private var sortedMessages: [ChatMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        CoDesignCard {
            VStack(spacing: 0) {
                // Toggle header
                Button {
                    withAnimation(AppTheme.Animation.spring) {
                        isExpanded.toggle()
                        rotationAngle += 180
                    }
                } label: {
                    HStack(spacing: AppTheme.spacingSmall) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)

                        Text("过程记录")
                            .font(AppTheme.Typography.subheadline.weight(.medium))
                            .foregroundStyle(Color.textSecondary)

                        if !messages.isEmpty {
                            Text("\(messages.count) 条消息")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(Color.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                            .rotationEffect(.degrees(rotationAngle))
                    }
                }
                .buttonStyle(.plain)

                // Expanded content with transition
                if isExpanded {
                    Divider()
                        .padding(.vertical, AppTheme.spacingSmall)
                        .transition(.opacity)

                    if sortedMessages.isEmpty && !isStreaming {
                        emptyState
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                                ForEach(sortedMessages) { message in
                                    ProcessLogMessageRow(message: message)
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                }

                                // Streaming message
                                if isStreaming && !streamingText.isEmpty {
                                    ProcessLogMessageRow(
                                        role: "assistant",
                                        content: streamingText,
                                        timestamp: Date(),
                                        isStreaming: true
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }
                        }
                        .coDesignHideScrollIndicators()
                        .frame(maxHeight: 400)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: "text.bubble")
                .font(.system(size: 24))
                .foregroundStyle(Color.textTertiary.opacity(0.5))

            Text("还没有过程记录")
                .font(AppTheme.Typography.subheadline.weight(.medium))
                .foregroundStyle(Color.textSecondary)

            Text("开始回答后，AI 追问和你的回答会出现在这里")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingLarge)
    }
}

// MARK: - ProcessLogMessageRow

/// A compact timeline-style message row for the process log.
/// Designed to look like an audit log entry, not a chat bubble.
struct ProcessLogMessageRow: View {
    let role: String
    let content: String
    let timestamp: Date
    let isStreaming: Bool

    init(message: ChatMessage) {
        self.role = message.role
        self.content = message.content
        self.timestamp = message.timestamp
        self.isStreaming = false
    }

    init(role: String, content: String, timestamp: Date, isStreaming: Bool) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }

    private var isUser: Bool {
        role == "user"
    }

    private var roleLabel: String {
        isUser ? "用户回答" : "AI 追问"
    }

    private var roleIcon: String {
        isUser ? "person.fill" : "sparkles"
    }

    private var roleColor: Color {
        isUser ? .primaryAccent : .secondaryAccent
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            // Role icon
            Image(systemName: roleIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(roleColor)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(roleColor.opacity(0.1))
                )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppTheme.spacingSmall) {
                    Text(roleLabel)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(roleColor)

                    Text(timestamp, style: .time)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)

                    if isStreaming {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }

                // Message content with Markdown support
                if let attributed = try? AttributedString(markdown: content) {
                    Text(attributed)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(6)
                } else {
                    Text(content)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(6)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: AppTheme.spacingMedium) {
            // Empty state
            ProcessLogDisclosure(
                messages: [],
                isStreaming: false,
                streamingText: ""
            )

            // With messages
            ProcessLogDisclosure(
                messages: [
                    ChatMessage(role: "user", content: "我想做一个帮助设计学生澄清想法的工具"),
                    ChatMessage(role: "assistant", content: "这个想法很有意思！能告诉我，你希望它主要帮助学生解决哪个阶段的问题？是项目前期的想法发散，还是中期的方案细化？"),
                    ChatMessage(role: "user", content: "主要是前期，很多学生一开始只有一个模糊的方向，不知道怎么具体化"),
                    ChatMessage(role: "assistant", content: "明白了。那你觉得学生在这个阶段最大的痛点是什么？是不知道要问自己什么问题，还是不知道怎么组织已有的想法？"),
                ],
                isStreaming: false,
                streamingText: ""
            )

            // Streaming
            ProcessLogDisclosure(
                messages: [
                    ChatMessage(role: "user", content: "我想做一个校园导航应用"),
                ],
                isStreaming: true,
                streamingText: "这个想法很有趣！让我想想..."
            )
        }
        .padding()
    }
    .background(Color.appBackground)
}
