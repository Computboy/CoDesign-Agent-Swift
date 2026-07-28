import SwiftUI

// MARK: - CoDesignCard

struct CoDesignCardBackgroundLayer {
    let name: String
    let opacity: Double
    let alignment: Alignment
    let scale: CGFloat
}

/// A reusable card container with unified styling (corner radius, background, shadow, padding).
/// Supports multiple emphasis levels: normal, elevated, highlighted, bordered.
///
/// Usage:
/// ```swift
/// CoDesignCard {
///     VStack(alignment: .leading) {
///         Text("Title")
///         Text("Content")
///     }
/// }
///
/// CoDesignCard(style: .elevated) { ... }
/// CoDesignCard(style: .highlighted(.primaryAccent)) { ... }
/// CoDesignCard(style: .bordered) { ... }
/// ```
struct CoDesignCard<Content: View>: View {

    enum Style {
        /// Default card with subtle shadow on card background
        case normal
        /// Stronger shadow for prominence
        case elevated
        /// Left accent border + tinted background
        case highlighted(Color)
        /// Card background with translucent image layers above the base fill
        case imageBackground([CoDesignCardBackgroundLayer])
        /// Stroke border, no fill, no shadow
        case bordered
        /// No background, no shadow, hairline border — for nested panel content
        case minimal
    }

    let style: Style
    let content: () -> Content

    init(style: Style = .normal, @ViewBuilder content: @escaping () -> Content) {
        self.style = style
        self.content = content
    }

    var body: some View {
        content()
            .padding(AppTheme.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(overlayView)
            .modifier(shadowModifier)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .normal:
            Color.elevatedCardBackground
        case .elevated:
            Color.elevatedCardBackground
        case .highlighted:
            Color.elevatedCardBackground
        case .imageBackground(let layers):
            ZStack(alignment: .top) {
                Color.elevatedCardBackground

                GeometryReader { proxy in
                    ZStack {
                        ForEach(layers.indices, id: \.self) { index in
                            let layer = layers[index]
                            let layerWidth = proxy.size.width * layer.scale
                            let layerHeight = proxy.size.height * layer.scale

                            Image(layer.name)
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: layerWidth,
                                    height: layerHeight,
                                    alignment: layer.alignment
                                )
                                .clipped()
                                .frame(
                                    width: proxy.size.width,
                                    height: proxy.size.height,
                                    alignment: layer.alignment
                                )
                                .opacity(layer.opacity)
                                .accessibilityHidden(true)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        case .bordered:
            Color.clear
        case .minimal:
            Color.clear
        }
    }

    // MARK: - Overlay (border / accent)

    @ViewBuilder
    private var overlayView: some View {
        switch style {
        case .normal, .elevated, .imageBackground:
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        case .highlighted(let accentColor):
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor.opacity(0.9))
                        .frame(width: 4)
                    Spacer()
                }
            }
        case .bordered:
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        case .minimal:
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(AppTheme.Border.color.opacity(0.5), lineWidth: AppTheme.Border.thin)
        }
    }

    // MARK: - Shadow

    private var shadowModifier: CoDesignCardShadow {
        switch style {
        case .normal, .imageBackground:
            return CoDesignCardShadow(level: .card)
        case .elevated:
            return CoDesignCardShadow(level: .elevated)
        case .highlighted:
            return CoDesignCardShadow(level: .card)
        case .bordered, .minimal:
            return CoDesignCardShadow(level: .none)
        }
    }
}

// MARK: - Preview

#Preview("CoDesignCard Styles") {
    ScrollView {
        VStack(spacing: AppTheme.spacingLarge) {

            CoDesignCard {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Normal Card").font(AppTheme.Typography.headline)
                    Text("Default card with card background and subtle shadow.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            CoDesignCard(style: .elevated) {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Elevated Card").font(AppTheme.Typography.headline)
                    Text("Stronger shadow for visually prominent content.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            CoDesignCard(style: .highlighted(.primaryAccent)) {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Highlighted Card").font(AppTheme.Typography.headline)
                    Text("Left accent bar indicates the current active clarification.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            CoDesignCard(style: .highlighted(.success)) {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Completed Stage").font(AppTheme.Typography.headline)
                    Text("Green accent for completed stages or confirmed fields.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            CoDesignCard(style: .highlighted(.warning)) {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Needs Review").font(AppTheme.Typography.headline)
                    Text("Amber accent for stages needing attention.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            CoDesignCard(style: .bordered) {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Bordered Card").font(AppTheme.Typography.headline)
                    Text("Minimal emphasis, good for secondary or locked content.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding()
    }
    .background(Color.appBackground)
}
