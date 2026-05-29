import SwiftUI
import SwiftData

struct ChatPanel: View {
    let project: Project
    let chatViewModel: ChatViewModel

    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            messageList

            // 错误提示
            if let errorMessage = chatViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.danger)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.danger.opacity(0.1))
            }

            Divider()

            // 输入区域
            inputArea
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if project.messages.isEmpty && !chatViewModel.isStreaming {
                        emptyState
                    }

                    let sortedMessages = project.messages.sorted { $0.timestamp < $1.timestamp }
                    ForEach(sortedMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // 正在生成的消息
                    if chatViewModel.isStreaming && !chatViewModel.currentStreamingText.isEmpty {
                        HStack {
                            Group {
                                if let attributed = try? AttributedString(markdown: chatViewModel.currentStreamingText) {
                                    Text(attributed)
                                } else {
                                    Text(chatViewModel.currentStreamingText)
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
                        .id("streaming")
                    }

                    // Typing indicator
                    if chatViewModel.isStreaming && chatViewModel.currentStreamingText.isEmpty {
                        HStack {
                            TypingIndicatorView()
                                .frame(maxWidth: 200)
                            Spacer()
                        }
                        .id("typing")
                    }
                }
                .padding()
            }
            .onChange(of: project.messages.count) {
                if let lastMessage = project.messages.sorted(by: { $0.timestamp < $1.timestamp }).last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatViewModel.currentStreamingText) {
                if chatViewModel.isStreaming {
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            Text("从一个模糊想法开始")
                .font(.headline)
                .foregroundStyle(Color.textSecondary)

            Text("AI 会通过追问帮你逐步澄清设计任务")
                .font(.subheadline)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("输入你的想法...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(chatViewModel.isStreaming)
                .onSubmit {
                    if canSend {
                        Task {
                            let text = inputText
                            inputText = ""
                            await chatViewModel.sendMessage(text)
                        }
                    }
                }

            Button {
                Task {
                    let text = inputText
                    inputText = ""
                    await chatViewModel.sendMessage(text)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? Color.primaryAccent : Color.textTertiary)
            }
            .disabled(!canSend)
        }
        .padding()
        .background(Color.appBackground)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !chatViewModel.isStreaming
    }
}
