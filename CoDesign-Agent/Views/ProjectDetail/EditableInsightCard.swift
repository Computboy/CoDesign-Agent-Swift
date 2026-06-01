import SwiftUI
import SwiftData

// MARK: - EditableInsightCard

/// A single editable DesignBrief field card used in InsightCardsPanel.
/// Displays the field title, key, current value, status badge, and action buttons.
/// Supports swipe gestures: right to confirm, left to reject.
struct EditableInsightCard: View {
    let field: BriefField
    let brief: DesignBrief
    let isConfirmed: Bool
    let isRejected: Bool
    let onEdit: () -> Void
    let onConfirm: () -> Void
    let onReject: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    private let swipeThreshold: CGFloat = 80

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

    private var fieldValue: String? {
        let snapshot = brief.toSnapshot()
        switch field {
        case .targetUser: return snapshot.targetUser
        case .painPoint: return snapshot.painPoint
        case .useScenario: return snapshot.useScenario
        case .coreValue: return snapshot.coreValue
        case .differentiation: return snapshot.differentiation
        case .boundaryItems:
            return snapshot.boundaryItems.isEmpty ? nil : "已定义 \(snapshot.boundaryItems.count) 项边界"
        case .mvpFeatures: return snapshot.mvpFeatures
        case .technicalModules: return snapshot.technicalModules
        case .interactionFlow: return snapshot.interactionFlow
        case .operationLogic: return snapshot.operationLogic
        case .hardConstraints: return snapshot.hardConstraints
        case .successMetrics:
            return snapshot.successMetrics.isEmpty ? nil : "已定义 \(snapshot.successMetrics.count) 项指标"
        case .risks:
            return snapshot.risks.isEmpty ? nil : "已识别 \(snapshot.risks.count) 项风险"
        case .milestones: return snapshot.milestones
        }
    }

    private var isFilled: Bool {
        fieldValue != nil && !fieldValue!.isEmpty
    }

    private var statusBadge: (status: CoDesignStatusBadge.Status, text: String) {
        if isConfirmed { return (.complete, "已确认") }
        if isRejected { return (.warning, "需修正") }
        if isFilled { return (.info, "已提取") }
        return (.locked, "未提取")
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Swipe background indicators
            swipeBackground

            // Main card content
            cardContent
                .offset(x: dragOffset)
                .gesture(swipeGesture)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only apply horizontal drag if horizontal movement is greater than vertical
                if abs(value.translation.width) > abs(value.translation.height) {
                    isDragging = true
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                isDragging = false

                // Only trigger action if horizontal movement was dominant and exceeds threshold
                if abs(value.translation.width) > abs(value.translation.height) {
                    if value.translation.width > swipeThreshold {
                        // Right swipe: confirm
                        onConfirm()
                    } else if value.translation.width < -swipeThreshold {
                        // Left swipe: reject
                        onReject()
                    }
                }

                withAnimation(AppTheme.Animation.spring) {
                    dragOffset = 0
                }
            }
    }

    @ViewBuilder
    private var swipeBackground: some View {
        HStack {
            // Left side: reject indicator (appears when swiping left)
            if dragOffset < -20 {
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                        Text("标记不准确")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing, AppTheme.spacingMedium)
                }
                .background(Color.warning)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }

            // Right side: confirm indicator (appears when swiping right)
            if dragOffset > 20 {
                HStack {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                        Text("确认")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, AppTheme.spacingMedium)
                    Spacer()
                }
                .background(Color.success)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        if isConfirmed {
            CoDesignCard(style: .bordered) { cardBody }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.success)
                        .frame(width: 4)
                        .padding(.vertical, AppTheme.spacingSmall)
                }
        } else if isRejected {
            CoDesignCard(style: .bordered) { cardBody }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.warning)
                        .frame(width: 4)
                        .padding(.vertical, AppTheme.spacingSmall)
                }
        } else {
            CoDesignCard(style: .bordered) { cardBody }
        }
    }

    @ViewBuilder
    private var cardBody: some View {
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {

                // Header: title + key + badge
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(fieldDisplayName)
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text(field.rawValue)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.textTertiary)
                    }

                    Spacer()

                    CoDesignStatusBadge(
                        status: statusBadge.status,
                        text: statusBadge.text
                    )
                }

                // Value or placeholder
                if isFilled {
                    Text(fieldValue ?? "")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                } else {
                    Text("暂未提取，后续对话中会逐步补全")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                        .italic()
                        .lineLimit(1)
                }

                // Rejected hint
                if isRejected {
                    Text("你可以点击编辑手动修正")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)
                }

                // Action buttons — compact single row
                if isFilled {
                    HStack(spacing: AppTheme.spacingXS) {
                        Button {
                            onEdit()
                        } label: {
                            Label("编辑", systemImage: "pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.primaryAccent)
                                .padding(.horizontal, 8)
                                .frame(height: 26)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.primaryAccent.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)

                        if !isConfirmed {
                            Button {
                                onConfirm()
                            } label: {
                                Label("确认", systemImage: "checkmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .frame(height: 26)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.success)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if !isRejected {
                            Button {
                                onReject()
                            } label: {
                                Label("不准确", systemImage: "exclamationmark.triangle")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.warning)
                                    .padding(.horizontal, 8)
                                    .frame(height: 26)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.warning.opacity(0.10))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    HStack(spacing: AppTheme.spacingXS) {
                        Button {
                            onEdit()
                        } label: {
                            Label("手动填写", systemImage: "pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.primaryAccent)
                                .padding(.horizontal, 8)
                                .frame(height: 26)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.primaryAccent.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)

                        Text("等待对话补全")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: AppTheme.spacingMedium) {
            // Filled, unconfirmed
            EditableInsightCard(
                field: .targetUser,
                brief: {
                    let b = DesignBrief()
                    b.targetUser = "大一新生，尤其是来自外地的学生"
                    return b
                }(),
                isConfirmed: false,
                isRejected: false,
                onEdit: {},
                onConfirm: {},
                onReject: {}
            )

            // Filled, confirmed
            EditableInsightCard(
                field: .painPoint,
                brief: {
                    let b = DesignBrief()
                    b.painPoint = "校园面积大、建筑命名混乱，新生经常找不到教室"
                    return b
                }(),
                isConfirmed: true,
                isRejected: false,
                onEdit: {},
                onConfirm: {},
                onReject: {}
            )

            // Filled, rejected
            EditableInsightCard(
                field: .coreValue,
                brief: {
                    let b = DesignBrief()
                    b.coreValue = "智能路径规划"
                    return b
                }(),
                isConfirmed: false,
                isRejected: true,
                onEdit: {},
                onConfirm: {},
                onReject: {}
            )

            // Empty
            EditableInsightCard(
                field: .mvpFeatures,
                brief: DesignBrief(),
                isConfirmed: false,
                isRejected: false,
                onEdit: {},
                onConfirm: {},
                onReject: {}
            )
        }
        .padding()
    }
    .background(Color.appBackground)
}
