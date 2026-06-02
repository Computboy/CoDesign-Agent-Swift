import SwiftUI

// MARK: - WorkspaceGlobalBar

/// A thin control strip below the system navigation bar.
/// Does NOT repeat the project title or brand name — those live in the
/// navigation bar.  Only exposes workspace controls: autonomy, context loop,
/// export, and the view-mode menu.
struct WorkspaceGlobalBar: View {
    let project: Project
    @Binding var selectedTab: ProjectDetailTab
    let onExportBrief: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularLayout
            compactLayout
        }
        .padding(.horizontal, AppTheme.spacingLarge)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    // MARK: - Regular (enough room for all controls)

    private var regularLayout: some View {
        HStack(spacing: AppTheme.spacingMedium) {

            Spacer()

            autonomyControl
            contextLoopBadge
            visualBoardButton
            portfolioButton
            exportButton
            viewModeMenu
        }
    }

    // MARK: - Compact (tiny screen)

    private var compactLayout: some View {
        HStack(spacing: AppTheme.spacingSmall) {

            Spacer()

            contextLoopBadge
            visualBoardButton
            portfolioButton
            viewModeMenu
        }
    }

    // MARK: - Autonomy

    private var autonomyControl: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Text("AI 引导")
            VStack(spacing: 2) {
                autonomyTrack
                Text("平衡")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primaryAccent)
            }
            Text("用户主导")
        }
        .font(AppTheme.Typography.caption)
        .foregroundStyle(Color.textTertiary)
        .padding(.horizontal, AppTheme.spacingSmall)
        .frame(height: 32)
        .background(
            Capsule(style: .continuous)
                .fill(Color.elevatedCardBackground.opacity(0.78))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
        .accessibilityLabel("Shared Autonomy Balanced")
    }

    private var autonomyTrack: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.primaryAccent.opacity(0.14))
                .frame(width: 52, height: 6)

            Circle()
                .fill(Color.primaryAccent)
                .frame(width: 12, height: 12)
                .offset(x: 0)
        }
    }

    // MARK: - Context Loop Badge

    private var contextLoopBadge: some View {
        HStack(spacing: AppTheme.spacingXS) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .semibold))
            Text("上下文循环已激活")
                .lineLimit(1)
        }
        .font(AppTheme.Typography.caption.weight(.medium))
        .foregroundStyle(Color.primaryAccent.opacity(0.82))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primaryAccent.opacity(0.06))
        )
    }

    // MARK: - Visual Board

    private var visualBoardButton: some View {
        Button {
            withAnimation(AppTheme.Animation.standard) {
                selectedTab = .visualBoard
            }
        } label: {
            Label("成果看板", systemImage: ProjectDetailTab.visualBoard.systemImage)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(selectedTab == .visualBoard ? Color.white : Color.primaryAccent)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(selectedTab == .visualBoard
                              ? Color.primaryAccent
                              : Color.primaryAccent.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Portfolio

    private var portfolioButton: some View {
        Button {
            withAnimation(AppTheme.Animation.standard) {
                selectedTab = .portfolio
            }
        } label: {
            Label("作品档案", systemImage: ProjectDetailTab.portfolio.systemImage)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(selectedTab == .portfolio ? Color.white : Color.primaryAccent)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(selectedTab == .portfolio
                              ? Color.primaryAccent
                              : Color.primaryAccent.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export

    private var exportButton: some View {
        Button {
            onExportBrief()
        } label: {
            Label("导出简报", systemImage: "square.and.arrow.up")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primaryAccent)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - View Mode Menu

    private var viewModeMenu: some View {
        Menu {
            Picker("视图模式", selection: $selectedTab) {
                ForEach(ProjectDetailTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }

            Divider()

            Button {
                selectedTab = .workspace
            } label: {
                Label("回到工作台", systemImage: "square.grid.2x2")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.elevatedCardBackground)
                )
                .overlay(
                    Circle()
                        .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkspaceGlobalBar(
        project: Project(name: "校园导航助手", briefDescription: "帮助新生找到教室"),
        selectedTab: .constant(.workspace)
    ) {
        print("Export")
    }
    .background(Color.appBackground)
}
