import SwiftUI

/// Renders a single node in the thinking tree with compact semantic styles.
struct TreeNodeView: View {
    private enum ActivationBehavior {
        case singleTap
        case doubleTap
        case none
    }

    let node: TreeNode
    var isResourceExpanded = false
    var onTap: () -> Void = {}
    var onResourceExpansionChanged: () -> Void = {}
    var onResourceDragChanged: (CGSize) -> Void = { _ in }
    var onResourceDragEnded: (CGSize, CGSize) -> Void = { _, _ in }

    var body: some View {
        Group {
            if node.hasCollapsedResources {
                baseButton
                    .accessibilityAction(
                        named: "切换资源卡"
                    ) {
                        onResourceExpansionChanged()
                    }
                    .accessibilityHint(
                        isResourceExpanded
                            ? "当前已展开；将资源卡向左拖入问题节点可以收起"
                            : "当前已收纳；向右拖动问题节点可以展开"
                    )
            } else {
                baseButton
            }
        }
        .animation(AppTheme.Animation.spring, value: node.position.x)
        .animation(AppTheme.Animation.spring, value: node.position.y)
    }

    private var baseButton: some View {
        Group {
            switch activationBehavior {
            case .singleTap:
                Button(action: onTap) {
                    content
                }
                .buttonStyle(.plain)
            case .doubleTap:
                content
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onTap()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(detailAccessibilityHint)
                    .accessibilityAction {
                        onTap()
                    }
            case .none:
                content
                    .accessibilityElement(children: .combine)
            }
        }
        .opacity(nodeOpacity)
        .simultaneousGesture(resourceSwipeGesture)
    }

    private var activationBehavior: ActivationBehavior {
        switch node.kind {
        case .stage where node.stageTreeState?.isCompleted == true:
            return .singleTap
        case .branchStage:
            return .none
        default:
            return .doubleTap
        }
    }

    private var detailAccessibilityHint: String {
        node.isEditable
            ? "双击查看详情；长按可以编辑"
            : "双击查看详情"
    }

    @ViewBuilder
    private var content: some View {
        switch node.kind {
        case .root:
            rootContent
        case .stage:
            stageContent
        case .branchStage:
            rollbackForkContent
        case .question:
            questionContent
        case .field:
            processContent(width: TreeNodeMetrics.fieldSize.width)
        case .process:
            processContent(width: TreeNodeMetrics.processSize.width)
        case .revision:
            processContent(width: TreeNodeMetrics.revisionSize.width)
        }
    }

    // MARK: - Root Node

