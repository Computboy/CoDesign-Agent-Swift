import SwiftUI
import SwiftData

/// Sheet for editing a thinking tree node.
/// Archives the old branch and creates a new active branch from the edited node.
///
/// For field nodes:
///   - "Node Label" is the brief display name (e.g. "目标用户")
///   - "Field Value" is the actual content saved to DesignBrief
///
/// For stage/root nodes:
///   - Only "Node Label" is editable (no linked Brief field)
struct NodeEditSheet: View {
    let node: TreeNode
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var editLabel: String = ""
    @State private var editDetail: String = ""

    private var isFieldNode: Bool {
        node.kind == .field && node.field != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    nodeInfoRow
                } header: {
                    Text("当前节点")
                }

                Section {
                    HStack {
                        Text("标签")
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 56, alignment: .leading)
                        TextField("节点标签", text: $editLabel, axis: .vertical)
                            .lineLimit(1...2)
                            .font(AppTheme.Typography.body)
                    }

                    if isFieldNode {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("内容")
                                    .foregroundStyle(Color.textSecondary)
                                Spacer()
                                Text(node.field?.displayName ?? "")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(Color.primaryAccent)
                            }
                            TextField("输入新值，保存后同步到设计简报", text: $editDetail, axis: .vertical)
                                .lineLimit(4...10)
                                .font(AppTheme.Typography.body)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.softAccentBackground)
                                )
                        }
                    }
                } header: {
                    Text("编辑")
                } footer: {
                    if isFieldNode {
                        Text("保存后，旧分支变为灰色存档，新分支从此节点重新生长。内容变更会同步到工作台的设计简报。")
                            .font(AppTheme.Typography.caption)
                    } else {
                        Text("保存后，旧分支变为灰色存档，新分支从此节点重新生长。")
                            .font(AppTheme.Typography.caption)
                    }
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
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                editLabel = node.content
                if isFieldNode {
                    editDetail = node.subContent ?? ""
                }
            }
        }
    }

    private var canSave: Bool {
        if isFieldNode {
            // For field nodes, require at least the detail value to be non-empty
            return !editDetail.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return !editLabel.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Node Info Row

    private var nodeInfoRow: some View {
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
        let trimmedLabel = editLabel.trimmingCharacters(in: .whitespaces)
        let trimmedDetail = editDetail.trimmingCharacters(in: .whitespaces)
        guard !trimmedLabel.isEmpty else { return }

        let moments = project.thinkingMoments

        // 1. Find the moment being edited
        guard let editedMomentID = node.momentID,
              let editedMoment = moments.first(where: { $0.id == editedMomentID }) else {
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
        //    For field nodes: content = label (e.g. "目标用户"), value goes to DesignBrief
        //    For stage/root: content = label
        let newMoment = ThinkingMoment(
            momType: editedMoment.momType == "seed" ? "revise" : editedMoment.momType,
            content: trimmedLabel,
            stageOrder: editedMoment.stageOrder,
            relatedField: editedMoment.relatedField,
            parentMomentID: editedMoment.parentMomentID,
            timestamp: Date(),
            isActiveBranch: true,
            branchVersion: editedMoment.branchVersion + 1
        )
        context.insert(newMoment)
        project.thinkingMoments.append(newMoment)

        // 4. For field nodes: sync the edited detail value to DesignBrief
        if isFieldNode,
           let field = node.field,
           let brief = project.brief {
            syncBriefField(field, value: trimmedDetail, brief: brief, context: context)
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
