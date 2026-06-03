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
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .fill(Color.elevatedCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
                )
                .disabled(isStreaming)
                .onSubmit { send() }

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
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(canSend ? Color.primaryAccent : Color.textTertiary.opacity(0.45))
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
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !isStreaming else { return }
            isInputFocused = true
        }
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
