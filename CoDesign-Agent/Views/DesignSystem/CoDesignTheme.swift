import SwiftUI

// MARK: - CoDesign Theme Tokens (extends existing AppTheme)
//
// This file extends the existing AppTheme enum defined in Color+Theme.swift.
// It adds typography, additional spacing, shadow, and animation tokens
// needed for the v0.3 Design System. No existing values are changed.

extension AppTheme {

    // MARK: - Typography

    enum Typography {
        static let largeTitle  = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let title       = Font.system(.title2, design: .rounded).weight(.bold)
        static let headline    = Font.system(.headline, design: .default).weight(.semibold)
        static let subheadline = Font.system(.subheadline, design: .default)
        static let body        = Font.system(.body, design: .default)
        static let callout     = Font.system(.callout, design: .default)
        static let caption     = Font.system(.caption, design: .default)
        static let captionMono = Font.system(.caption, design: .monospaced).weight(.medium)
    }

    // MARK: - Extended Spacing

    static let spacingXS: CGFloat = 4
    // spacingSmall (8), spacingMedium (12), spacingLarge (20) already defined
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48

    // MARK: - Shadows

    enum Shadow {
        /// Light, unified card shadow — subtle lift without heavy depth.
        static let cardRadius: CGFloat = 8
        static let cardY: CGFloat = 2
        static let cardOpacity: Double = 0.04

        static let elevatedRadius: CGFloat = 12
        static let elevatedY: CGFloat = 3
        static let elevatedOpacity: Double = 0.06

        static let focusRadius: CGFloat = 16
        static let focusY: CGFloat = 4
        static let focusOpacity: Double = 0.08
    }

    // MARK: - Animation

    enum Animation {
        static let quick: SwiftUI.Animation = .easeInOut(duration: 0.15)
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let slow: SwiftUI.Animation = .easeInOut(duration: 0.4)
        static let spring: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.75)
    }

    // MARK: - Layout

    enum Layout {
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 20
        static let inlineSpacing: CGFloat = 8
        static let buttonHeight: CGFloat = 44
        static let buttonHeightSmall: CGFloat = 32
        static let stagePillHeight: CGFloat = 28
        static let badgeHeight: CGFloat = 22
    }

    // MARK: - Border

    enum Border {
        static let thin: CGFloat = 1
        static let medium: CGFloat = 1.5
        static let thick: CGFloat = 2
    }
}

// MARK: - View Modifier: Card Shadow

struct CoDesignCardShadow: ViewModifier {
    enum Level { case card, elevated, focus }

    let level: Level

    func body(content: Content) -> some View {
        switch level {
        case .card:
            content.shadow(
                color: Color.black.opacity(AppTheme.Shadow.cardOpacity),
                radius: AppTheme.Shadow.cardRadius,
                x: 0,
                y: AppTheme.Shadow.cardY
            )
        case .elevated:
            content.shadow(
                color: Color.black.opacity(AppTheme.Shadow.elevatedOpacity),
                radius: AppTheme.Shadow.elevatedRadius,
                x: 0,
                y: AppTheme.Shadow.elevatedY
            )
        case .focus:
            content.shadow(
                color: Color.black.opacity(AppTheme.Shadow.focusOpacity),
                radius: AppTheme.Shadow.focusRadius,
                x: 0,
                y: AppTheme.Shadow.focusY
            )
        }
    }
}

extension View {
    func coDesignShadow(_ level: CoDesignCardShadow.Level = .card) -> some View {
        modifier(CoDesignCardShadow(level: level))
    }
}

// MARK: - Preview

#Preview("Theme Tokens") {
    ScrollView {
        VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {

            // Typography
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Typography").font(AppTheme.Typography.caption).foregroundStyle(.secondary)
                Text("Large Title").font(AppTheme.Typography.largeTitle)
                Text("Title").font(AppTheme.Typography.title)
                Text("Headline").font(AppTheme.Typography.headline)
                Text("Subheadline").font(AppTheme.Typography.subheadline)
                Text("Body").font(AppTheme.Typography.body)
                Text("Caption").font(AppTheme.Typography.caption)
                Text("Caption Mono").font(AppTheme.Typography.captionMono)
            }

            Divider()

            // Colors
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Colors").font(AppTheme.Typography.caption).foregroundStyle(.secondary)
                HStack(spacing: AppTheme.spacingSmall) {
                    colorSwatch("Primary", .primaryAccent)
                    colorSwatch("Secondary", .secondaryAccent)
                    colorSwatch("Success", .success)
                    colorSwatch("Warning", .warning)
                    colorSwatch("Danger", .danger)
                    colorSwatch("Info", .info)
                }
            }

            Divider()

            // Shadows
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Shadows").font(AppTheme.Typography.caption).foregroundStyle(.secondary)
                HStack(spacing: AppTheme.spacingMedium) {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(Color.cardBackground)
                        .frame(width: 80, height: 50)
                        .coDesignShadow(.card)
                        .overlay(Text("Card").font(AppTheme.Typography.caption))

                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(Color.cardBackground)
                        .frame(width: 80, height: 50)
                        .coDesignShadow(.elevated)
                        .overlay(Text("Elevated").font(AppTheme.Typography.caption))

                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(Color.cardBackground)
                        .frame(width: 80, height: 50)
                        .coDesignShadow(.focus)
                        .overlay(Text("Focus").font(AppTheme.Typography.caption))
                }
            }
        }
        .padding()
    }
}

private func colorSwatch(_ name: String, _ color: Color) -> some View {
    VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(width: 44, height: 44)
        Text(name).font(.system(size: 9))
    }
}
