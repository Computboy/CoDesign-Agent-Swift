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
        HStack(alignment: .bottom, spacing: AppTheme.spacingSmall) {
            TextField("输入你的想法...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .fill(Color.elevatedCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(Color.primaryAccent.opacity(0.08), lineWidth: AppTheme.Border.thin)
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
                        .fill(canSend ? Color.primaryAccent : Color.textTertiary)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .frame(maxWidth: .infinity)
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
