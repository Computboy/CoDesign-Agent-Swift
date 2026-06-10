import SwiftUI

/// Detail sheet shown when a tree node is tapped.
struct ThinkingNodeDetailSheet: View {
    let node: TreeNode
    let project: Project
    var onAdoptEvidence: (ResourceCard, Int) -> Void = { _, _ in }
    var onEditNode: (TreeNode) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var isResourceModuleExpanded = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    header
                    Divider()

                    switch node.kind {
                    case .root:
                        rootContent
                    case .stage:
                        stageContent
                    case .question:
                        questionContent
                    case .field:
                        fieldContent
                    case .process:
                        processContent
                    case .evidence:
                        evidenceContent
                    case .revision:
                        revisionContent
                    }

                    relatedTraces
                }
                .padding(AppTheme.spacingLarge)
            }
            .background(Color.appBackground)
            .navigationTitle(nodeTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if node.isEditable && !node.isArchived {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            dismiss()
                            onEditNode(node)
                        } label: {
                            Label("回溯修改", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            nodeIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(nodeTitle)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                if let subtitle = nodeSubtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer()
            statusBadge
        }
    }

    private var nodeIcon: some View {
        Image(systemName: node.iconSystemName ?? "sparkles")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(node.nodeColor)
            .frame(width: 44, height: 44)
            .background(Circle().fill(node.nodeColor.opacity(0.12)))
    }

    private var statusBadge: some View {
        let style: CoDesignStatusBadge.Status
        if node.isGhost {
            style = .locked
        } else if node.kind == .revision || node.isArchived {
            style = .warning
        } else if node.kind == .stage && node.statusText == "已完成" {
            style = .complete
        } else if node.kind == .stage && node.statusText == "进行中" {
            style = .active
        } else if node.kind == .stage && node.statusText == "待复核" {
            style = .warning
        } else {
            style = .active
        }

        return CoDesignStatusBadge(status: style, text: node.statusText ?? "过程")
    }

    // MARK: - Root Content

    private var rootContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "项目概述")
            CoDesignCard {
                Text(project.briefDescription.isEmpty ? project.name : project.briefDescription)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textPrimary)
            }

            let filledCount = project.brief?.toSnapshot().filledFieldCount ?? 0
            let totalCount = BriefField.allCases.count
            HStack(spacing: AppTheme.spacingLarge) {
                statItem(value: "\(filledCount)/\(totalCount)", label: "字段已填充")
                statItem(value: "\(project.messages.count)", label: "对话轮次")
                statItem(value: "\(project.learningTraces.count)", label: "学习轨迹")
            }
        }
    }

    // MARK: - Stage Content

    private var stageContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            if let order = node.stageOrder,
               let definition = StageDefinition.all.first(where: { $0.order == order }) {
                CoDesignSectionHeader(title: "阶段描述")
                CoDesignCard {
                    Text(definition.description)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textPrimary)
                }

                CoDesignSectionHeader(title: "设计产物字段")
                let brief = project.brief?.toSnapshot() ?? DesignBriefSnapshot()
                ForEach(definition.briefFields, id: \.rawValue) { field in
                    fieldRow(field, brief: brief)
                }

                CoDesignSectionHeader(title: "思考引导")
                ForEach(definition.thinkingQuestions, id: \.self) { question in
                    HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Color.primaryAccent.opacity(0.65))
                        Text(question)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                stageResourceModule(order: order)
            }
        }
    }

    // MARK: - Process Content

    private var questionContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "澄清问题")
            CoDesignCard {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text(node.content)
                        .font(AppTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    if let answer = nextAnswerForQuestion {
                        Divider()
                        Text("后续回答")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.textTertiary)
                        Text(answer.content)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("这个问题还没有匹配到后续回答。")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            if node.isEditable && !node.isArchived {
                Button {
                    dismiss()
                    onEditNode(node)
                } label: {
                    Label("从这个问题回溯修改", systemImage: "arrow.uturn.backward.circle")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.warning)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var processContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: node.processLabel ?? "过程节点")
            CoDesignCard {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text(node.content)
                        .font(AppTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    if let subContent = node.subContent {
                        Text(subContent)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Field Content

    private var fieldContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "结构化判断")
            CoDesignCard {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text(node.content)
                        .font(AppTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    if let subContent = node.subContent {
                        Text(subContent)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("该字段仍需在工作台中继续澄清。")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Evidence Content

    private var evidenceContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            if let resource = node.resource {
                CoDesignSectionHeader(title: "本地知识库依据")

                CoDesignCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                        HStack(spacing: AppTheme.spacingSmall) {
                            CoDesignStatusBadge(status: .active, text: resource.type == .paper ? "RAG" : resource.type.displayName)
                            if let year = resource.year {
                                Text("\(year)")
                                    .font(AppTheme.Typography.captionMono)
                                    .foregroundStyle(Color.textTertiary)
                            }
                            Spacer()
                        }

                        Text(resource.title)
                            .font(AppTheme.Typography.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        resourceBlock("核心观点", resource.promptCoreIdea)
                        resourceBlock("为什么与当前阶段相关", resource.whyRelevant)
                        resourceBlock("它帮助完成哪类设计判断", resource.processActionText)
                        resourceBlock("AI 可以怎样用", resource.promptRAGUse)
                        if let source = resource.sourceDisplayText {
                            resourceBlock("来源简写", source)
                        }

                        Button {
                            if let stageOrder = node.stageOrder {
                                onAdoptEvidence(resource, stageOrder)
                                dismiss()
                            }
                        } label: {
                            Label("采纳为依据", systemImage: "checkmark.seal")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.secondaryAccent)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                CoDesignSectionHeader(title: "已采纳依据")
                CoDesignCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Text(node.content)
                            .font(AppTheme.Typography.body.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text(node.subContent ?? "此依据已进入项目过程记录。")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }

    private var revisionContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "回溯记录")
            CoDesignCard(style: .highlighted(.warning)) {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text(node.content)
                        .font(AppTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("旧路径已归档，新路径会继续作为当前分支生长。")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Related Traces

    @ViewBuilder
    private var relatedTraces: some View {
        let traces = project.learningTraces
            .filter { trace in
                guard let order = node.stageOrder else { return false }
                return trace.stageOrder == order
            }
            .sorted { $0.timestamp < $1.timestamp }

        if !traces.isEmpty && node.kind != .process {
            CoDesignSectionHeader(title: "学习轨迹")
            VStack(spacing: AppTheme.spacingSmall) {
                ForEach(traces) { trace in
                    ReflectionCard(trace: trace)
                }
            }
        }
    }

    // MARK: - Helpers

    private var nodeTitle: String {
        switch node.kind {
        case .root:
            return "项目想法"
        case .stage:
            if let order = node.stageOrder,
               let definition = StageDefinition.all.first(where: { $0.order == order }) {
                return "阶段 \(order): \(definition.name)"
            }
            return "阶段"
        case .question:
            return "澄清问题"
        case .field:
            return node.field?.displayName ?? node.content
        case .process:
            return node.processLabel ?? "过程"
        case .evidence:
            return "Evidence"
        case .revision:
            return "回溯记录"
        }
    }

    private var nodeSubtitle: String? {
        switch node.kind {
        case .root:
            return project.name
        case .stage:
            return node.subContent
        case .question, .field, .process, .evidence, .revision:
            return node.content
        }
    }

    private var nextAnswerForQuestion: ThinkingMoment? {
        guard node.kind == .question,
              let momentID = node.momentID,
              let question = project.thinkingMoments.first(where: { $0.id == momentID }) else {
            return nil
        }

        return project.thinkingMoments
            .filter {
                $0.stageOrder == question.stageOrder &&
                $0.momType == "answer" &&
                $0.timestamp > question.timestamp
            }
            .sorted { $0.timestamp < $1.timestamp }
            .first
    }

    private func fieldRow(_ field: BriefField, brief: DesignBriefSnapshot) -> some View {
        let filled = field.isFilled(in: brief)
        return HStack {
            Circle()
                .fill(filled ? Color.success : Color.stageNotStarted)
                .frame(width: 8, height: 8)
            Text(field.displayName)
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(filled ? "已填充" : "未填充")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(filled ? Color.success : Color.textTertiary)
        }
        .padding(.vertical, 2)
    }

    private func stageResourceModule(order: Int) -> some View {
        let resources = ResourceRecommendationService().recommend(
            currentStageOrder: order,
            brief: project.brief,
            recentMessage: project.latestConversationText,
            limit: 3
        )

        return DisclosureGroup(isExpanded: $isResourceModuleExpanded) {
            VStack(spacing: AppTheme.spacingSmall) {
                ForEach(resources) { resource in
                    ResourceCardView(resource: resource)
                }
            }
            .padding(.top, AppTheme.spacingSmall)
        } label: {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondaryAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("阶段设计依据")
                        .font(AppTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(resources.first?.userDisplayText ?? "当前阶段暂无本地知识库依据")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
        }
        .tint(Color.secondaryAccent)
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color.secondaryAccent.opacity(0.16), lineWidth: AppTheme.Border.thin)
        )
    }

    private func resourceBlock(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textTertiary)
            Text(content)
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTheme.Typography.title)
                .foregroundStyle(Color.primaryAccent)
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - DesignBriefSnapshot Extension

private extension DesignBriefSnapshot {
    var filledFieldCount: Int {
        BriefField.allCases.filter { $0.isFilled(in: self) }.count
    }
}
