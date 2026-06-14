import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProjectDetailView: View {
    let project: Project

    @State private var viewModel = ProjectDetailViewModel()
    @State private var chatViewModel: ChatViewModel?
    @State private var isShowingExportSheet = false
    @State private var isExportingReport = false
    @State private var reportDocument = GeneratedReportDocument()
    @State private var exportContentType: UTType = .markdownReport
    @State private var exportDefaultFilename = "CoDesign报告.md"
    @State private var exportStatusMessage: ProjectExportStatusMessage?
    @AppStorage("serviceMode") private var serviceModeRaw: String = "mock"
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
}

private struct ProjectExportStatusMessage: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
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
