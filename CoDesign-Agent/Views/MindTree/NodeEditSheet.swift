import SwiftUI
import SwiftData

struct QuestionRevisionContext {
    let question: String
    let revisedAnswer: String
    let stageOrder: Int
}

/// Sheet for editing a thinking tree node.
/// Question nodes edit the user's answer, not the AI question.
struct NodeEditSheet: View {
    let node: TreeNode
    let project: Project
    var onQuestionRevisionSaved: (QuestionRevisionContext) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var editLabel: String = ""
    @State private var editDetail: String = ""

    private var isQuestionNode: Bool {
        node.kind == .question
    }

    private var isFieldNode: Bool {
        node.kind == .field && node.field != nil
    }

    private var canEditNode: Bool {
        node.momentID != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    if isQuestionNode {
                        questionAnswerEditSection
                    } else {
                        nodeInfoCard
                        generalEditSection
                    }

                    helperNotice
                }
                .padding(AppTheme.spacingLarge)
            }
            .background(Color.appBackground)
            .navigationTitle(isQuestionNode ? "修改你的回答" : "编辑思维节点")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isQuestionNode ? "保存并回溯" : "保存") { save() }
                        .disabled(!canSave || !canEditNode)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                editLabel = node.content
                if isQuestionNode {
                    if let answer = pairedAnswerForQuestion() {
                        editDetail = ThinkingTreeMomentProjector.displayAnswerText(
                            for: answer,
                            in: project.messages
                        )
                    } else {
                        editDetail = ""
                    }
                } else if isFieldNode {
                    editDetail = node.subContent ?? ""
                }
            }
        }
    }

    private var canSave: Bool {
        if isQuestionNode || isFieldNode {
            return !editDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !editLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var nodeInfoCard: some View {
        CoDesignCard {
            HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
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
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if node.isArchived {
                    CoDesignStatusBadge(status: .locked, text: "旧版 v\(node.branchVersion)")
                }
            }
        }
    }

    private var questionAnswerEditSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
            VStack(alignment: .leading, spacing: 6) {
                Text("从此问题回溯")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(Color.textPrimary)

                Text("问题保持不变，只修改你当时给出的回答。保存后，此回答之后的旧路径会作为灰色分支保留，你将从新回答继续推进。")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CoDesignSectionHeader(title: "原问题")
            CoDesignCard {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Label("只读，不会修改问题本身", systemImage: "lock")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textTertiary)

                    Text(originalQuestionText)
                        .font(AppTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            CoDesignSectionHeader(title: "修改后的回答")
            CoDesignCard {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("当前回答")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textTertiary)

                    ZStack(alignment: .topLeading) {
                        if editDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("在这里补写或修改你对这个问题的回答。")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                        }

                        TextEditor(text: $editDetail)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(Color.textPrimary)
                            .frame(minHeight: 190)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                            .fill(Color.panelBackground.opacity(0.72))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
                    )
                }
            }
        }
    }

    private var generalEditSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "编辑")
            CoDesignCard {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("标签")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.textTertiary)
                        TextField("节点标签", text: $editLabel, axis: .vertical)
                            .lineLimit(1...2)
                            .font(AppTheme.Typography.body)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                    .fill(Color.panelBackground.opacity(0.72))
                            )
                    }

                    if isFieldNode {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("内容")
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(Color.textTertiary)
                                Spacer()
                                Text(node.field?.displayName ?? "")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(Color.primaryAccent)
                            }

                            TextEditor(text: $editDetail)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(Color.textPrimary)
                                .frame(minHeight: 150)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                        .fill(Color.panelBackground.opacity(0.72))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                        .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
                                )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var helperNotice: some View {
        if node.isArchived {
            noticeCard("此节点属于旧分支，编辑会基于它创建新的活跃分支。", icon: "info.circle", tint: .warning)
        } else if !canEditNode {
            noticeCard("主干阶段由工作台进度驱动，请在工作台继续澄清。", icon: "lock", tint: .textTertiary)
        } else if isQuestionNode {
            noticeCard("保存后，旧回答以及后续受影响节点会变为灰色旧分支；新回答会接在同一个问题节点后。", icon: "arrow.triangle.branch", tint: .warning)
        } else if isFieldNode {
            noticeCard("保存后，旧分支会保留为灰色历史路径，字段内容会同步到工作台设计简报。", icon: "arrow.uturn.backward", tint: .primaryAccent)
        } else {
            noticeCard("保存后，旧分支会保留为灰色历史路径，新分支从此继续。", icon: "arrow.uturn.backward", tint: .primaryAccent)
        }
    }

    private func noticeCard(_ text: String, icon: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(tint.opacity(0.07))
        )
    }

    // MARK: - Save Logic

    private func save() {
        let context = project.modelContext ?? modelContext
        guard let editedMomentID = node.momentID,
              let editedMoment = project.thinkingMoments.first(where: { $0.id == editedMomentID }) else {
            dismiss()
            return
        }

        if isQuestionNode {
            saveQuestionAnswerRevision(questionMoment: editedMoment, context: context)
            return
        }

        saveGeneralRevision(editedMoment: editedMoment, context: context)
    }

    private func saveQuestionAnswerRevision(questionMoment: ThinkingMoment, context: ModelContext) {
        let trimmedAnswer = editDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else { return }

        let existingAnswer = pairedAnswerForQuestion(questionMoment)
        let affectedMoments = affectedMomentsAfterQuestion(questionMoment, existingAnswer: existingAnswer)
        archive(affectedMoments)

        let nextVersion = ((existingAnswer?.branchVersion ?? questionMoment.branchVersion) + 1)
        let newAnswer = ThinkingMoment(
            momType: "answer",
            content: trimmedAnswer,
            stageOrder: questionMoment.stageOrder,
            relatedField: nil,
            parentMomentID: questionMoment.id,
            timestamp: Date(),
            isActiveBranch: true,
            branchVersion: nextVersion
        )
        context.insert(newAnswer)
        project.thinkingMoments.append(newAnswer)

        markStagesForReview(from: questionMoment.stageOrder)
        clearBriefFieldsAfter(stageOrder: questionMoment.stageOrder, context: context)
        project.updatedAt = Date()
        try? context.save()
        onQuestionRevisionSaved(
            QuestionRevisionContext(
                question: originalQuestionText,
                revisedAnswer: trimmedAnswer,
                stageOrder: questionMoment.stageOrder
            )
        )
        dismiss()
    }

    private func saveGeneralRevision(editedMoment: ThinkingMoment, context: ModelContext) {
        let trimmedLabel = editLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = editDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else { return }

        let affected = affectedMomentsAfter(editedMoment)
        archive([editedMoment] + affected)

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

        if isFieldNode,
           let field = node.field,
           let brief = project.brief {
            syncBriefField(field, value: trimmedDetail, brief: brief, context: context)
        }

        markStagesForReview(from: editedMoment.stageOrder)
        project.updatedAt = Date()
        try? context.save()
        dismiss()
    }

    private func affectedMomentsAfterQuestion(
        _ question: ThinkingMoment,
        existingAnswer: ThinkingMoment?
    ) -> [ThinkingMoment] {
        let archiveStart = existingAnswer?.timestamp ?? question.timestamp
        let directDescendants = existingAnswer.map { collectDescendants(of: $0.id, in: project.thinkingMoments) } ?? []
        let inferred = project.thinkingMoments.filter { moment in
            moment.isActiveBranch &&
            moment.id != question.id &&
            (
                moment.parentMomentID == question.id ||
                directDescendants.contains(where: { $0.id == moment.id }) ||
                moment.stageOrder > question.stageOrder ||
                (moment.stageOrder == question.stageOrder && moment.timestamp >= archiveStart)
            )
        }
        return unique(inferred + directDescendants + [existingAnswer].compactMap { $0 })
    }

    private func affectedMomentsAfter(_ moment: ThinkingMoment) -> [ThinkingMoment] {
        let descendants = collectDescendants(of: moment.id, in: project.thinkingMoments)
        let inferred = project.thinkingMoments.filter { candidate in
            candidate.isActiveBranch &&
            candidate.id != moment.id &&
            (
                descendants.contains(where: { $0.id == candidate.id }) ||
                candidate.stageOrder > moment.stageOrder ||
                (candidate.stageOrder == moment.stageOrder && candidate.timestamp > moment.timestamp)
            )
        }
        return unique(descendants + inferred)
    }

    private func archive(_ moments: [ThinkingMoment]) {
        let now = Date()
        for moment in unique(moments) where moment.isActiveBranch {
            moment.isActiveBranch = false
            moment.archivedAt = now
        }
    }

    private func clearBriefFieldsAfter(stageOrder: Int, context: ModelContext) {
        guard let brief = project.brief else { return }
        let fieldsToClear = StageDefinition.all
            .filter { $0.order > stageOrder }
            .flatMap(\.briefFields)

        for field in fieldsToClear {
            clearBriefField(field, brief: brief, context: context)
        }
        brief.lastExtractedAt = Date()
    }

    private func markStagesForReview(from stageOrder: Int) {
        for stage in project.stages {
            if stage.order == stageOrder {
                stage.status = "needsReview"
                stage.lastUpdated = Date()
            } else if stage.order > stageOrder {
                stage.status = "notStarted"
                stage.completionRatio = 0
                stage.lastUpdated = Date()
            }
        }
    }

    // MARK: - Helpers

    private func pairedAnswerForQuestion() -> ThinkingMoment? {
        guard let questionID = node.momentID,
              let question = project.thinkingMoments.first(where: { $0.id == questionID }) else {
            return nil
        }
        return pairedAnswerForQuestion(question)
    }

    private func pairedAnswerForQuestion(_ question: ThinkingMoment) -> ThinkingMoment? {
        ThinkingTreeMomentProjector.pairedAnswer(for: question, in: project.thinkingMoments)
    }

    private var originalQuestionText: String {
        ThinkingTreeMomentProjector.displayQuestionText(for: node, in: project.messages)
    }

    private func collectDescendants(of parentID: UUID, in moments: [ThinkingMoment]) -> [ThinkingMoment] {
        let children = moments.filter { $0.parentMomentID == parentID }
        var result = children
        for child in children {
            result.append(contentsOf: collectDescendants(of: child.id, in: moments))
        }
        return result
    }

    private func unique(_ moments: [ThinkingMoment]) -> [ThinkingMoment] {
        var seen = Set<UUID>()
        return moments.filter { seen.insert($0.id).inserted }
    }

    /// Syncs a BriefField value to the DesignBrief model.
    private func syncBriefField(_ field: BriefField, value: String, brief: DesignBrief, context: ModelContext) {
        switch field {
        case .targetUser:       brief.targetUser = value
        case .painPoint:        brief.painPoint = value
        case .useScenario:      brief.useScenario = value
        case .coreValue:        brief.coreValue = value
        case .differentiation:  brief.differentiation = value
        case .mvpFeatures:      brief.mvpFeatures = value
        case .technicalModules: brief.technicalModules = value
        case .interactionFlow:  brief.interactionFlow = value
        case .operationLogic:   brief.operationLogic = value
        case .hardConstraints:  brief.hardConstraints = value
        case .milestones:       brief.milestones = value

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

    private func clearBriefField(_ field: BriefField, brief: DesignBrief, context: ModelContext) {
        switch field {
        case .targetUser:       brief.targetUser = nil
        case .painPoint:        brief.painPoint = nil
        case .useScenario:      brief.useScenario = nil
        case .coreValue:        brief.coreValue = nil
        case .differentiation:  brief.differentiation = nil
        case .mvpFeatures:      brief.mvpFeatures = nil
        case .technicalModules: brief.technicalModules = nil
        case .interactionFlow:  brief.interactionFlow = nil
        case .operationLogic:   brief.operationLogic = nil
        case .hardConstraints:  brief.hardConstraints = nil
        case .milestones:       brief.milestones = nil
        case .boundaryItems:
            brief.boundaryItems.forEach { context.delete($0) }
            brief.boundaryItems = []
        case .successMetrics:
            brief.successMetrics.forEach { context.delete($0) }
            brief.successMetrics = []
        case .risks:
            brief.risks.forEach { context.delete($0) }
            brief.risks = []
        }
    }

    private var nodeTypeName: String {
        switch node.kind {
        case .root: return "根节点"
        case .stage: return "阶段节点"
        case .branchStage: return "旧阶段节点"
        case .question: return "问题节点"
        case .field: return "字段节点"
        case .process: return "过程节点"
        case .evidence: return "依据节点"
        case .revision: return "回溯节点"
        }
    }

    private var nodeIconName: String {
        switch node.kind {
        case .root: return "lightbulb.fill"
        case .stage: return node.iconSystemName ?? "number.circle.fill"
        case .branchStage: return node.iconSystemName ?? "arrow.uturn.backward"
        case .question: return "questionmark.circle"
        case .field: return "leaf.fill"
        case .process: return node.iconSystemName ?? "bubble.left"
        case .evidence: return "doc.text.magnifyingglass"
        case .revision: return "arrow.uturn.backward"
        }
    }
}
