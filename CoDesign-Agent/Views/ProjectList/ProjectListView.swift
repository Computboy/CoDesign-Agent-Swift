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

            if filteredProjects.isEmpty {
                ProjectEmptyStateView(
                    isSearchEmpty: isFiltering,
                    onCreateProject: onCreateProject
                )
                .transition(.opacity)
            } else {
                projectScrollList(filteredProjects)
                    .transition(.opacity)
            }
        }
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
                ForEach(projects) { project in
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
