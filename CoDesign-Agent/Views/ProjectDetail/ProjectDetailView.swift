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
            WorkspaceGlobalBar(
                project: project,
                selectedTab: Binding(
                    get: { viewModel.selectedTab },
                    set: { viewModel.selectedTab = $0 }
                ),
                onExportBrief: {
                    print("[WorkspaceGlobalBar] Export Brief tapped for project: \(project.name)")
                }
            )

            if viewModel.selectedTab != .workspace {
                HStack(spacing: AppTheme.spacingSmall) {
                    Label(viewModel.selectedTab.title, systemImage: viewModel.selectedTab.systemImage)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    CoDesignSmallButton("回到工作台", icon: "square.grid.2x2") {
                        withAnimation(AppTheme.Animation.standard) {
                            viewModel.selectedTab = .workspace
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacingLarge)
                .padding(.vertical, AppTheme.spacingSmall)
                .background(Color.appBackground)
            }

            // MARK: - Tab Content
            Group {
                if let chatVM = chatViewModel {
                    switch viewModel.selectedTab {
                    case .workspace:
                        ClarificationWorkspaceView(
                            project: project,
                            chatViewModel: chatVM,
                            onReviewBrief: {
                                withAnimation(AppTheme.Animation.standard) {
                                    viewModel.selectedTab = .insights
                                }
                            },
                            onRevisitPreviousStage: {
                                withAnimation(AppTheme.Animation.standard) {
                                    viewModel.selectedTab = .progress
                                }
                            },
                            onExportBrief: {
                                print("[WorkspaceGlobalBar] Export Brief tapped for project: \(project.name)")
                            }
                        )
                    case .visualBoard:
                        VisualBoardView(project: project)
                    case .portfolio:
                        VisualPortfolioView(project: project)
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
