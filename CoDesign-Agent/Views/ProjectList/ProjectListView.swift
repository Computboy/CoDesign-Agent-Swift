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
            Group {
                let filtered = viewModel.filteredProjects(projects)

                if filtered.isEmpty {
                    emptyStateView
                } else {
                    projectList(filtered)
                }
            }
            .navigationTitle("Clarify")
            .searchable(text: $viewModel.searchText, prompt: "搜索项目")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                #endif

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

    // MARK: - Project List

    private func projectList(_ filtered: [Project]) -> some View {
        List {
            ForEach(filtered) { project in
                NavigationLink {
                    ProjectDetailView(project: project)
                } label: {
                    ProjectCard(project: project)
                }
            }
            .onDelete { offsets in
                viewModel.deleteProjects(
                    at: offsets,
                    from: projects,
                    context: modelContext
                )
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            if viewModel.searchText.isEmpty {
                Text("还没有项目")
                    .font(.headline)
                    .foregroundStyle(Color.textSecondary)
                Text("点击右上角 + 创建你的第一个项目")
                    .font(.subheadline)
                    .foregroundStyle(Color.textTertiary)
            } else {
                Text("没有找到匹配的项目")
                    .font(.headline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            // 项目名称
            Text(project.name)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            // 简短描述
            if !project.briefDescription.isEmpty {
                Text(project.briefDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }

            // 进度条
            ProgressView(value: project.completionRate)
                .tint(.primaryAccent)
                .padding(.vertical, 2)

            // 底部信息栏
            HStack(spacing: AppTheme.spacingMedium) {
                Label("\(Int(project.completionRate * 100))%", systemImage: "chart.bar.fill")
                Label("\(project.messages.count)", systemImage: "bubble.left.fill")
                Label("\(project.learningTraces.count)", systemImage: "lightbulb.fill")
                Spacer()
                Text(project.updatedAt, style: .date)
            }
            .font(.caption)
            .foregroundStyle(Color.textTertiary)
        }
        .padding(AppTheme.spacingMedium)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    ProjectListView()
        .modelContainer(for: Project.self, inMemory: true)
}
