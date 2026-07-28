import SwiftUI

// MARK: - AnswerComposer

/// The input area for the Clarification Workspace.
/// Just the text field and send button — quick actions live in CurrentClarificationCard.
struct AnswerComposer: View {
    let isStreaming: Bool
    let onSend: (String) -> Void

    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isStreaming
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.spacingSmall) {
            TextField("输入你的想法...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .fill(Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(
                            Color.primaryAccent.opacity(
                                isInputFocused
                                    ? 0.90
                                    : 0.62
                            ),
                            lineWidth: isInputFocused ? 2 : 1.5
                        )
                )
                .animation(AppTheme.Animation.quick, value: isInputFocused)
                .disabled(isStreaming)
                #if os(macOS)
                .submitLabel(.send)
                .onSubmit { send() }
                #else
                .submitLabel(.return)
                #endif
                #if os(iOS)
                .textInputAutocapitalization(.sentences)
                #endif

            Button {
                send()
            } label: {
                Group {
                    if isStreaming {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundStyle(
                    canSend
                        ? Color.white
                        : Color.primaryAccent.opacity(AppTheme.Opacity.muted)
                )
                .frame(width: sendButtonSize, height: sendButtonSize)
                .background(
                    Circle()
                        .fill(
                            canSend
                                ? Color.primaryAccent
                                : Color.primaryAccent.opacity(AppTheme.Opacity.medium)
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color.primaryAccent.opacity(
                                canSend
                                    ? AppTheme.Opacity.noticeable
                                    : AppTheme.Opacity.medium
                            ),
                            lineWidth: AppTheme.Border.thin
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingSmall)
        .task {
            refocusWhenReady()
        }
        .onChange(of: isStreaming) { _, streaming in
            if !streaming {
                refocusWhenReady()
            }
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false
        onSend(text)
    }

    private func refocusWhenReady() {
        guard !isStreaming else { return }
        #if os(iOS)
        return
        #else
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !isStreaming else { return }
            isInputFocused = true
        }
        #endif
    }

    private var sendButtonSize: CGFloat {
        #if os(iOS)
        return 50
        #else
        return 36
        #endif
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        AnswerComposer(isStreaming: false) { text in
            print("Send: \(text)")
        }
        .background(Color.appBackground)
    }
}

#Preview("Streaming") {
    VStack {
        Spacer()
        AnswerComposer(isStreaming: true) { _ in }
            .background(Color.appBackground)
    }
}
