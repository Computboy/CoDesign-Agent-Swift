import SwiftUI

// MARK: - CoDesignButton

/// A unified button component supporting three visual styles (primary, secondary, ghost),
/// loading state, disabled state, and optional leading icon.
///
/// Usage:
/// ```swift
/// CoDesignButton("Start Clarification", style: .primary) { ... }
/// CoDesignButton("Give Me an Example", style: .secondary, icon: "lightbulb") { ... }
/// CoDesignButton("Skip", style: .ghost) { ... }
/// CoDesignButton("Sending", style: .primary, isLoading: true) { ... }
/// ```
struct CoDesignButton: View {

    enum Style {
        case primary
        case secondary
        case ghost
    }

    let title: String
    let style: Style
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        style: Style = .primary,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    private var effectiveDisabled: Bool {
        isDisabled || isLoading
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingSmall) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(progressTint)
                        .controlSize(.small)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }

                Text(title)
                    .font(AppTheme.Typography.subheadline.weight(.semibold))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .frame(height: AppTheme.Layout.buttonHeight)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .overlay(overlayView)
        }
        .disabled(effectiveDisabled)
        .opacity(effectiveDisabled ? 0.5 : 1.0)
        .animation(AppTheme.Animation.quick, value: effectiveDisabled)
    }

    // MARK: - Styling helpers

    private var foregroundColor: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return .primaryAccent
        case .ghost:     return .textSecondary
        }
    }

    private var progressTint: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return .primaryAccent
        case .ghost:     return .textSecondary
        }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .primary:   return 20
        case .secondary: return 16
        case .ghost:     return 12
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Color.primaryAccent
        case .secondary:
            Color.primaryAccent.opacity(0.1)
        case .ghost:
            Color.clear
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        switch style {
        case .primary, .ghost:
            EmptyView()
        case .secondary:
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.3), lineWidth: AppTheme.Border.thin)
        }
    }
}

// MARK: - Small Variant

/// A compact button variant for inline use (e.g., chips, toolbar actions).
struct CoDesignSmallButton: View {
    let title: String
    let icon: String?
    let isFilled: Bool
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isFilled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isFilled = isFilled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingXS) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(AppTheme.Typography.caption.weight(.medium))
            }
            .foregroundStyle(isFilled ? Color.white : Color.primaryAccent)
            .padding(.horizontal, 10)
            .frame(height: AppTheme.Layout.buttonHeightSmall)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .fill(isFilled ? Color.primaryAccent : Color.primaryAccent.opacity(0.1))
            )
        }
    }
}

// MARK: - Preview

#Preview("CoDesignButton") {
    VStack(spacing: AppTheme.spacingLarge) {
        // Primary
        CoDesignButton("Start Clarification", style: .primary) { }
        CoDesignButton("Send Answer", style: .primary, icon: "paperplane.fill") { }
        CoDesignButton("Sending...", style: .primary, isLoading: true) { }
        CoDesignButton("Disabled", style: .primary, isDisabled: true) { }

        Divider()

        // Secondary
        CoDesignButton("Give Me an Example", style: .secondary, icon: "lightbulb") { }
        CoDesignButton("Try Another Angle", style: .secondary, icon: "arrow.triangle.2.circlepath") { }
        CoDesignButton("Disabled", style: .secondary, isDisabled: true) { }

        Divider()

        // Ghost
        CoDesignButton("Skip", style: .ghost) { }
        CoDesignButton("I'm Not Sure", style: .ghost, icon: "questionmark.circle") { }
        CoDesignButton("Disabled", style: .ghost, isDisabled: true) { }

        Divider()

        // Small variants
        HStack(spacing: AppTheme.spacingSmall) {
            CoDesignSmallButton("Confirm", icon: "checkmark") { }
            CoDesignSmallButton("Edit", icon: "pencil") { }
            CoDesignSmallButton("MVP In", isFilled: true) { }
            CoDesignSmallButton("MVP Out") { }
        }
    }
    .padding()
    .background(Color.appBackground)
}
