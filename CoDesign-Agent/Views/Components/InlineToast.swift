import SwiftUI

/// 轻量级的内联提示组件，用于显示 success / warning / info 反馈
struct InlineToast: View {
    enum ToastType {
        case success
        case warning
        case info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .success
            case .warning: return .warning
            case .info: return .info
            }
        }
    }

    let type: ToastType
    let message: String
    let onDismiss: () -> Void

    @State private var isVisible: Bool = true

    var body: some View {
        if isVisible {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: type.icon)
                    .foregroundStyle(type.color)

                Text(message)
                    .font(AppTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button {
                    withAnimation(AppTheme.Animation.standard) {
                        isVisible = false
                    }
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .fill(type.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                            .stroke(type.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VStack(spacing: AppTheme.spacingMedium) {
        InlineToast(
            type: .success,
            message: "字段已确认",
            onDismiss: {}
        )

        InlineToast(
            type: .warning,
            message: "字段已标记为不准确",
            onDismiss: {}
        )

        InlineToast(
            type: .info,
            message: "编辑已保存",
            onDismiss: {}
        )
    }
    .padding()
    .background(Color.appBackground)
}
