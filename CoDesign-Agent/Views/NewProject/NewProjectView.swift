import SwiftUI
import SwiftData

struct NewProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NewProjectViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    // 项目名称
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Text("项目名称")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .bold()

                        TextField("例如：智能校园导航助手", text: $viewModel.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 简短描述
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Text("简短描述")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .bold()

                        TextField("用一句话描述你的项目", text: $viewModel.briefDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }

                    // 错误提示
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.danger)
                            .padding(.top, AppTheme.spacingSmall)
                    }

                    // 创建按钮
                    Button {
                        if viewModel.createProject(context: modelContext) != nil {
                            dismiss()
                        }
                    } label: {
                        Text("创建项目")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                viewModel.canCreate
                                    ? Color.primaryAccent
                                    : Color.primaryAccent.opacity(0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                    }
                    .disabled(!viewModel.canCreate)
                    .padding(.top, AppTheme.spacingMedium)

                    Spacer()
                }
                .padding(AppTheme.spacingLarge)
            }
            .background(Color.appBackground)
            .navigationTitle("新建项目")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NewProjectView()
        .modelContainer(for: Project.self, inMemory: true)
}
