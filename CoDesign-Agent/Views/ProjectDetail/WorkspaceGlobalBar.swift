import SwiftUI

// MARK: - WorkspaceGlobalBar

/// Project-scoped navigation for the clarification workspace.
/// All actions route to existing destinations; this view owns presentation only.
struct WorkspaceGlobalBar: View {
    let project: Project
    @Binding var selectedTab: ProjectDetailTab
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
                    Color.white.opacity(0.98),
                    Color(red: 0.975, green: 0.976, blue: 1.0).opacity(0.96),
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
        HStack(spacing: 18) {
            backButton
            projectIdentity
                .frame(width: 310, alignment: .leading)

            Spacer(minLength: 8)

            primaryModePicker

            Spacer(minLength: 8)

            trailingActions
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
                        .fill(Color.white.opacity(0.92))
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
                title: "澄清模式",
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
                .fill(Color.white.opacity(0.92))
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
            withAnimation(AppTheme.Animation.standard) {
                selectedTab = tab
            }
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

    private var trailingActions: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(AppTheme.Animation.standard) {
                    selectedTab = .chat
                }
            } label: {
                Label("专注", systemImage: "waveform")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(selectedTab == .chat ? Color.primaryAccent : Color.textPrimary)
                    .padding(.horizontal, 15)
                    .frame(height: 42)
                    .background(actionBackground(isSelected: selectedTab == .chat))
            }
            .buttonStyle(.plain)

            viewModeMenu
            exportButton(compact: false)
        }
    }

    private var viewModeMenu: some View {
        Menu {
            Button {
                selectedTab = .portfolio
            } label: {
                Label("作品档案", systemImage: ProjectDetailTab.portfolio.systemImage)
            }

            Button {
                selectedTab = .insights
            } label: {
                Label("设计洞察", systemImage: ProjectDetailTab.insights.systemImage)
            }

            Button {
                selectedTab = .progress
            } label: {
                Label("阶段进度", systemImage: ProjectDetailTab.progress.systemImage)
            }

            Divider()

            Button(action: onExportBrief) {
                Label("导出报告", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 42, height: 42)
                .background(actionBackground(isSelected: false))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更多")
    }

    private var compactNavigationMenu: some View {
        Menu {
            compactDestination("澄清模式", icon: "sparkles", tab: .workspace)
            compactDestination("思维树", icon: ProjectDetailTab.mindTree.systemImage, tab: .mindTree)
            compactDestination("成果看板", icon: ProjectDetailTab.visualBoard.systemImage, tab: .visualBoard)
            compactDestination("专注", icon: "waveform", tab: .chat)

            Divider()

            compactDestination("作品档案", icon: ProjectDetailTab.portfolio.systemImage, tab: .portfolio)
            compactDestination("设计洞察", icon: ProjectDetailTab.insights.systemImage, tab: .insights)
            compactDestination("阶段进度", icon: ProjectDetailTab.progress.systemImage, tab: .progress)
        } label: {
            Label(
                selectedTab == .workspace ? "澄清" : selectedTab.title,
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
            selectedTab = tab
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
            .fill(isSelected ? Color.primaryAccent.opacity(0.12) : Color.white.opacity(0.92))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primaryAccent.opacity(0.10), lineWidth: 1)
            )
    }
}

#Preview {
    WorkspaceGlobalBar(
        project: Project(name: "校园导航助手", briefDescription: "帮助新生找到教室"),
        selectedTab: .constant(.workspace),
        onBack: {},
        onExportBrief: {}
    )
    .background(Color.softAccentBackground)
}
