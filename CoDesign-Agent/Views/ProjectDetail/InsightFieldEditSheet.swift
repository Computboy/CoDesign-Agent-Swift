import SwiftUI
import SwiftData

// MARK: - InsightFieldEditSheet

/// A sheet for editing a single DesignBrief field.
/// Supports String?-based fields directly. For relationship fields (successMetrics, boundaryItems, risks),
/// a text representation is provided and saved as a single text entry.
struct InsightFieldEditSheet: View {
    let field: BriefField
    let brief: DesignBrief

    /// Callback when save is successful (not called on cancel)
    var onSaveSuccess: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var editText: String = ""
    @State private var showEmptyWarning: Bool = false

    private let maxCharacterLimit = 2000

    // MARK: - Display Helpers

    private var fieldDisplayName: String {
        switch field {
        case .targetUser: return "目标用户"
        case .painPoint: return "核心痛点"
        case .useScenario: return "使用场景"
        case .coreValue: return "核心价值"
        case .differentiation: return "差异化"
        case .boundaryItems: return "项目边界"
        case .mvpFeatures: return "MVP 功能"
        case .technicalModules: return "技术模块"
        case .interactionFlow: return "交互流程"
        case .operationLogic: return "运行逻辑"
        case .hardConstraints: return "硬性约束"
        case .successMetrics: return "验收标准"
        case .risks: return "风险预案"
        case .milestones: return "里程碑"
        }
    }

    private var fieldHint: String {
        switch field {
        case .targetUser: return "描述你的目标用户是谁，他们有什么特征"
        case .painPoint: return "描述用户遇到的核心问题或痛点"
        case .useScenario: return "描述用户在什么具体场景下使用"
        case .coreValue: return "描述产品提供的核心价值"
        case .differentiation: return "描述与现有方案的差异"
        case .boundaryItems: return "描述项目边界，每行一项"
        case .mvpFeatures: return "描述 MVP 包含的核心功能"
        case .technicalModules: return "描述技术模块和选型"
        case .interactionFlow: return "描述用户交互流程"
        case .operationLogic: return "描述系统运行逻辑和规则"
        case .hardConstraints: return "描述硬性约束条件"
        case .successMetrics: return "描述验收标准，每行一项指标"
        case .risks: return "描述已识别的风险"
        case .milestones: return "描述项目里程碑和排期"
        }
    }

    // MARK: - Init

    init(field: BriefField, brief: DesignBrief, onSaveSuccess: (() -> Void)? = nil) {
        self.field = field
        self.brief = brief
        self.onSaveSuccess = onSaveSuccess
        let snapshot = brief.toSnapshot()
        switch field {
        case .targetUser: _editText = State(initialValue: snapshot.targetUser ?? "")
        case .painPoint: _editText = State(initialValue: snapshot.painPoint ?? "")
        case .useScenario: _editText = State(initialValue: snapshot.useScenario ?? "")
        case .coreValue: _editText = State(initialValue: snapshot.coreValue ?? "")
        case .differentiation: _editText = State(initialValue: snapshot.differentiation ?? "")
        case .mvpFeatures: _editText = State(initialValue: snapshot.mvpFeatures ?? "")
        case .technicalModules: _editText = State(initialValue: snapshot.technicalModules ?? "")
        case .interactionFlow: _editText = State(initialValue: snapshot.interactionFlow ?? "")
        case .operationLogic: _editText = State(initialValue: snapshot.operationLogic ?? "")
        case .hardConstraints: _editText = State(initialValue: snapshot.hardConstraints ?? "")
        case .milestones: _editText = State(initialValue: snapshot.milestones ?? "")
        case .boundaryItems:
            let items = snapshot.boundaryItems.map { $0.content }.joined(separator: "\n")
            _editText = State(initialValue: items)
        case .successMetrics:
            let items = snapshot.successMetrics.map { "\($0.metric): \($0.target)" }.joined(separator: "\n")
            _editText = State(initialValue: items)
        case .risks:
            let items = snapshot.risks.map { $0.desc }.joined(separator: "\n")
            _editText = State(initialValue: items)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {

                    // Field info
                    CoDesignCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                            Text(fieldDisplayName)
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(Color.textPrimary)

                            Text(field.rawValue)
                                .font(AppTheme.Typography.captionMono)
                                .foregroundStyle(Color.textTertiary)

                            Text(fieldHint)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

                    // Text editor
                    CoDesignCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                            TextEditor(text: $editText)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(Color.textPrimary)
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .coDesignHideScrollIndicators()
                                .onChange(of: editText) { oldValue, newValue in
                                    if newValue.count > maxCharacterLimit {
                                        editText = String(newValue.prefix(maxCharacterLimit))
                                    }
                                }

                            HStack {
                                Spacer()
                                Text("\(editText.count)/\(maxCharacterLimit)")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(
                                        editText.count >= maxCharacterLimit
                                            ? Color.warning
                                            : Color.textTertiary
                                    )
                            }
                        }
                    }

                    // Empty warning
                    if showEmptyWarning {
                        CoDesignCard(style: .highlighted(.warning)) {
                            HStack(spacing: AppTheme.spacingSmall) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.warning)
                                Text("内容不能为空，请输入有效内容后再保存")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(Color.warning)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(AppTheme.spacingMedium)
            }
            .coDesignHideScrollIndicators()
            .background(Color.appBackground)
            .navigationTitle("编辑\(fieldDisplayName)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            withAnimation(AppTheme.Animation.quick) {
                showEmptyWarning = true
            }
            return
        }

        showEmptyWarning = false

        // Write to SwiftData DesignBrief
        switch field {
        case .targetUser: brief.targetUser = trimmed
        case .painPoint: brief.painPoint = trimmed
        case .useScenario: brief.useScenario = trimmed
        case .coreValue: brief.coreValue = trimmed
        case .differentiation: brief.differentiation = trimmed
        case .mvpFeatures: brief.mvpFeatures = trimmed
        case .technicalModules: brief.technicalModules = trimmed
        case .interactionFlow: brief.interactionFlow = trimmed
        case .operationLogic: brief.operationLogic = trimmed
        case .hardConstraints: brief.hardConstraints = trimmed
        case .milestones: brief.milestones = trimmed
        case .boundaryItems:
            // Parse lines into BoundaryItem objects
            let lines = trimmed.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            brief.boundaryItems.forEach { modelContext.delete($0) }
            brief.boundaryItems = lines.map {
                let bi = BoundaryItem(content: $0, isIncluded: true)
                modelContext.insert(bi)
                return bi
            }
        case .successMetrics:
            // Parse lines into SuccessMetric objects
            let lines = trimmed.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            brief.successMetrics.forEach { modelContext.delete($0) }
            brief.successMetrics = lines.map {
                let sm = SuccessMetric(metric: $0, target: "待定义")
                modelContext.insert(sm)
                return sm
            }
        case .risks:
            // Parse lines into RiskItem objects
            let lines = trimmed.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            brief.risks.forEach { modelContext.delete($0) }
            brief.risks = lines.map {
                let ri = RiskItem(desc: $0)
                modelContext.insert(ri)
                return ri
            }
        }

        // Update extraction timestamp
        brief.lastExtractedAt = Date()

        // Save
        try? modelContext.save()

        // Notify parent of successful save before dismissing
        onSaveSuccess?()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    InsightFieldEditSheet(
        field: .targetUser,
        brief: {
            let b = DesignBrief()
            b.targetUser = "大一新生，尤其是来自外地的学生"
            return b
        }()
    )
}
