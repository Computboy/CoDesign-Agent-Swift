import SwiftData
import SwiftUI

struct CoDesignPackagePreviewView: View {
    let package: CoDesignPackage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPanel: PreviewPanel = .mindTree
    @State private var showArchivedBranches = true
    @State private var statusMessage: PreviewStatusMessage?
    @State private var didImport = false

    private var supportsImport: Bool {
        CoDesignPackageImporter.supportedSchemaVersions.contains(package.schemaVersion)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                Picker("预览面板", selection: $selectedPanel) {
                    ForEach(PreviewPanel.allCases) { panel in
                        Label(panel.title, systemImage: panel.icon).tag(panel)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.vertical, AppTheme.spacingSmall)

                content
            }
            .background(Color.appBackground)
            .navigationTitle("CoDesign 项目包")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(didImport ? "已导入" : "导入为新项目") {
                        importPackage()
                    }
                    .disabled(didImport || !supportsImport)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.primaryAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.primaryAccent.opacity(AppTheme.Opacity.light)))

                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    HStack(spacing: AppTheme.spacingXS) {
                        Text(package.project.name)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("只读")
                            .font(AppTheme.Typography.microSemibold)
                            .foregroundStyle(Color.warning)
                            .padding(.horizontal, 7)
                            .frame(height: 20)
                            .background(Capsule().fill(Color.warning.opacity(AppTheme.Opacity.light)))
                    }

                    Text("导出时间：\(package.exportedAt.formatted(date: .abbreviated, time: .shortened)) · schema \(package.schemaVersion)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer(minLength: 0)
            }

            if !supportsImport {
                Label(
                    "此 CoDesign 项目包版本暂不支持导入，但可以尝试只读预览。",
                    systemImage: "exclamationmark.triangle"
                )
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.warning)
            }

            if let statusMessage {
                Label(statusMessage.text, systemImage: statusMessage.isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                    .font(AppTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(statusMessage.isError ? Color.danger : Color.success)
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                switch selectedPanel {
                case .mindTree:
                    Toggle("显示回溯分支", isOn: $showArchivedBranches)
                        .toggleStyle(.switch)
                    SnapshotThinkingTreeView(
                        package: package,
                        showArchivedBranches: $showArchivedBranches
                    )
                case .decisionTrace:
                    decisionTraceView
                case .brief:
                    briefView
                case .resources:
                    resourcesView
                case .summary:
                    reportSummaryView
                }
            }
            .padding(AppTheme.spacingMedium)
        }
        .coDesignHideScrollIndicators()
    }

    private var decisionTraceView: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            ForEach(package.decisionTrace) { item in
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text("Stage \(item.stageOrder) / \(item.stageTitle)")
                        .font(AppTheme.Typography.microSemibold)
                        .foregroundStyle(Color.primaryAccent)
                    Text(item.title)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                    Text(item.content)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppTheme.Layout.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge).fill(Color.cardBackground))
            }
        }
    }

    private var briefView: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            briefRow("目标用户", package.brief.targetUser)
            briefRow("核心痛点", package.brief.painPoint)
            briefRow("使用场景", package.brief.useScenario)
            briefRow("核心价值", package.brief.coreValue)
            briefRow("差异化价值", package.brief.differentiation)
            briefRow("MVP 功能", package.brief.mvpFeatures)
            briefRow("技术模块", package.brief.technicalModules)
            briefRow("交互流程", package.brief.interactionFlow)
            briefRow("运行逻辑", package.brief.operationLogic)
            briefRow("硬性约束", package.brief.hardConstraints)
            briefRow("里程碑", package.brief.milestones)
        }
    }

    private func briefRow(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            Text(title)
                .font(AppTheme.Typography.microSemibold)
                .foregroundStyle(Color.textTertiary)
            Text(ReportSnapshotValue.text(value))
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(AppTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge).fill(Color.cardBackground))
    }

    private var resourcesView: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if package.resources.isEmpty {
                Text("项目包中没有资源线索。")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
            } else {
                ForEach(package.resources) { resource in
                    VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                        Text(resource.title)
                            .font(AppTheme.Typography.caption.weight(.semibold))
                        Text(resource.summary)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                        if let citation = resource.citation {
                            Text(citation)
                                .font(AppTheme.Typography.micro)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    .padding(AppTheme.Layout.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge).fill(Color.cardBackground))
                }
            }
        }
    }

    private var reportSummaryView: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            ForEach(package.reportSections.projectSummary.keys.sorted(), id: \.self) { key in
                briefRow(key, package.reportSections.projectSummary[key])
            }
        }
    }

    private func importPackage() {
        do {
            _ = try CoDesignPackageImporter().importAsNewProject(package: package, context: modelContext)
            didImport = true
            statusMessage = PreviewStatusMessage(
                text: "已导入为新项目。部分资源线索仅在预览包中保留。",
                isError: false
            )
        } catch {
            statusMessage = PreviewStatusMessage(text: error.localizedDescription, isError: true)
        }
    }
}

private enum PreviewPanel: String, CaseIterable, Identifiable {
    case mindTree
    case decisionTrace
    case brief
    case resources
    case summary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mindTree: return "思维树"
        case .decisionTrace: return "路径"
        case .brief: return "Brief"
        case .resources: return "资源"
        case .summary: return "摘要"
        }
    }

    var icon: String {
        switch self {
        case .mindTree: return "tree"
        case .decisionTrace: return "point.3.connected.trianglepath.dotted"
        case .brief: return "rectangle.stack"
        case .resources: return "books.vertical"
        case .summary: return "doc.text"
        }
    }
}

private struct PreviewStatusMessage: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}
