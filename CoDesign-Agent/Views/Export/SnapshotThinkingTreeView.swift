import SwiftUI

struct SnapshotThinkingTreeView: View {
    let package: CoDesignPackage
    @Binding var showArchivedBranches: Bool

    @State private var expandedStages: Set<Int>
    @State private var selectedNode: CoDesignMindTreeNode?

    init(package: CoDesignPackage, showArchivedBranches: Binding<Bool>) {
        self.package = package
        _showArchivedBranches = showArchivedBranches
        _expandedStages = State(initialValue: Set(package.display.expandedStages))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            if package.mindTree.nodes.isEmpty {
                emptyState
            } else {
                ForEach(stageOrders, id: \.self) { stageOrder in
                    stageSection(stageOrder)
                }
            }
        }
        .sheet(item: $selectedNode) { node in
            SnapshotNodeDetailView(node: node, package: package)
                #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                #endif
        }
    }

    private var visibleNodes: [CoDesignMindTreeNode] {
        package.mindTree.nodes
            .filter { showArchivedBranches || !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.stageOrder == rhs.stageOrder {
                    return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
                }
                return lhs.stageOrder < rhs.stageOrder
            }
    }

    private var stageOrders: [Int] {
        Array(Set(visibleNodes.map(\.stageOrder))).sorted()
    }

    private func stageSection(_ stageOrder: Int) -> some View {
        let nodes = visibleNodes.filter { $0.stageOrder == stageOrder }
        let title = stageOrder == 0
            ? "项目主题"
            : "Stage \(stageOrder) / \(nodes.first?.stageTitle ?? ReportSnapshotValue.stageTitle(stageOrder))"
        let isExpanded = expandedStages.contains(stageOrder)

        return VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Button {
                withAnimation(AppTheme.Animation.standard) {
                    if isExpanded {
                        expandedStages.remove(stageOrder)
                    } else {
                        expandedStages.insert(stageOrder)
                    }
                }
            } label: {
                HStack(spacing: AppTheme.spacingSmall) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(AppTheme.Typography.caption.weight(.bold))
                        .foregroundStyle(Color.primaryAccent)
                        .frame(width: 20)

                    Text(title)
                        .font(AppTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Text("\(nodes.count)")
                        .font(AppTheme.Typography.microSemibold)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(Color.cardBackground))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: AppTheme.spacingSmall) {
                    ForEach(nodes) { node in
                        SnapshotTreeNodeRow(node: node) {
                            selectedNode = node
                        }
                    }
                }
                .padding(.leading, AppTheme.spacingMedium)
            }
        }
        .padding(AppTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
    }

    private var emptyState: some View {
        Label("项目包中没有可显示的思维树数据。", systemImage: "tree")
            .font(AppTheme.Typography.caption)
            .foregroundStyle(Color.textTertiary)
            .padding(AppTheme.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill(Color.cardBackground)
            )
    }
}

private struct SnapshotTreeNodeRow: View {
    let node: CoDesignMindTreeNode
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(tint.opacity(AppTheme.Opacity.light)))

                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    HStack(spacing: AppTheme.spacingXS) {
                        Text(node.kind)
                            .font(AppTheme.Typography.microSemibold)
                            .foregroundStyle(tint)
                            .padding(.horizontal, 7)
                            .frame(height: 20)
                            .background(Capsule().fill(tint.opacity(AppTheme.Opacity.light)))

                        if node.isArchived {
                            Text("旧分支 v\(node.branchVersion)")
                                .font(AppTheme.Typography.microSemibold)
                                .foregroundStyle(Color.warning)
                        }
                    }

                    Text(node.content)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let relatedField = node.relatedField {
                        Text("关联字段：\(relatedField)")
                            .font(AppTheme.Typography.micro)
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(AppTheme.spacingSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .fill(node.isArchived ? Color.warning.opacity(AppTheme.Opacity.subtle) : Color.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch node.momType {
        case "project": return "lightbulb.fill"
        case "stage": return "scope"
        case "question": return "questionmark.circle"
        case "answer": return "bubble.left"
        case "decision", "deepen": return "checkmark.seal"
        case "evidence": return "doc.text.magnifyingglass"
        case "revise": return "arrow.uturn.backward"
        default: return "sparkles"
        }
    }

    private var tint: Color {
        node.isArchived ? Color.warning : Color.primaryAccent
    }
}

private struct SnapshotNodeDetailView: View {
    let node: CoDesignMindTreeNode
    let package: CoDesignPackage

    var body: some View {
        NavigationStack {
            List {
                Section("节点") {
                    Text(node.content)
                    LabeledContent("类型", value: node.kind)
                    LabeledContent("阶段", value: "Stage \(node.stageOrder) / \(node.stageTitle)")
                    LabeledContent("分支", value: node.isArchived ? "旧分支 v\(node.branchVersion)" : "主线")
                    if let relatedField = node.relatedField {
                        LabeledContent("关联字段", value: relatedField)
                    }
                    if let timestamp = node.timestamp {
                        LabeledContent("时间", value: timestamp.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if !node.metadata.isEmpty {
                    Section("Metadata") {
                        ForEach(node.metadata.keys.sorted(), id: \.self) { key in
                            LabeledContent(key, value: node.metadata[key] ?? "")
                        }
                    }
                }
            }
            .navigationTitle("节点详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
