import SwiftUI
import Combine

struct TypingIndicatorView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            Text("AI 正在思考")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.primaryAccent)
                        .frame(width: 4, height: 4)
                        .opacity(index <= dotCount ? 1.0 : 0.3)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                dotCount = (dotCount + 1) % 3
            }
        }
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
}
