import SwiftUI

// MARK: - Color Tokens

extension Color {

    // MARK: Surface Hierarchy (3 levels)

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

    /// Adaptive panel surface — light: cool neutral gray, dark: system secondary bg.
    static let panelBackground: Color = {
        #if canImport(UIKit)
        return Color(.secondarySystemBackground)
        #else
        return Color(red: 0.97, green: 0.97, blue: 0.98)
        #endif
    }()

    // MARK: Accent Colors (desaturated for calm, professional feel)

    static let primaryAccent = Color(red: 0.36, green: 0.45, blue: 0.84)   // restrained blue
    static let secondaryAccent = Color(red: 0.52, green: 0.44, blue: 0.76) // muted slate-purple
    static let softAccentBackground = Color(red: 0.95, green: 0.96, blue: 0.99)

    // MARK: Text Colors

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

    // MARK: Status Colors (desaturated — forest green, dark amber, serious red)

    static let success = Color(red: 0.27, green: 0.69, blue: 0.42)   // forest green
    static let warning = Color(red: 0.86, green: 0.68, blue: 0.22)   // dark amber
    static let danger = Color(red: 0.82, green: 0.33, blue: 0.33)    // serious red
    static let info = Color(red: 0.32, green: 0.58, blue: 0.82)      // slate blue

    // MARK: Stage Status Colors

    static let stageNotStarted = Color(red: 0.78, green: 0.78, blue: 0.80)   // muted gray (unique)

    /// Aliases — canonical tokens are the source of truth.
    static let stageActive = Color.primaryAccent
    static let stageCompleted = Color.success
    static let stageNeedsReview = Color.warning

    // MARK: Chat Role Colors

    static let userBubbleBackground = Color.primaryAccent
    static let assistantBubbleBackground: Color = {
        #if canImport(UIKit)
        return Color(.secondarySystemBackground)
        #else
        return Color(red: 0.93, green: 0.93, blue: 0.95)
        #endif
    }()

    /// Neutral surface — purple tint removed for calm interface.
    static let reflectionCardBackground: Color = {
        #if canImport(UIKit)
        return Color(.secondarySystemBackground)
        #else
        return Color(red: 0.97, green: 0.97, blue: 0.97)
        #endif
    }()

    // MARK: Stage Status → Color Mapping

    /// Returns the appropriate color for a given stage status.
    static func stageColor(for status: StageStatus) -> Color {
        switch status {
        case .notStarted:  return .stageNotStarted
        case .active:      return .stageActive
        case .completed:   return .stageCompleted
        case .needsReview: return .stageNeedsReview
        }
    }

    /// String-based status color lookup (for Model layer convenience).
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
    // Corner Radii — tight professional scale: 8 < 12 < 16 < 20
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20

    // Spacing — extended scale: 2/4/6/8/12/20/32/48
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 12
    static let spacingLarge: CGFloat = 20
}
