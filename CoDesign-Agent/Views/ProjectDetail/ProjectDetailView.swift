import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project
    @State private var viewModel = ProjectDetailViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            ProjectDetailHeader(project: project, viewModel: viewModel)
                .padding(AppTheme.spacingMedium)
                .background(Color.cardBackground)

            // MARK: - Tab Picker
            Picker("Tab", selection: $viewModel.selectedTab) {
                ForEach(ProjectDetailTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(AppTheme.spacingMedium)

            // MARK: - Tab Content
            Group {
                switch viewModel.selectedTab {
                case .chat:
                    ChatPlaceholder(project: project, viewModel: viewModel)
                case .progress:
                    ProgressPlaceholder(project: project, viewModel: viewModel)
                case .insights:
                    InsightsPlaceholder(project: project)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.appBackground)
        .navigationTitle(project.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Header

struct ProjectDetailHeader: View {
    let project: Project
    let viewModel: ProjectDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text(project.briefDescription)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            ProgressView(value: project.completionRate)
                .tint(.primaryAccent)

            HStack(spacing: AppTheme.spacingMedium) {
                Label("\(viewModel.completionPercent(for: project))%", systemImage: "chart.bar.fill")
                Label("\(project.messages.count)", systemImage: "bubble.left.fill")
                Label("\(project.stages.count)", systemImage: "list.number")
                Label("\(project.learningTraces.count)", systemImage: "lightbulb.fill")
            }
            .font(.caption)
            .foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - Chat Placeholder

struct ChatPlaceholder: View {
    let project: Project
    let viewModel: ProjectDetailViewModel

    var body: some View {
        VStack(spacing: AppTheme.spacingLarge) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            Text("对话面板")
                .font(.headline)

            Text("Step 19-21 将在这里实现 AI 苏格拉底式对话。")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            Text("当前已有 \(project.messages.count) 条消息。")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)

            // 显示最近 3 条消息
            let recentMessages = Array(viewModel.sortedMessages(for: project).suffix(3))
            if !recentMessages.isEmpty {
                Divider()
                    .padding(.horizontal)

                Text("最近消息")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)

                ForEach(recentMessages) { message in
                    HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                        Text(message.role)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.primaryAccent)
                            .frame(width: 60, alignment: .leading)

                        Text(message.content)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
    }
}

// MARK: - Progress Placeholder

struct ProgressPlaceholder: View {
    let project: Project
    let viewModel: ProjectDetailViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                VStack(spacing: AppTheme.spacingSmall) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.textTertiary)

                    Text("进度面板")
                        .font(.headline)

                    Text("Step 22-23 将在这里实现 9 步进度可视化。")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("当前共有 \(project.stages.count) 个阶段，完成度 \(viewModel.completionPercent(for: project))%。")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Divider()
                    .padding(.horizontal)

                // 列出 9 个阶段
                VStack(spacing: AppTheme.spacingSmall) {
                    ForEach(viewModel.sortedStages(for: project)) { stage in
                        HStack {
                            Text("\(stage.order).")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.primaryAccent)
                                .frame(width: 24, alignment: .leading)

                            Text(stage.name)
                                .font(.caption)
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Text(stage.status)
                                .font(.caption2)
                                .foregroundStyle(Color.stageColor(for: stage.status))

                            Text("\(Int(stage.completionRatio * 100))%")
                                .font(.caption2)
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Insights Placeholder

struct InsightsPlaceholder: View {
    let project: Project

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                VStack(spacing: AppTheme.spacingSmall) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.textTertiary)

                    Text("洞察面板")
                        .font(.headline)

                    Text("Step 24-25 将在这里实现 DesignBrief 摘要和学习轨迹时间线。")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("当前已有 \(project.learningTraces.count) 条学习轨迹。")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Divider()
                    .padding(.horizontal)

                // DesignBrief 摘要
                if let brief = project.brief {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Text("DesignBrief 摘要")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.textSecondary)

                        BriefFieldRow(label: "目标用户", value: brief.targetUser)
                        BriefFieldRow(label: "核心痛点", value: brief.painPoint)
                        BriefFieldRow(label: "使用场景", value: brief.useScenario)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}

// MARK: - BriefFieldRow Helper

struct BriefFieldRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            Text(label + ":")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryAccent)
                .frame(width: 70, alignment: .leading)

            if let value, !value.isEmpty {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(Color.textPrimary)
            } else {
                Text("尚未填写")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .italic()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProjectDetailView(project: Project(
            name: "测试项目",
            briefDescription: "这是一个测试项目的详细描述"
        ))
    }
}
