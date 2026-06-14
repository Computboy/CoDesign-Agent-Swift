import SwiftUI

// MARK: - CoDesign Theme Tokens (extends existing AppTheme)
//
// This file extends the existing AppTheme enum defined in Color+Theme.swift.
// It adds typography, additional spacing, shadow, and animation tokens
// needed for the v0.3 Design System. No existing values are changed.

extension AppTheme {

    // MARK: - Typography

    enum Typography {
        static let largeTitle  = Font.system(size: 36, weight: .bold, design: .rounded)
        static let title       = Font.system(size: 24, weight: .bold, design: .rounded)
        static let headline    = Font.system(size: 18, weight: .semibold, design: .default)
        static let subheadline = Font.system(size: 16, weight: .regular, design: .default)
        static let body        = Font.system(size: 17.5, weight: .regular, design: .default)
        static let callout     = Font.system(size: 16.5, weight: .regular, design: .default)
        static let caption     = Font.system(size: 13.5, weight: .regular, design: .default)
        static let captionMono = Font.system(size: 13, weight: .medium, design: .monospaced)

        // Micro / Tiny — metadata, timestamps, field labels, compact UI
        static let micro          = Font.system(size: 11, weight: .regular)
        static let microSemibold  = Font.system(size: 11, weight: .semibold)
        static let tiny           = Font.system(size: 12, weight: .regular)
        static let tinySemibold   = Font.system(size: 12, weight: .semibold)
    }

    // MARK: - Extended Spacing
    // Scale: 2 / 4 / 6 / 8 / 12 / 20 / 32 / 48

    static let spacingXXS: CGFloat = 2
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 6
    // spacingSmall (8), spacingMedium (12), spacingLarge (20) already defined in Color+Theme
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48

    // MARK: - Shadows (3 distinct levels)

    enum Shadow {
        /// Subtle lift — default card state, barely perceptible.
        static let cardRadius: CGFloat = 4
        static let cardY: CGFloat = 1
        static let cardOpacity: Double = 0.03

        /// Medium lift — elevated content, clear but restrained.
        static let elevatedRadius: CGFloat = 8
        static let elevatedY: CGFloat = 3
        static let elevatedOpacity: Double = 0.06

        /// Strong lift — focused / selected / active state.
        static let focusRadius: CGFloat = 12
        static let focusY: CGFloat = 4
        static let focusOpacity: Double = 0.08
    }

    // MARK: - Opacity Tokens

    enum Opacity {
        static let hairline: Double = 0.04      // borders, subtle separators
        static let subtle: Double = 0.06        // card background tints
        static let light: Double = 0.08         // badge / chip backgrounds
        static let medium: Double = 0.12        // icon backgrounds, hover states
        static let noticeable: Double = 0.18    // active borders, selection states
        static let soft: Double = 0.35          // disabled states
        static let muted: Double = 0.55         // archived items
        static let strong: Double = 0.82        // completed-state text
        static let nearFull: Double = 0.92      // near-opaque overlays
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
        static let buttonHeight: CGFloat = 46
        static let buttonHeightSmall: CGFloat = 34
        static let stagePillHeight: CGFloat = 28
        static let badgeHeight: CGFloat = 24

        // Dense content padding (insight cards, rail rows, editables)
        static let compactPadding: CGFloat = 10

        // Icon sizes
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 24
    }

    // MARK: - Border

    enum Border {
        static let thin: CGFloat = 1
        static let medium: CGFloat = 1.5
        static let thick: CGFloat = 2
        static let color: Color = {
            #if canImport(UIKit)
            return Color(.separator).opacity(0.5)
            #else
            return Color.black.opacity(0.08)
            #endif
        }()
    }
}

// MARK: - View Modifier: Card Shadow

struct CoDesignCardShadow: ViewModifier {
    enum Level { case none, card, elevated, focus }

    let level: Level

    @ViewBuilder
    func body(content: Content) -> some View {
        switch level {
        case .none:
            content
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
                Text("Tiny Semibold — field label").font(AppTheme.Typography.tinySemibold)
                Text("Tiny — helper text").font(AppTheme.Typography.tiny)
                Text("Micro Semibold — badge").font(AppTheme.Typography.microSemibold)
                Text("Micro — timestamp").font(AppTheme.Typography.micro)
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
    VStack(spacing: AppTheme.spacingXS) {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
            .fill(color)
            .frame(width: 44, height: 44)
        Text(name).font(AppTheme.Typography.micro)
    }
}
