import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project
    @State private var viewModel = ProjectDetailViewModel()
    @State private var chatViewModel: ChatViewModel?
    @Environment(\.llmService) private var llmService
    @Environment(\.structuredExtractor) private var structuredExtractor

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            ProjectDetailHeader(project: project, viewModel: viewModel)
                .padding(AppTheme.spacingMedium)
                .background(Color.cardBackground)

            // MARK: - Tab Picker
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(ProjectDetailTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(AppTheme.spacingMedium)

            // MARK: - Tab Content
            Group {
                if let chatVM = chatViewModel {
                    switch viewModel.selectedTab {
                    case .workspace:
                        ClarificationWorkspaceView(
                            project: project,
                            chatViewModel: chatVM
                        )
                    case .chat:
                        ChatPanel(
                            project: project,
                            chatViewModel: chatVM
                        )
                    case .progress:
                        ProgressPanel(project: project)
                    case .insights:
                        InsightsPanel(project: project)
                    }
                } else {
                    ProgressView("正在准备工作台...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.appBackground)
        .navigationTitle(project.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // 只在首次加载时初始化一次
            if chatViewModel == nil {
                chatViewModel = ChatViewModel(
                    project: project,
                    llmService: llmService,
                    extractor: structuredExtractor
                )
            }
        }
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

// MARK: - Preview

#Preview {
    NavigationStack {
        ProjectDetailView(project: Project(
            name: "测试项目",
            briefDescription: "这是一个测试项目的详细描述"
        ))
        .environment(\.llmService, MockLLMService())
        .environment(\.structuredExtractor, MockStructuredExtractor())
    }
}
