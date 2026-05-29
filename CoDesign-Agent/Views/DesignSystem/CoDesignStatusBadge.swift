import SwiftUI

// MARK: - CoDesignStatusBadge

/// A compact status badge for displaying state information.
/// Used in StageRail, InsightCards, ProjectCards, and ClarificationCards.
///
/// Usage:
/// ```swift
/// CoDesignStatusBadge(status: .active)
/// CoDesignStatusBadge(status: .complete, text: "已完成")
/// CoDesignStatusBadge(status: .warning, text: "需要复查")
/// ```
struct CoDesignStatusBadge: View {

    enum Status: String {
        case active
        case complete
        case partial
        case warning
        case locked
        case error
        case info

        var defaultText: String {
            switch self {
            case .active:   return "进行中"
            case .complete: return "已完成"
            case .partial:  return "部分"
            case .warning:  return "需注意"
            case .locked:   return "未解锁"
            case .error:    return "错误"
            case .info:     return "信息"
            }
        }

        var iconName: String {
            switch self {
            case .active:   return "circle.fill"
            case .complete: return "checkmark.circle.fill"
            case .partial:  return "circle.lefthalf.filled"
            case .warning:  return "exclamationmark.triangle.fill"
            case .locked:   return "lock.fill"
            case .error:    return "xmark.circle.fill"
            case .info:     return "info.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .active:   return .stageActive
            case .complete: return .stageCompleted
            case .partial:  return .warning
            case .warning:  return .warning
            case .locked:   return .stageNotStarted
            case .error:    return .danger
            case .info:     return .info
            }
        }
    }

    let status: Status
    let text: String?

    init(status: Status, text: String? = nil) {
        self.status = status
        self.text = text
    }

    var body: some View {
        HStack(spacing: AppTheme.spacingXS) {
            Image(systemName: status.iconName)
                .font(.system(size: 10, weight: .semibold))

            Text(text ?? status.defaultText)
                .font(AppTheme.Typography.caption.weight(.medium))
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 8)
        .frame(height: AppTheme.Layout.badgeHeight)
        .background(
            Capsule(style: .continuous)
                .fill(status.tint.opacity(0.12))
        )
    }
}

// MARK: - Preview

#Preview("CoDesignStatusBadge") {
    VStack(spacing: AppTheme.spacingLarge) {
        // All default labels
        HStack(spacing: AppTheme.spacingSmall) {
            CoDesignStatusBadge(status: .active)
            CoDesignStatusBadge(status: .complete)
            CoDesignStatusBadge(status: .partial)
        }

        HStack(spacing: AppTheme.spacingSmall) {
            CoDesignStatusBadge(status: .warning)
            CoDesignStatusBadge(status: .locked)
            CoDesignStatusBadge(status: .error)
            CoDesignStatusBadge(status: .info)
        }

        Divider()

        // Custom labels
        HStack(spacing: AppTheme.spacingSmall) {
            CoDesignStatusBadge(status: .complete, text: "Stage 1 Done")
            CoDesignStatusBadge(status: .active, text: "Clarifying")
            CoDesignStatusBadge(status: .warning, text: "Missing Fields")
        }
    }
    .padding()
    .background(Color.appBackground)
}