    private var rootContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18, weight: .bold))

            Text(node.content)
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .frame(width: TreeNodeMetrics.rootSize.width)
        .frame(minHeight: TreeNodeMetrics.rootSize.height)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primaryAccent,
                            Color.secondaryAccent,
                            Color(red: 0.38, green: 0.66, blue: 0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.primaryAccent.opacity(AppTheme.Opacity.noticeable), radius: 18, y: 7)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.46), lineWidth: 1.4)
        }
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.primaryAccent.opacity(0.13 + node.richness * 0.08))
                .blur(radius: 12)
                .padding(-10)
        }
    }

    // MARK: - Stage Node

    private var stageContent: some View {
        HStack(spacing: 11) {
            Image(
                systemName: node.stageTreeState == .completedCollapsed
                    ? "chevron.up"
                    : "chevron.down"
            )
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(node.nodeColor)
            .frame(width: 30, height: 30)
            .background(
                Circle().fill(node.nodeColor.opacity(0.10))
            )

            ZStack {
                Circle()
                    .fill(node.nodeColor.opacity(node.isGhost ? 0.12 : 0.18))
                    .frame(width: 40, height: 40)

                Image(systemName: node.iconSystemName ?? "circle.grid.3x3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(node.isGhost ? Color.textTertiary : node.nodeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(node.content)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(node.isGhost ? Color.textTertiary : node.nodeColor)
                    if let statusText = node.statusText {
                        Text(statusText)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(node.isGhost ? Color.textTertiary : node.nodeColor)
                    }
                }

                Text(node.subContent ?? "")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(node.isGhost ? Color.textSecondary : Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: TreeNodeMetrics.stageSize.width, alignment: .leading)
        .frame(minHeight: TreeNodeMetrics.stageSize.height)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(stageBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(
                    node.nodeColor.opacity(node.isGhost ? 0.13 : 0.34),
                    style: node.isGhost
                        ? StrokeStyle(lineWidth: 1, dash: [5, 5])
                        : StrokeStyle(lineWidth: 1.2)
                )
        )
        .shadow(
            color: node.nodeColor.opacity(0.08),
            radius: 10,
            y: 5
        )
        .accessibilityHint(
            stageAccessibilityHint
        )
        .accessibilityLabel(
            stageAccessibilityLabel
        )
    }

    private var stageAccessibilityHint: String {
        guard node.stageTreeState?.isCompleted == true else {
            return detailAccessibilityHint
        }

        return node.stageTreeState == .completedCollapsed
            ? "轻点展开该阶段的问题树"
            : "轻点收起该阶段的问题树"
    }

    private var stageAccessibilityLabel: String {
        guard node.stageTreeState?.isCompleted == true else {
            return "Stage \(node.stageOrder ?? 0)，\(node.subContent ?? node.content)"
        }

        return node.stageTreeState == .completedCollapsed
            ? "展开 Stage \(node.stageOrder ?? 0) 问题链"
            : "收起 Stage \(node.stageOrder ?? 0) 问题链"
    }

    private var stageBackground: Color {
        if node.isGhost {
            return Color.cardBackground.opacity(AppTheme.Opacity.muted)
        }
        return Color.cardBackground.opacity(AppTheme.Opacity.nearFull)
    }

    private var rollbackForkContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primaryAccent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.primaryAccent.opacity(0.10)))

            VStack(alignment: .leading, spacing: 3) {
                Text(node.content)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(node.subContent ?? "左旧右新")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .frame(width: TreeNodeMetrics.branchStageSize.width, alignment: .leading)
        .frame(minHeight: TreeNodeMetrics.branchStageSize.height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.34), lineWidth: 1.2)
        )
        .shadow(color: Color.primaryAccent.opacity(0.08), radius: 8, y: 3)
    }

    // MARK: - Process Nodes

    private var questionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 9) {
                    Text(questionNumberText)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(node.isArchived ? Color.textTertiary : Color.white)
                        .frame(
                            minWidth: node.isArchived ? 44 : 30,
                            minHeight: 30
                        )
                        .background(
                            node.isArchived
                                ? AnyShapeStyle(Color(red: 0.90, green: 0.91, blue: 0.94))
                                : AnyShapeStyle(Color.primaryAccent)
                        )
                        .clipShape(Capsule(style: .continuous))

                    Circle()
                        .strokeBorder(questionCategoryColor, lineWidth: 1.6)
                        .frame(width: 9, height: 9)

                    Text(questionCategoryTitle)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(questionCategoryColor)

                    Spacer(minLength: 0)
                }

                Text(questionSummary)
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(questionTextColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Image(systemName: questionStatusIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(questionStatusColor)

                    Text(questionStatusText)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(node.isArchived ? Color.textTertiary : Color.textSecondary)

                    Spacer(minLength: 0)

                    if node.hasCollapsedResources {
                        Image(systemName: isResourceExpanded ? "rectangle.stack.fill" : "rectangle.stack")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(node.boundResources.count)")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundStyle(node.isArchived ? Color.textTertiary : Color.textSecondary)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .frame(width: TreeNodeMetrics.questionSize.width, alignment: .leading)
        .frame(minHeight: TreeNodeMetrics.questionSize.height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cardBackground)
                .shadow(
                    color: node.isArchived ? .clear : Color.primaryAccent.opacity(0.08),
                    radius: 9,
                    y: 3
                )
        )
        .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        questionBorderColor,
                        style: node.isArchived
                            ? StrokeStyle(lineWidth: 1.2, dash: [5, 5])
                            : StrokeStyle(lineWidth: node.isAnswered ? 1.0 : 1.8)
                    )
        )
    }

    private var resourceSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard node.hasCollapsedResources,
                      abs(value.translation.width)
                        > abs(value.translation.height) * 1.18
                else {
                    return
                }
                onResourceDragChanged(value.translation)
            }
            .onEnded { value in
                guard node.hasCollapsedResources else {
                    return
                }
                onResourceDragEnded(
                    value.translation,
                    value.predictedEndTranslation
                )
            }
    }

    private var questionNumberText: String {
        let number = String(format: "%02d", node.questionNumber ?? 0)
        return node.isArchived ? "\(number)-旧" : number
    }

    private var questionCategoryTitle: String {
        node.questionCategory?.title ?? "设计判断"
    }

    private var questionCategoryColor: Color {
        node.isArchived
            ? Color(red: 0.58, green: 0.60, blue: 0.66)
            : (node.questionCategory?.color ?? Color.primaryAccent)
    }

    private var questionStatusIcon: String {
        if node.isArchived { return "checkmark.circle.fill" }
        return node.isAnswered ? "checkmark.circle.fill" : "ellipsis.circle"
    }

    private var questionStatusText: String {
        if node.isArchived { return "已归档" }
        return node.isAnswered ? "已回答" : "正在等待你的回答…"
    }

    private var questionStatusColor: Color {
        if node.isArchived { return Color.textTertiary }
        return node.isAnswered ? Color.success : Color.primaryAccent
    }

    private var questionBorderColor: Color {
        if node.isArchived {
            return Color(red: 0.72, green: 0.74, blue: 0.79)
        }
        return node.isAnswered
            ? Color(red: 0.84, green: 0.85, blue: 0.90)
            : Color.primaryAccent
    }

    private var questionSummary: String {
        let flattened = node.content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flattened
    }

    private var questionTextColor: Color {
        node.isArchived ? Color.textSecondary : Color.textPrimary
    }

    private func processContent(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: node.iconSystemName ?? "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(node.nodeColor)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(node.nodeColor.opacity(0.12)))

                Text(node.processLabel ?? "Process")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(node.nodeColor)

                Spacer(minLength: 0)
            }

            Text(node.content)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let subContent = node.subContent {
                Text(subContent)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(node.isArchived ? Color(red: 0.95, green: 0.93, blue: 0.90).opacity(AppTheme.Opacity.nearFull) : Color.cardBackground.opacity(AppTheme.Opacity.nearFull))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(
                    node.nodeColor.opacity(node.isArchived ? 0.28 : 0.22),
                    style: node.isArchived
                        ? StrokeStyle(lineWidth: 1, dash: [4, 4])
                        : StrokeStyle(lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 7, y: 3)
    }

    private var nodeOpacity: Double {
        if node.isArchived { return 0.82 }
        if node.isGhost { return 0.64 }
        return 1.0
    }

}
