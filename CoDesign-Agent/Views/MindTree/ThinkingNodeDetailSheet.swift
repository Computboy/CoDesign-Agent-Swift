import SwiftUI

/// Detail sheet shown when a tree node is tapped.
struct ThinkingNodeDetailSheet: View {
    let node: TreeNode
    let project: Project
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    header
                    Divider()

                    switch node.kind {
                    case .root:   rootContent
                    case .stage:  stageContent
                    case .field:  fieldContent
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
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            nodeIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(nodeTitle)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(Color.textPrimary)
                if let subtitle = nodeSubtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            Spacer()
            statusBadge
        }
    }

    private var nodeIcon: some View {
        let icon: String = {
            switch node.kind {
            case .root: return "lightbulb.fill"
            case .stage: return node.iconSystemName ?? "number.circle.fill"
            case .field: return "leaf.fill"
            }
        }()
        return Image(systemName: icon)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(node.nodeColor)
            .frame(width: 44, height: 44)
            .background(
                Circle().fill(node.nodeColor.opacity(0.12))
            )
    }

    private var statusBadge: some View {
        let (text, style): (String, CoDesignStatusBadge.Status) = {
            if node.isGhost { return ("未探索", .locked) }
            switch node.nodeColor {
            case .success: return ("已完成", .complete)
            case .primaryAccent: return ("进行中", .active)
            case .warning: return ("待修正", .warning)
            default: return ("未探索", .locked)
            }
        }()
        return CoDesignStatusBadge(status: style, text: text)
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
               let def = StageDefinition.all.first(where: { $0.order == order }) {

                CoDesignSectionHeader(title: "阶段描述")
                CoDesignCard {
                    Text(def.description)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textPrimary)
                }

                CoDesignSectionHeader(title: "设计产物字段")
                let brief = project.brief?.toSnapshot() ?? DesignBriefSnapshot()
                ForEach(def.briefFields, id: \.rawValue) { field in
                    fieldRow(field, brief: brief)
                }

                CoDesignSectionHeader(title: "思考引导")
                ForEach(def.thinkingQuestions, id: \.self) { q in
                    HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Color.primaryAccent.opacity(0.6))
                        Text(q)
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
            if let sub = node.subContent {
                CoDesignSectionHeader(title: "提取内容")
                CoDesignCard {
                    Text(sub)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textPrimary)
                }
            } else if node.isGhost {
                CoDesignCard(style: .bordered) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(Color.textTertiary)
                        Text("此字段尚未从对话中提取。继续与 AI 对话，系统将自动识别并填充。")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(Color.textTertiary)
                    }
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

        if !traces.isEmpty {
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
        case .root: return "项目想法"
        case .stage:
            if let order = node.stageOrder,
               let def = StageDefinition.all.first(where: { $0.order == order }) {
                return "阶段 \(order): \(def.name)"
            }
            return "阶段"
        case .field: return node.content
        }
    }

    private var nodeSubtitle: String? {
        switch node.kind {
        case .root: return project.name
        case .stage: return node.subContent
        case .field: return node.subContent
        }
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
            if filled {
                Text("已填充")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.success)
            } else {
                Text("未填充")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.vertical, 2)
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
