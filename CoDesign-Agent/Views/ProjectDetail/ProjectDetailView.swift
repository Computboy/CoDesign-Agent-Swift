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
    @State private var shouldBeginMindTreeCreation = false
    @State private var isShowingProjectLibrary = false
    @State private var tabSlideDirection = 1
    @State private var mindTreePresentationState = MindTreePresentationState()
    @AppStorage("serviceMode") private var serviceModeRaw: String = "mock"
    @Environment(\.llmService) private var llmService
    @Environment(\.structuredExtractor) private var structuredExtractor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            WorkspacePageBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                WorkspaceGlobalBar(
                    project: project,
                    selectedTab: viewModel.selectedTab,
                    onSelectTab: selectTab,
                    onBack: {
                        dismiss()
                    },
                    onExportBrief: {
                        isShowingExportSheet = true
                    }
                )

                // MARK: - Tab Content
                ZStack {
                    selectedTabContent
                        .id(viewModel.selectedTab)
                        .transition(tabTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .navigationDestination(isPresented: $isShowingProjectLibrary) {
            ProjectLibraryDestinationView()
        }
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
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task {
            mindTreePresentationState.restorePersistedExpansionIfNeeded(
                from: project.mindTreeAnnotations
            )
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

    @ViewBuilder
    private var selectedTabContent: some View {
        if let chatVM = chatViewModel {
            switch viewModel.selectedTab {
            case .workspace:
                ClarificationWorkspaceView(
                    project: project,
                    chatViewModel: chatVM,
                    mindTreePresentationState: mindTreePresentationState,
                    onReviewBrief: {
                        selectTab(.insights)
                    },
                    onRevisitPreviousStage: {
                        selectTab(.progress)
                    },
                    onExportBrief: {
                        isShowingExportSheet = true
                    },
                    onOpenProjectLibrary: {
                        isShowingProjectLibrary = true
                    },
                    onStartMindTreeCreation: {
                        shouldBeginMindTreeCreation = true
                        selectTab(.mindTree)
                    }
                )
            case .mindTree:
                ThinkingTreeView(
                    project: project,
                    chatViewModel: chatVM,
                    presentationState: mindTreePresentationState,
                    startsInCreationMode: shouldBeginMindTreeCreation,
                    onCreationStarted: {
                        shouldBeginMindTreeCreation = false
                    }
                )
            case .visualBoard:
                VisualBoardView(project: project)
            case .portfolio:
                VisualPortfolioView(project: project)
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

    private var tabTransition: AnyTransition {
        let insertionEdge: Edge = tabSlideDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = tabSlideDirection > 0 ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private func selectTab(_ tab: ProjectDetailTab) {
        guard tab != viewModel.selectedTab else { return }

        tabSlideDirection = tab.navigationOrder > viewModel.selectedTab.navigationOrder ? 1 : -1
        withAnimation(.spring(response: 0.44, dampingFraction: 0.90, blendDuration: 0.08)) {
            viewModel.selectedTab = tab
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

private struct WorkspacePageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color(red: 1.0, green: 0.88, blue: 0.77).opacity(0.22))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 100, y: -180)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.primaryAccent.opacity(0.08))
                .frame(width: 520, height: 520)
                .blur(radius: 120)
                .offset(x: -170, y: 220)
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.075, green: 0.078, blue: 0.12),
                Color(red: 0.055, green: 0.06, blue: 0.10),
                Color(red: 0.095, green: 0.075, blue: 0.13),
            ]
        }

        return [
            Color(red: 0.984, green: 0.986, blue: 1.0),
            Color(red: 0.965, green: 0.968, blue: 0.995),
            Color(red: 0.988, green: 0.982, blue: 1.0),
        ]
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
