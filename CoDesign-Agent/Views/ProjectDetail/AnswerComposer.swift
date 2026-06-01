import SwiftUI

// MARK: - AnswerComposer

/// The input area for the Clarification Workspace.
/// Just the text field and send button — quick actions live in CurrentClarificationCard.
struct AnswerComposer: View {
    let isStreaming: Bool
    let onSend: (String) -> Void

    @State private var inputText: String = ""

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isStreaming
    }

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            // Input area
            HStack(alignment: .bottom, spacing: AppTheme.spacingSmall) {
                // Text field
                TextField("输入你的想法...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                            .fill(Color.cardBackground)
                    )
                    .disabled(isStreaming)
                    .onSubmit {
                        send()
                    }

                // Send button
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
                            .fill(canSend ? Color.primaryAccent : Color.textTertiary)
                    )
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, AppTheme.spacingMedium)
        }
        .padding(.vertical, AppTheme.spacingSmall)
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        onSend(text)
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
