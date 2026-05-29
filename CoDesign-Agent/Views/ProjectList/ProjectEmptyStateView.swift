import SwiftUI

// MARK: - ProjectEmptyStateView

/// A guided empty state for ProjectListView.
/// Shows a welcoming card when no projects exist, or a simple message when search yields no results.
struct ProjectEmptyStateView: View {

    /// Whether the empty state is due to a search filter (vs genuinely no projects)
    let isSearchEmpty: Bool

    /// Called when the user taps the "create first project" button
    let onCreateProject: () -> Void

    var body: some View {
        if isSearchEmpty {
            searchEmptyState
        } else {
            welcomeEmptyState
        }
    }

    // MARK: - Welcome (no projects)

    private var welcomeEmptyState: some View {
        VStack(spacing: AppTheme.spacingLarge) {
            Spacer()

            CoDesignCard(style: .elevated) {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {

                    // Icon
                    HStack {
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.primaryAccent.opacity(0.7))
                        Spacer()
                    }

                    // Title
                    Text("从一个模糊想法开始")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Description
                    Text("不需要一次想清楚。先写下你的设计想法，CoDesign Agent 会通过追问帮你逐步澄清目标、边界和方案。")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // CTA button
                    CoDesignButton(
                        "创建第一个项目",
                        style: .primary,
                        icon: "plus.circle.fill",
                        action: onCreateProject
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, AppTheme.spacingLarge)

            Spacer()
        }
    }

    // MARK: - Search no results

    private var searchEmptyState: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.textTertiary)

            Text("没有找到匹配的项目")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(Color.textSecondary)

            Text("试试其他关键词，或创建一个新项目")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textTertiary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Welcome Empty State") {
    ProjectEmptyStateView(isSearchEmpty: false) { }
        .background(Color.appBackground)
}

#Preview("Search No Results") {
    ProjectEmptyStateView(isSearchEmpty: true) { }
        .background(Color.appBackground)
}
