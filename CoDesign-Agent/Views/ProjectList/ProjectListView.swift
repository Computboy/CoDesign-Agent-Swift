import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @State private var viewModel = ProjectListViewModel()
    @State private var isShowingNewProject = false
    @State private var showingSettings = false

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
    }

    // MARK: - Deletion

    private func deleteProject(_ project: Project) {
        withAnimation(AppTheme.Animation.standard) {
            modelContext.delete(project)
            try? modelContext.save()
        }
    }
}

// MARK: - Project Library

struct ProjectLibraryView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    @Binding var searchText: String
    @State private var hasEntered = false

    let onCreateProject: () -> Void
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

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ProjectLibraryBackdrop()
                .opacity(hasEntered ? 1 : 0)
                .animation(.easeOut(duration: 0.45), value: hasEntered)

            if filteredProjects.isEmpty {
                ProjectEmptyStateView(
                    isSearchEmpty: isFiltering,
                    onCreateProject: onCreateProject
                )
                .opacity(hasEntered ? 1 : 0)
                .offset(y: hasEntered ? 0 : 18)
                .scaleEffect(hasEntered ? 1 : 0.985, anchor: .top)
            } else {
                projectScrollList(filteredProjects)
                    .opacity(hasEntered ? 1 : 0)
                    .offset(y: hasEntered ? 0 : 18)
                    .scaleEffect(hasEntered ? 1 : 0.985, anchor: .top)
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: hasEntered)
        .navigationTitle("项目库")
        .searchable(text: $searchText, prompt: "搜索项目")
        .toolbar {
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
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        #endif
        .task {
            hasEntered = false
            await Task.yield()
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                hasEntered = true
            }
        }
        .onDisappear {
            hasEntered = false
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
                        ProjectCard(project: project)
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
                    .opacity(hasEntered ? 1 : 0)
                    .offset(y: hasEntered ? 0 : CGFloat(20 + min(index, 6) * 4))
                    .scaleEffect(hasEntered ? 1 : 0.985, anchor: .top)
                    .animation(
                        .spring(response: 0.48, dampingFraction: 0.86)
                            .delay(Double(min(index, 8)) * 0.028),
                        value: hasEntered
                    )
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
            .animation(AppTheme.Animation.standard, value: projects.map(\.id))
        }
        .coDesignHideScrollIndicators()
    }

    private func deleteProject(_ project: Project) {
        onDeleteProject(project)
    }
}

private struct ProjectLibraryBackdrop: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.primaryAccent.opacity(0.10),
                    Color.secondaryAccent.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)

            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
