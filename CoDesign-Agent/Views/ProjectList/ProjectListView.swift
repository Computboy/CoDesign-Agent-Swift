import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @State private var viewModel = ProjectListViewModel()
    @State private var isShowingNewProject = false
    @State private var showingSettings = false
    @State private var isImportingCodesign = false
    @State private var previewPackage: CoDesignPackage?
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationStack {
            let filtered = viewModel.filteredProjects(projects)

            CoDesignHomeView(
                searchText: $viewModel.searchText,
                projects: filtered,
                isFiltering: !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                onCreateProject: {
                    isShowingNewProject = true
                },
                onImportPackage: {
                    isImportingCodesign = true
                },
                onShowSettings: {
                    showingSettings = true
                },
                onDeleteProject: deleteProject
            )
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .sheet(isPresented: $isShowingNewProject) {
            NewProjectView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            APISettingsView()
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $previewPackage) { package in
            CoDesignPackagePreviewView(package: package)
                #if os(iOS)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                #endif
        }
        .fileImporter(
            isPresented: $isImportingCodesign,
            allowedContentTypes: [.codesignProject]
        ) { result in
            handleCodesignImport(result)
        }
        .alert(
            "导入失败",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    // MARK: - Deletion

    private func deleteProject(_ project: Project) {
        withAnimation(AppTheme.Animation.standard) {
            modelContext.delete(project)
            try? modelContext.save()
        }
    }

    private func handleCodesignImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                previewPackage = try CoDesignPackageImporter().loadPackage(from: url)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                return
            }
            importErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Project Library

struct ProjectLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    @Binding var searchText: String
    @State private var hasEntered = false
    @State private var isLeaving = false

    let onCreateProject: () -> Void
    let onImportPackage: () -> Void
    let onShowSettings: () -> Void
    let onDeleteProject: (Project) -> Void

    private var filteredProjects: [Project] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return projects.sorted { $0.updatedAt > $1.updatedAt }
        }

        return projects
            .filter {
                $0.name.localizedCaseInsensitiveContains(keyword)
                || $0.briefDescription.localizedCaseInsensitiveContains(keyword)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var contentIsVisible: Bool {
        hasEntered && !isLeaving
    }

    private var libraryCardHeight: CGFloat {
        #if os(macOS)
        176
        #else
        178
        #endif
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            if filteredProjects.isEmpty {
                ProjectEmptyStateView(
                    isSearchEmpty: isFiltering,
                    onCreateProject: onCreateProject
                )
                .opacity(contentIsVisible ? 1 : 0)
                .offset(y: pageOffsetY)
                .scaleEffect(pageScale, anchor: .top)
                .blur(radius: contentIsVisible ? 0 : pageBlurRadius)
            } else {
                projectScrollList(filteredProjects)
                    .opacity(contentIsVisible ? 1 : 0)
                    .offset(y: pageOffsetY)
                    .scaleEffect(pageScale, anchor: .top)
                    .blur(radius: contentIsVisible ? 0 : pageBlurRadius)
            }
        }
        .background(Color.white)
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: contentIsVisible)
        .navigationTitle("项目库")
        .searchable(text: $searchText, prompt: "搜索项目")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: closeLibrary) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isLeaving)
                .accessibilityLabel("返回")
            }
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button(action: onImportPackage) {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("导入 CoDesign 项目包")
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: onShowSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("设置")
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: onCreateProject) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建项目")
            }
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        #endif
        .task {
            isLeaving = false
            hasEntered = false
            await Task.yield()
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84, blendDuration: 0.08)) {
                hasEntered = true
            }
        }
        .onDisappear {
            hasEntered = false
            isLeaving = false
        }
    }

    private func projectScrollList(_ projects: [Project]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            let columns: [GridItem] = {
                #if os(macOS)
                [GridItem(.adaptive(minimum: 320), spacing: AppTheme.spacingMedium)]
                #else
                [GridItem(.adaptive(minimum: 300), spacing: AppTheme.spacingMedium)]
                #endif
            }()

            LazyVGrid(columns: columns, spacing: AppTheme.spacingMedium) {
                ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        ProjectCard(project: project, fixedHeight: libraryCardHeight)
                    }
                    .buttonStyle(ProjectCardNavigationButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteProject(project)
                        } label: {
                            Label("删除项目", systemImage: "trash")
                        }
                    }
                    .transition(
                        .opacity.combined(with: .move(edge: .bottom))
                    )
                    .opacity(contentIsVisible ? 1 : 0)
                    .offset(y: contentIsVisible ? 0 : CGFloat(28 + min(index, 6) * 4))
                    .scaleEffect(contentIsVisible ? 1 : 0.965, anchor: .center)
                    .blur(radius: contentIsVisible ? 0 : 4)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.86)
                            .delay(contentIsVisible ? Double(min(index, 8)) * 0.03 : 0),
                        value: contentIsVisible
                    )
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
            .animation(AppTheme.Animation.standard, value: projects.map(\.id))
        }
        .background(Color.white)
        .coDesignHideScrollIndicators()
    }

    private func deleteProject(_ project: Project) {
        onDeleteProject(project)
    }

    private var pageOffsetY: CGFloat {
        if isLeaving {
            return -10
        }
        return hasEntered ? 0 : 24
    }

    private var pageScale: CGFloat {
        if isLeaving {
            return 0.985
        }
        return hasEntered ? 1 : 0.97
    }

    private var pageBlurRadius: CGFloat {
        isLeaving ? 5 : 8
    }

    private func closeLibrary() {
        guard !isLeaving else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isLeaving = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Project Card Navigation Feedback

private struct ProjectCardNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .brightness(configuration.isPressed ? -0.015 : 0)
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ProjectListView()
        .modelContainer(for: Project.self, inMemory: true)
}
