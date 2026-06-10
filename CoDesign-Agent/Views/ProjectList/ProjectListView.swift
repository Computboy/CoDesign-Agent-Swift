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

// MARK: - Preview

#Preview {
    ProjectListView()
        .modelContainer(for: Project.self, inMemory: true)
}
