import SwiftUI
import SwiftData

/// Sheet for editing a thinking tree node.
/// Archives the old branch and creates a new active branch from the edited node.
struct NodeEditSheet: View {
    let node: TreeNode
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var editContent: String = ""
    @State private var editDetail: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    nodeInfo
                } header: {
                    Text("编辑节点")
                }

                Section {
                    TextField("节点标题", text: $editContent, axis: .vertical)
                        .lineLimit(1...3)
                        .font(AppTheme.Typography.body)

                    if node.kind == .field {
                        TextField("详细内容（可选）", text: $editDetail, axis: .vertical)
                            .lineLimit(3...6)
                            .font(AppTheme.Typography.subheadline)
                    }
                } header: {
                    Text("内容")
                } footer: {
                    Text("保存后，旧分支将变为灰色存档状态，新分支将从此节点重新生长。")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                if node.isArchived {
                    Section {
                        Label("此节点属于旧版分支，编辑将基于此节点创建全新活跃分支。",
                              systemImage: "info.circle")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color.warning)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("编辑思维节点")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(editContent.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                editContent = node.content
                editDetail = node.subContent ?? ""
            }
        }
    }

    // MARK: - Node Info

    private var nodeInfo: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            Circle()
                .fill(node.nodeColor.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: nodeIconName)
                        .foregroundStyle(node.nodeColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(nodeTypeName)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
                Text(node.content)
                    .font(AppTheme.Typography.subheadline.weight(.medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
            }

            Spacer()

            if node.isArchived {
                CoDesignStatusBadge(status: .locked, text: "旧版 v\(node.branchVersion)")
            }
        }
    }

    // MARK: - Save Logic

    private func save() {
        guard let context = project.modelContext else { return }
        let trimmedContent = editContent.trimmingCharacters(in: .whitespaces)
        guard !trimmedContent.isEmpty else { return }

        let moments = project.thinkingMoments

        // 1. Find the moment being edited
        guard let editedMomentID = node.momentID,
              let editedMoment = moments.first(where: { $0.id == editedMomentID }) else {
            // No moment linked — just dismiss (shouldn't happen)
            dismiss()
            return
        }

        // 2. Archive the edited moment and all its descendants
        let descendants = collectDescendants(of: editedMomentID, in: moments)
        let toArchive = [editedMoment] + descendants
        for moment in toArchive {
            moment.isActiveBranch = false
            moment.archivedAt = Date()
        }

        // 3. Create new active moment branching from the same parent
        let newMoment = ThinkingMoment(
            momType: editedMoment.momType == "seed" ? "revise" : editedMoment.momType,
            content: trimmedContent,
            stageOrder: editedMoment.stageOrder,
            relatedField: editedMoment.relatedField,
            parentMomentID: editedMoment.parentMomentID,
            timestamp: Date(),
            isActiveBranch: true,
            branchVersion: editedMoment.branchVersion + 1
        )
        context.insert(newMoment)
        project.thinkingMoments.append(newMoment)

        // 4. Sync field changes to DesignBrief
        if let fieldRaw = editedMoment.relatedField,
           let field = BriefField(rawValue: fieldRaw),
           let brief = project.brief {
            syncBriefField(field, value: trimmedContent, brief: brief, context: context)
        }

        // 5. Save
        try? context.save()
        dismiss()
    }

    // MARK: - Helpers

    /// Recursively collects all descendant moments of a given moment ID.
    private func collectDescendants(of parentID: UUID, in moments: [ThinkingMoment]) -> [ThinkingMoment] {
        let children = moments.filter { $0.parentMomentID == parentID }
        var result = children
        for child in children {
            result.append(contentsOf: collectDescendants(of: child.id, in: moments))
        }
        return result
    }

    /// Syncs a BriefField value to the DesignBrief model.
    private func syncBriefField(_ field: BriefField, value: String, brief: DesignBrief, context: ModelContext) {
        switch field {
        case .targetUser:      brief.targetUser = value
        case .painPoint:       brief.painPoint = value
        case .useScenario:     brief.useScenario = value
        case .coreValue:       brief.coreValue = value
        case .differentiation: brief.differentiation = value
        case .mvpFeatures:     brief.mvpFeatures = value
        case .technicalModules: brief.technicalModules = value
        case .interactionFlow: brief.interactionFlow = value
        case .operationLogic:  brief.operationLogic = value
        case .hardConstraints: brief.hardConstraints = value
        case .milestones:      brief.milestones = value

        case .boundaryItems:
            // Replace with simple list parsed from lines
            brief.boundaryItems.forEach { context.delete($0) }
            brief.boundaryItems = value.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map {
                    let bi = BoundaryItem(content: $0, isIncluded: true)
                    context.insert(bi)
                    return bi
                }

        case .successMetrics:
            brief.successMetrics.forEach { context.delete($0) }
            brief.successMetrics = value.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map {
                    let sm = SuccessMetric(metric: $0, target: "待定义")
                    context.insert(sm)
                    return sm
                }

        case .risks:
            brief.risks.forEach { context.delete($0) }
            brief.risks = value.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map {
                    let ri = RiskItem(desc: $0)
                    context.insert(ri)
                    return ri
                }
        }
        brief.lastExtractedAt = Date()
    }

    private var nodeTypeName: String {
        switch node.kind {
        case .root: return "根节点"
        case .stage: return "阶段节点"
        case .field: return "字段节点"
        }
    }

    private var nodeIconName: String {
        switch node.kind {
        case .root: return "lightbulb.fill"
        case .stage: return node.iconSystemName ?? "number.circle.fill"
        case .field: return "leaf.fill"
        }
    }
}
