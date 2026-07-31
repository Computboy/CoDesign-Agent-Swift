import SwiftUI

// MARK: - WorkspaceGlobalBar

/// Project-scoped navigation for the clarification workspace.
/// All actions route to existing destinations; this view owns presentation only.
struct WorkspaceGlobalBar: View {
    let project: Project
    let selectedTab: ProjectDetailTab
    let onSelectTab: (ProjectDetailTab) -> Void
    let onBack: () -> Void
    let onExportBrief: () -> Void

    private var currentStage: ProgressStage? {
        let sorted = project.stages.sorted { $0.order < $1.order }
        return sorted.first(where: { $0.status == "needsReview" })
            ?? sorted.first(where: { $0.status == "active" })
            ?? sorted.first(where: { $0.status == "notStarted" })
            ?? sorted.last
    }

    private var stageCount: Int {
        max(project.stages.count, StageDefinition.all.count, 1)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularLayout
            compactLayout
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    Color.appBackground.opacity(0.98),
                    Color.panelBackground.opacity(0.96),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primaryAccent.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var regularLayout: some View {
        ZStack {
            HStack(spacing: 18) {
                backButton
                projectIdentity
                    .frame(width: 310, alignment: .leading)

                Spacer(minLength: 24)

                exportButton(compact: false)
            }

            primaryModePicker
        }
    }

    private var compactLayout: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            backButton

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(AppTheme.Typography.subheadline.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                if let currentStage {
                    Text("Stage \(currentStage.order) · \(currentStage.name)")
                        .font(AppTheme.Typography.microSemibold)
                        .foregroundStyle(Color.primaryAccent)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)
            compactNavigationMenu
            exportButton(compact: true)
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.elevatedCardBackground.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.primaryAccent.opacity(0.10), lineWidth: 1)
                )
                .coDesignShadow(.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("返回")
        .accessibilityIdentifier("workspace.back")
    }

    private var projectIdentity: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            HStack(spacing: 10) {
                if let currentStage {
                    Text("Stage \(currentStage.order) · \(currentStage.name)")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.primaryAccent)
                        .lineLimit(1)

                    Text("\(currentStage.order) / \(stageCount) 阶段")
                        .font(AppTheme.Typography.microSemibold)
                        .foregroundStyle(Color.textSecondary)
                }

                ProgressView(value: project.completionRate)
                    .tint(Color.primaryAccent)
                    .frame(width: 58)
            }
        }
    }

    private var primaryModePicker: some View {
        HStack(spacing: 3) {
            modeButton(
                title: "工作台",
                icon: "sparkles",
                tab: .workspace
            )
            modeButton(
                title: "思维树",
                icon: ProjectDetailTab.mindTree.systemImage,
                tab: .mindTree
            )
            modeButton(
                title: "成果看板",
                icon: ProjectDetailTab.visualBoard.systemImage,
                tab: .visualBoard
            )
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.elevatedCardBackground.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.10), lineWidth: 1)
        )
        .coDesignShadow(.card)
    }

    private func modeButton(
        title: String,
        icon: String,
        tab: ProjectDetailTab
    ) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            onSelectTab(tab)
        } label: {
            Label(title, systemImage: icon)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            isSelected
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.33, green: 0.28, blue: 0.96),
                                            Color(red: 0.48, green: 0.36, blue: 0.96),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(Color.clear)
                        )
                )
                .shadow(
                    color: isSelected ? Color.primaryAccent.opacity(0.22) : .clear,
                    radius: 8,
                    x: 0,
                    y: 3
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workspace.mode.\(tab.rawValue)")
    }

    private var compactNavigationMenu: some View {
        Menu {
            compactDestination("工作台", icon: "sparkles", tab: .workspace)
            compactDestination("思维树", icon: ProjectDetailTab.mindTree.systemImage, tab: .mindTree)
            compactDestination("成果看板", icon: ProjectDetailTab.visualBoard.systemImage, tab: .visualBoard)
        } label: {
            Label(
                selectedTab == .workspace ? "工作台" : selectedTab.title,
                systemImage: selectedTab == .workspace ? "sparkles" : selectedTab.systemImage
            )
            .font(AppTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(Color.primaryAccent)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(actionBackground(isSelected: true))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换工作区")
        .accessibilityIdentifier("workspace.compactNavigation")
    }

    private func compactDestination(
        _ title: String,
        icon: String,
        tab: ProjectDetailTab
    ) -> some View {
        Button {
            onSelectTab(tab)
        } label: {
            Label(title, systemImage: icon)
        }
    }

    private func exportButton(compact: Bool) -> some View {
        Button(action: onExportBrief) {
            Label(compact ? "导出" : "导出报告", systemImage: "square.and.arrow.up")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, compact ? 12 : 17)
                .frame(height: 42)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.31, green: 0.29, blue: 0.95),
                                    Color(red: 0.38, green: 0.42, blue: 0.91),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.primaryAccent.opacity(0.20), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workspace.export")
    }

    private func actionBackground(isSelected: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(isSelected ? Color.primaryAccent.opacity(0.12) : Color.elevatedCardBackground.opacity(0.92))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primaryAccent.opacity(0.10), lineWidth: 1)
            )
    }
}

#Preview {
    WorkspaceGlobalBar(
        project: Project(name: "校园导航助手", briefDescription: "帮助新生找到教室"),
        selectedTab: .workspace,
        onSelectTab: { _ in },
        onBack: {},
        onExportBrief: {}
    )
    .background(Color.softAccentBackground)
}
