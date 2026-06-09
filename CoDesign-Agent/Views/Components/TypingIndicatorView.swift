import SwiftUI
import Combine

struct TypingIndicatorView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            Text("AI 正在思考")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: AppTheme.spacingXXS) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.primaryAccent)
                        .frame(width: 4, height: 4)
                        .opacity(index <= dotCount ? 1.0 : AppTheme.Opacity.soft)
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
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
