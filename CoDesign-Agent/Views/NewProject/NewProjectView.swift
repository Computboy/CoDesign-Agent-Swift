import SwiftUI
import SwiftData

// MARK: - NewProjectView (DesignSeedView)

struct NewProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NewProjectViewModel()

    // Design Seed fields
    @State private var designIdea: String = ""
    @State private var selectedProjectType: String = ""
    @State private var knownConstraints: String = ""
    @State private var selectedClarificationPriorities: Set<String> = []

    // Project type options
    private let projectTypes = [
        "设计类课程项目",
        "创新创业项目",
        "交互设计作业",
        "个人 App 想法",
        "其他"
    ]

    // Clarification priority options (mapped from StageDefinition)
    private let clarificationOptions = [
        ("目标用户", "targetUser"),
        ("核心痛点", "painPoint"),
        ("功能边界", "boundary"),
        ("技术可行性", "technical"),
        ("验收标准", "successMetrics"),
        ("风险预案", "risks")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {

                    // Header with guided copy
                    headerSection

                    // Design Seed Card: Main idea
                    designIdeaCard

                    // Optional: Project type
                    projectTypeCard

                    // Optional: Known constraints
                    constraintsCard

                    // Optional: Clarification priorities
                    clarificationPrioritiesCard

                    // Info text
                    infoText

                    // Create button
                    CoDesignButton(
                        "开始澄清",
                        style: .primary,
                        icon: "sparkles",
                        isLoading: false,
                        isDisabled: !canCreate,
                        action: createProject
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppTheme.spacingMedium)

                    Spacer()
                }
                .padding(AppTheme.spacingLarge)
            }
            .background(Color.appBackground)
            .navigationTitle("从一个模糊想法开始")
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

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("不用一次想清楚")
                .font(AppTheme.Typography.title)
                .foregroundStyle(Color.textPrimary)

            Text("先写下你的设计想法，CoDesign Agent 会通过追问帮你逐步澄清目标、用户、边界和方案。")
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Design Idea Card (Required)

    private var designIdeaCard: some View {
        CoDesignCard(style: .bordered) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                CoDesignSectionHeader(title: "我现在的设计想法是")

                TextEditor(text: $designIdea)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textPrimary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if designIdea.isEmpty {
                            Text("例如：我想做一个帮助大学生更好完成设计类课程开题的 AI 工具")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(Color.textTertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }

                // Character count
                HStack {
                    Spacer()
                    Text("\(designIdea.count) 字")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }

    // MARK: - Project Type Card (Optional)

    private var projectTypeCard: some View {
        CoDesignCard(style: .bordered) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                CoDesignSectionHeader(
                    title: "项目类型",
                    subtitle: "可选"
                )

                // Chip selection
                CoDesignFlowLayout(spacing: AppTheme.spacingSmall) {
                    ForEach(projectTypes, id: \.self) { type in
                        ChipButton(
                            title: type,
                            isSelected: selectedProjectType == type,
                            action: {
                                selectedProjectType = (selectedProjectType == type) ? "" : type
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Constraints Card (Optional)

    private var constraintsCard: some View {
        CoDesignCard(style: .bordered) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                CoDesignSectionHeader(
                    title: "已知限制",
                    subtitle: "可选"
                )

                TextEditor(text: $knownConstraints)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textPrimary)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if knownConstraints.isEmpty {
                            Text("例如：两周内完成、只能用 SwiftUI、需要本地存储")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(Color.textTertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    // MARK: - Clarification Priorities Card (Optional)

    private var clarificationPrioritiesCard: some View {
        CoDesignCard(style: .bordered) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                CoDesignSectionHeader(
                    title: "我希望 AI 先帮我澄清",
                    subtitle: "可选，可多选"
                )

                CoDesignFlowLayout(spacing: AppTheme.spacingSmall) {
                    ForEach(clarificationOptions, id: \.1) { option in
                        ChipButton(
                            title: option.0,
                            isSelected: selectedClarificationPriorities.contains(option.1),
                            action: {
                                if selectedClarificationPriorities.contains(option.1) {
                                    selectedClarificationPriorities.remove(option.1)
                                } else {
                                    selectedClarificationPriorities.insert(option.1)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Info Text

    private var infoText: some View {
        Text("写得模糊也没关系。CoDesign Agent 会把你的想法拆成阶段、问题和设计字段，帮助你一步步形成 Design Brief。")
            .font(AppTheme.Typography.caption)
            .foregroundStyle(Color.textTertiary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Computed Properties

    private var canCreate: Bool {
        !designIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func createProject() {
        // Auto-generate project name from design idea (first 20 chars or first sentence)
        let trimmedIdea = designIdea.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectName = generateProjectName(from: trimmedIdea)

        // Compose rich briefDescription
        var descriptionParts: [String] = [trimmedIdea]

        if !selectedProjectType.isEmpty {
            descriptionParts.append("项目类型：\(selectedProjectType)")
        }

        if !knownConstraints.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            descriptionParts.append("已知限制：\(knownConstraints.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if !selectedClarificationPriorities.isEmpty {
            let priorityNames = clarificationOptions
                .filter { selectedClarificationPriorities.contains($0.1) }
                .map { $0.0 }
                .joined(separator: "、")
            descriptionParts.append("优先澄清：\(priorityNames)")
        }

        let richDescription = descriptionParts.joined(separator: "\n")

        // Use existing ViewModel to create project
        viewModel.name = projectName
        viewModel.briefDescription = richDescription

        if viewModel.createProject(context: modelContext) != nil {
            dismiss()
        }
    }

    private func generateProjectName(from idea: String) -> String {
        // Take first sentence or first 20 characters
        if let firstSentenceEnd = idea.firstIndex(of: "。") ?? idea.firstIndex(of: ".") {
            let sentence = String(idea[..<firstSentenceEnd])
            return String(sentence.prefix(30))
        }

        // Take first line if multi-line
        if let firstLineEnd = idea.firstIndex(of: "\n") {
            return String(idea[..<firstLineEnd]).prefix(30).description
        }

        // Fallback: first 30 chars
        return String(idea.prefix(30))
    }
}

// MARK: - ChipButton

private struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.primaryAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.primaryAccent : Color.primaryAccent.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .animation(AppTheme.Animation.quick, value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    NewProjectView()
        .modelContainer(for: Project.self, inMemory: true)
}
