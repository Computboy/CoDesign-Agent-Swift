import SwiftUI

// MARK: - CoDesignSectionHeader

/// A section header with title, optional subtitle, and optional trailing action.
/// Used for organizing InsightsPanel, Workspace sections, and ProjectList groups.
///
/// Usage:
/// ```swift
/// CoDesignSectionHeader(title: "Design Brief")
/// CoDesignSectionHeader(title: "MVP Boundary", subtitle: "3 features confirmed")
/// CoDesignSectionHeader(title: "Risk Matrix", subtitle: "2 identified") {
///     Button("See All") { ... }
/// }
/// ```
struct CoDesignSectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing?

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(Color.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            if let trailing {
                trailing
            }
        }
    }
}

// Convenience initializer when no trailing view is needed
extension CoDesignSectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }
}

// MARK: - Preview

#Preview("CoDesignSectionHeader") {
    VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
        CoDesignSectionHeader(title: "Design Brief")

        CoDesignSectionHeader(
            title: "MVP Boundary",
            subtitle: "3 features confirmed, 2 excluded"
        )

        CoDesignSectionHeader(title: "Risk Matrix", subtitle: "2 risks identified") {
            Button("See All") { }
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundStyle(Color.primaryAccent)
        }

        CoDesignSectionHeader(title: "Success Metrics") {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.primaryAccent)
        }

        Divider()

        // In context: section header + cards
        CoDesignSectionHeader(title: "Learning Trace", subtitle: "3 insights captured")

        CoDesignCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Reframe: Problem Redefined")
                    .font(AppTheme.Typography.subheadline.weight(.semibold))
                Text("You shifted from 'can't find classrooms' to 'spatial cognitive overload'")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
    .padding()
    .background(Color.appBackground)
}
