import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProjectDetailView: View {
    let project: Project
    var isPresentationMode: Bool = false

    @State private var viewModel = ProjectDetailViewModel()
    @State private var chatViewModel: ChatViewModel?
    @State private var isShowingExportSheet = false
    @State private var isExportingReport = false
    @State private var reportDocument = GeneratedReportDocument()
    @State private var exportContentType: UTType = .markdownReport
    @State private var exportDefaultFilename = "CoDesign报告.md"
    @State private var exportStatusMessage: ProjectExportStatusMessage?
    #if DEBUG
    @State private var didRunPresentationScript = false
    @State private var presentationScriptTask: Task<Void, Never>?
    #endif
    @AppStorage("serviceMode") private var serviceModeRaw: String = "mock"
    @Environment(\.modelContext) private var modelContext
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
                    isShowingExportSheet = true
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
                .padding(.horizontal, AppTheme.spacingMedium)
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
                            resourcePanelStartsExpanded: isPresentationMode,
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
                                isShowingExportSheet = true
                            }
                        )
                    case .mindTree:
                        ThinkingTreeView(project: project, chatViewModel: chatVM)
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
        .sheet(isPresented: $isShowingExportSheet) {
            ReportExportSheet(project: project, onPreparedExport: presentExport)
                #if os(iOS)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                #endif
        }
        .fileExporter(
            isPresented: $isExportingReport,
            document: reportDocument,
            contentType: exportContentType,
            defaultFilename: exportDefaultFilename,
            onCompletion: handleExportResult
        )
        .alert(item: $exportStatusMessage) { message in
            Alert(
                title: Text(message.isError ? "导出失败" : "导出完成"),
                message: Text(message.text),
                dismissButton: .default(Text("好"))
            )
        }
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
            chatViewModel?.refreshStageProgress()
        }
        #if DEBUG
        .task(id: presentationTaskID) {
            startPresentationScriptIfNeeded()
        }
        #endif
        .onChange(of: serviceModeRaw) { _, _ in
            chatViewModel?.updateServices(
                llmService: llmService,
                extractor: structuredExtractor
            )
        }
    }

    private func presentExport(_ preparedExport: PreparedReportExport) {
        isShowingExportSheet = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)

            #if os(iOS)
            do {
                switch preparedExport {
                case .file(let data, _, let defaultFilename):
                    let exportFile = try TemporaryExportFile(
                        data: data,
                        defaultFilename: defaultFilename
                    )
                    DocumentExportPresenter.present(fileURL: exportFile.url) { result in
                        handleDocumentPickerResult(result, temporaryURL: exportFile.url)
                    }
                }
            } catch {
                exportStatusMessage = ProjectExportStatusMessage(
                    text: error.localizedDescription,
                    isError: true
                )
            }
            #else
            switch preparedExport {
            case .file(let data, let contentType, let defaultFilename):
                reportDocument = GeneratedReportDocument(data: data)
                exportContentType = contentType
                exportDefaultFilename = defaultFilename
                isExportingReport = true
            }
            #endif
        }
    }

    #if os(iOS)
    private func handleDocumentPickerResult(_ result: Result<URL, Error>, temporaryURL: URL) {
        defer {
            try? FileManager.default.removeItem(at: temporaryURL.deletingLastPathComponent())
        }
        handleExportResult(result)
    }
    #endif

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            exportStatusMessage = ProjectExportStatusMessage(text: "文件已生成。", isError: false)
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                return
            }
            exportStatusMessage = ProjectExportStatusMessage(text: error.localizedDescription, isError: true)
        }
    }

    #if DEBUG
    private var presentationTaskID: String {
        "\(isPresentationMode)-\(chatViewModel == nil ? "pending" : "ready")"
    }

    @MainActor
    private func startPresentationScriptIfNeeded() {
        guard isPresentationMode, !didRunPresentationScript, let chatViewModel else { return }
        didRunPresentationScript = true
        presentationScriptTask = Task {
            await runPresentationScript(chatViewModel: chatViewModel)
        }
    }

    @MainActor
    private func runPresentationScript(chatViewModel: ChatViewModel) async {
        await presentationPause(1.2)
        await setPresentationTab(.workspace)

        await presentationPause(1.0)
        await chatViewModel.sendMessage(PresentationScript.firstAnswer)

        await presentationPause(1.4)
        await setPresentationTab(.insights)

        await presentationPause(3.2)
        acceptFirstPresentationCandidate()

        await presentationPause(1.8)
        await setPresentationTab(.workspace)

        await presentationPause(0.8)
        await chatViewModel.sendMessage(PresentationScript.boundaryAnswer)

        await presentationPause(1.6)
        await setPresentationTab(.mindTree)

        await presentationPause(5.2)
        await setPresentationTab(.progress)

        await presentationPause(4.0)
        await setPresentationTab(.workspace)

        await presentationPause(0.8)
        await chatViewModel.sendMessage(PresentationScript.finalAnswer)

        await presentationPause(1.6)
        await setPresentationTab(.visualBoard)

        await presentationPause(5.0)
        await setPresentationTab(.portfolio)

        await presentationPause(5.0)
        await setPresentationTab(.insights)
    }

    @MainActor
    private func setPresentationTab(_ tab: ProjectDetailTab) async {
        withAnimation(.spring(response: 0.72, dampingFraction: 0.86, blendDuration: 0.12)) {
            viewModel.selectedTab = tab
        }
    }

    @MainActor
    private func acceptFirstPresentationCandidate() {
        guard let brief = project.brief,
              let pendingLog = brief.pendingExtractionReviewLogs().first
        else {
            return
        }

        withAnimation(AppTheme.Animation.spring) {
            brief.acceptPendingExtraction(pendingLog, context: modelContext)
            chatViewModel?.refreshStageProgress()
            try? modelContext.save()
        }
    }

    private func presentationPause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
    #endif
}

private struct ProjectExportStatusMessage: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

#if DEBUG
private enum PresentationScript {
    static let firstAnswer = """
    目标用户是 18 到 24 岁大学生。他们平时刷短视频，但传统文化内容经常像课堂讲稿，太说教、离生活远，看完也记不住。真实场景是课程展示或校园文化活动前，学生需要快速把一个文化主题做成能打动同学的短视频创意。
    """

    static let boundaryAnswer = """
    第一版必须保留主题输入、受众画像、情绪目标、脚本生成、分镜草稿和文化依据卡片。暂时不做真实视频渲染、复杂剪辑，也不做社交平台自动发布。AI 只生成草稿，关键解释和最终采用都要由用户确认。
    """

    static let finalAnswer = """
    我们用三周完成课堂可演示原型。成功指标是脚本可用率达到 80%，文化事实错误率不超过 5%，从输入主题到导出简报不超过 10 分钟。最大风险是 AI 事实不准和内容仍然太像讲稿，所以需要依据卡片、人工确认和不自动发布的预案。
    """
}
#endif

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
