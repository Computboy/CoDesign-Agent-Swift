import SwiftUI

// MARK: - Color Tokens

extension Color {

    // MARK: 基础背景

    static let appBackground: Color = {
        #if canImport(UIKit)
        return Color(.systemBackground)
        #else
        return Color(red: 1.0, green: 1.0, blue: 1.0)
        #endif
    }()

    static let cardBackground: Color = {
        #if canImport(UIKit)
        return Color(.secondarySystemBackground)
        #else
        return Color(red: 0.97, green: 0.97, blue: 0.97)
        #endif
    }()

    static let elevatedCardBackground: Color = {
        #if canImport(UIKit)
        return Color(.tertiarySystemBackground)
        #else
        return Color(red: 1.0, green: 1.0, blue: 1.0)
        #endif
    }()

    // MARK: 品牌色

    static let primaryAccent = Color(red: 0.35, green: 0.47, blue: 0.93)   // 柔和蓝紫
    static let secondaryAccent = Color(red: 0.58, green: 0.44, blue: 0.86) // 柔和紫
    static let softAccentBackground = Color(red: 0.94, green: 0.95, blue: 0.99)

    // MARK: 文本色

    static let textPrimary: Color = {
        #if canImport(UIKit)
        return Color(.label)
        #else
        return Color(red: 0.1, green: 0.1, blue: 0.1)
        #endif
    }()

    static let textSecondary: Color = {
        #if canImport(UIKit)
        return Color(.secondaryLabel)
        #else
        return Color(red: 0.45, green: 0.45, blue: 0.45)
        #endif
    }()

    static let textTertiary: Color = {
        #if canImport(UIKit)
        return Color(.tertiaryLabel)
        #else
        return Color(red: 0.65, green: 0.65, blue: 0.65)
        #endif
    }()

    // MARK: 状态色

    static let success = Color(red: 0.30, green: 0.78, blue: 0.47)   // 绿
    static let warning = Color(red: 0.95, green: 0.75, blue: 0.25)   // 琥珀黄
    static let danger = Color(red: 0.91, green: 0.36, blue: 0.36)    // 红
    static let info = Color(red: 0.35, green: 0.63, blue: 0.90)      // 蓝

    // MARK: 阶段状态色

    static let stageNotStarted = Color(red: 0.78, green: 0.78, blue: 0.80)   // 灰
    static let stageActive = Color(red: 0.35, green: 0.47, blue: 0.93)       // 蓝紫（同 primaryAccent）
    static let stageCompleted = Color(red: 0.30, green: 0.78, blue: 0.47)    // 绿（同 success）
    static let stageNeedsReview = Color(red: 0.95, green: 0.75, blue: 0.25)  // 黄（同 warning）

    // MARK: 聊天角色色

    static let userBubbleBackground = Color(red: 0.35, green: 0.47, blue: 0.93)    // 蓝紫
    static let assistantBubbleBackground: Color = {
        #if canImport(UIKit)
        return Color(.secondarySystemBackground)
        #else
        return Color(red: 0.93, green: 0.93, blue: 0.95)
        #endif
    }()
    static let reflectionCardBackground = Color(red: 0.96, green: 0.94, blue: 0.99) // 淡紫

    // MARK: 阶段状态 → Color 映射

    /// 根据 StageStatus 返回对应颜色（用于 StageNodeView / ProgressPanel）
    static func stageColor(for status: StageStatus) -> Color {
        switch status {
        case .notStarted:  return .stageNotStarted
        case .active:      return .stageActive
        case .completed:   return .stageCompleted
        case .needsReview: return .stageNeedsReview
        }
    }

    /// 根据 String 状态返回对应颜色（兼容 Model 层直接使用）
    static func stageColor(for status: String) -> Color {
        switch status {
        case "notStarted":  return .stageNotStarted
        case "active":      return .stageActive
        case "completed":   return .stageCompleted
        case "needsReview": return .stageNeedsReview
        default:            return .stageNotStarted
        }
    }
}

// MARK: - AppTheme Token

enum AppTheme {
    // 圆角
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 22

    // 间距
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 12
    static let spacingLarge: CGFloat = 20

    // 阴影
    static let cardShadowRadius: CGFloat = 8
}
