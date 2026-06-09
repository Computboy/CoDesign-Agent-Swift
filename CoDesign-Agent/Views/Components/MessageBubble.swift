import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }

            Group {
                if message.role == "assistant",
                   let attributed = try? AttributedString(markdown: message.content) {
                    Text(attributed)
                } else {
                    Text(message.content)
                }
            }
            .font(AppTheme.Typography.body)
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
            .background(backgroundColor)
            .foregroundStyle(textColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .frame(maxWidth: 300, alignment: message.role == "user" ? .trailing : .leading)
            .coDesignShadow(.card)

            if message.role == "assistant" {
                Spacer()
            }
        }
    }

    private var backgroundColor: Color {
        message.role == "user" ? .primaryAccent : .cardBackground
    }

    private var textColor: Color {
        message.role == "user" ? .white : .textPrimary
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(message: ChatMessage(role: "user", content: "我想做一个校园导航应用"))
        MessageBubble(message: ChatMessage(role: "assistant", content: "这个想法很有意思！能告诉我，你觉得哪类学生最需要这个？"))
    }
    .padding()
}
