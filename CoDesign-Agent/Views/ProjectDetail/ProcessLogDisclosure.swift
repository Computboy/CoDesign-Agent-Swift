import SwiftUI

// MARK: - ProcessLogDisclosure

/// A collapsible section that displays the message history (process log).
/// Default state is collapsed to keep the workspace focused.
/// Uses existing MessageBubble for consistent message rendering with Markdown support.
struct ProcessLogDisclosure: View {
    let messages: [ChatMessage]
    let isStreaming: Bool
    let streamingText: String

    @State private var isExpanded: Bool = false

    private var sortedMessages: [ChatMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toggle header
            Button {
                withAnimation(AppTheme.Animation.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppTheme.spacingSmall) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textTertiary)

                    Text("过程记录")
                        .font(AppTheme.Typography.subheadline.weight(.medium))
                        .foregroundStyle(Color.textSecondary)

                    if !messages.isEmpty {
                        Text("\(messages.count)")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.textTertiary.opacity(0.15))
                            )
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.vertical, AppTheme.spacingSmall)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, AppTheme.spacingMedium)

                if sortedMessages.isEmpty && !isStreaming {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.spacingSmall) {
                            ForEach(sortedMessages) { message in
                                MessageBubble(message: message)
                            }

                            // Streaming message
                            if isStreaming && !streamingText.isEmpty {
                                HStack {
                                    Group {
                                        if let attributed = try? AttributedString(markdown: streamingText) {
                                            Text(attributed)
                                        } else {
                                            Text(streamingText)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.cardBackground)
                                    .foregroundStyle(Color.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .frame(maxWidth: 280, alignment: .leading)
                                    Spacer()
                                }
                            }
                        }
                        .padding(AppTheme.spacingMedium)
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
        .background(Color.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            Text("还没有对话记录")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingLarge)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: AppTheme.spacingMedium) {
        ProcessLogDisclosure(
            messages: [],
            isStreaming: false,
            streamingText: ""
        )

        ProcessLogDisclosure(
            messages: [
                ChatMessage(role: "user", content: "我想做一个校园导航应用"),
                ChatMessage(role: "assistant", content: "这个想法很有意思！能告诉我，你觉得哪类学生最需要这个？"),
            ],
            isStreaming: false,
            streamingText: ""
        )
    }
    .padding()
    .background(Color.appBackground)
}
