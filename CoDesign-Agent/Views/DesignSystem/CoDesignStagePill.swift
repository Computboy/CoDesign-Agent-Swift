import SwiftUI

// MARK: - CoDesignStagePill

/// A compact pill representing one stage in the 9-stage design clarification process.
/// Used by StageRail (future) and stage overview components.
///
/// Usage:
/// ```swift
/// CoDesignStagePill(order: 1, name: "痛点与场景锚定", state: .active)
/// CoDesignStagePill(order: 3, name: "项目边界定义", state: .complete)
/// ```
struct CoDesignStagePill: View {

    enum State {
        case locked
        case active
        case partial
        case complete
        case warning

        var tint: Color {
            switch self {
            case .locked:   return .stageNotStarted
            case .active:   return .stageActive
            case .partial:  return .warning
            case .complete: return .stageCompleted
            case .warning:  return .danger
            }
        }

        var iconName: String? {
            switch self {
            case .locked:   return "lock.fill"
            case .active:   return nil
            case .partial:  return nil
            case .complete: return "checkmark"
            case .warning:  return "exclamationmark"
            }
        }
    }

    let order: Int
    let name: String
    let state: State
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: AppTheme.spacingXS) {
            // Number or icon
            Group {
                if let iconName = state.iconName, state != .active {
                    Image(systemName: iconName)
                        .font(.system(size: isCompact ? 9 : 10, weight: .bold))
                } else {
                    Text(String(format: "%d", order))
                        .font(AppTheme.Typography.captionMono)
                }
            }
            .frame(width: isCompact ? 16 : 20, height: isCompact ? 16 : 20)
            .background(
                Circle()
                    .fill(state.tint.opacity(state == .locked ? 0.15 : 0.2))
            )
            .foregroundStyle(state.tint)

            // Name (hidden in compact mode)
            if !isCompact {
                Text(name)
                    .font(AppTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(state == .locked ? Color.textTertiary : Color.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, isCompact ? 6 : 10)
        .frame(height: AppTheme.Layout.stagePillHeight)
        .background(
            Capsule(style: .continuous)
                .fill(state == .active
                    ? state.tint.opacity(0.15)
                    : Color.textTertiary.opacity(0.08)
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    state == .active ? state.tint.opacity(0.5) : Color.clear,
                    lineWidth: AppTheme.Border.thin
                )
        )
    }
}

// MARK: - Preview

#Preview("CoDesignStagePill") {
    ScrollView {
        VStack(spacing: AppTheme.spacingLarge) {

            // Full-size pills
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Full Size").font(AppTheme.Typography.caption).foregroundStyle(.secondary)

                CoDesignStagePill(order: 1, name: "痛点与场景锚定", state: .complete)
                CoDesignStagePill(order: 2, name: "差异化价值提取", state: .active)
                CoDesignStagePill(order: 3, name: "项目边界定义", state: .partial)
                CoDesignStagePill(order: 4, name: "功能与技术拆解", state: .warning)
                CoDesignStagePill(order: 5, name: "运行逻辑与规则", state: .locked)
            }

            Divider()

            // Compact pills
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Compact").font(AppTheme.Typography.caption).foregroundStyle(.secondary)

                HStack(spacing: AppTheme.spacingXS) {
                    CoDesignStagePill(order: 1, name: "痛点", state: .complete, isCompact: true)
                    CoDesignStagePill(order: 2, name: "价值", state: .active, isCompact: true)
                    CoDesignStagePill(order: 3, name: "边界", state: .partial, isCompact: true)
                    CoDesignStagePill(order: 4, name: "功能", state: .locked, isCompact: true)
                    CoDesignStagePill(order: 5, name: "逻辑", state: .locked, isCompact: true)
                    CoDesignStagePill(order: 6, name: "约束", state: .locked, isCompact: true)
                    CoDesignStagePill(order: 7, name: "指标", state: .locked, isCompact: true)
                    CoDesignStagePill(order: 8, name: "风险", state: .locked, isCompact: true)
                    CoDesignStagePill(order: 9, name: "里程碑", state: .locked, isCompact: true)
                }
            }
        }
        .padding()
    }
    .background(Color.appBackground)
}
