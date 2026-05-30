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
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                let filtered = viewModel.filteredProjects(projects)

                if filtered.isEmpty {
                    ProjectEmptyStateView(
                        isSearchEmpty: !viewModel.searchText.isEmpty
                    ) {
                        isShowingNewProject = true
                    }
                    .transition(.opacity)
                } else {
                    projectScrollList(filtered)
                        .transition(.opacity)
                }
            }
            .navigationTitle("CoDesign")
            .searchable(text: $viewModel.searchText, prompt: "搜索项目")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingNewProject) {
            NewProjectView()
        }
        .sheet(isPresented: $showingSettings) {
            APISettingsView()
        }
    }

    // MARK: - Project Scroll List

    private func projectScrollList(_ filtered: [Project]) -> some View {
        ScrollView {
            let columns: [GridItem] = {
                #if os(macOS)
                [GridItem(.adaptive(minimum: 320), spacing: AppTheme.spacingMedium)]
                #else
                [GridItem(.adaptive(minimum: 300), spacing: AppTheme.spacingMedium)]
                #endif
            }()

            LazyVGrid(columns: columns, spacing: AppTheme.spacingMedium) {
                ForEach(filtered) { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        ProjectCard(project: project)
                    }
                    .buttonStyle(.plain)
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
            .animation(AppTheme.Animation.standard, value: filtered.map(\.id))
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

// MARK: - Preview

#Preview {
    ProjectListView()
        .modelContainer(for: Project.self, inMemory: true)
}
