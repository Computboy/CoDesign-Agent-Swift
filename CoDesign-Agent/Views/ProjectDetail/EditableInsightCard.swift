import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

// MARK: - EditableInsightCard

/// A single editable DesignBrief field card used in InsightCardsPanel.
/// Displays the field title, key, current value, status badge, and action buttons.
/// Supports swipe gestures: right to confirm, left to reject.
struct EditableInsightCard: View {
    let field: BriefField
    let brief: DesignBrief
    let isConfirmed: Bool
    let isRejected: Bool
    let reliabilityLog: ExtractionAuditLog?
    let onEdit: () -> Void
    let onConfirm: () -> Void
    let onReject: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isEvidenceExpanded: Bool = false

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
        if let reliabilityLog {
            let percent = Int((reliabilityLog.confidence * 100).rounded())
            switch reliabilityLog.levelValue {
            case .confirmed:
                return (.complete, "Confirmed · \(percent)%")
            case .needsReview:
                return (.warning, "Needs Review · \(percent)%")
            case .rejected:
                return (.locked, "Rejected · \(percent)%")
            }
        }
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
                #if os(iOS)
                // Fail before recognition when the drag is vertical. This lets
                // the enclosing Design Brief ScrollView own vertical panning,
                // while preserving the card's horizontal review interaction.
                .gesture(
                    HorizontalCardSwipeGesture(
                        onChanged: updateSwipe(translation:),
                        onEnded: finishSwipe(translation:)
                    )
                )
                #else
                .gesture(swipeGesture)
                #endif
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    updateSwipe(translation: value.translation.width)
                }
            }
            .onEnded { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    finishSwipe(translation: value.translation.width)
                } else {
                    finishSwipe(translation: 0)
                }
            }
    }

    private func updateSwipe(translation: CGFloat) {
        isDragging = true
        dragOffset = translation
    }

    private func finishSwipe(translation: CGFloat) {
        isDragging = false

        if translation > swipeThreshold {
            onConfirm()
        } else if translation < -swipeThreshold {
            onReject()
        }

        withAnimation(AppTheme.Animation.spring) {
            dragOffset = 0
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

    private var cardContent: some View {
        let accentColor: Color = {
            if isConfirmed { return .success }
            if isRejected { return .warning }
            return .clear
        }()

        return VStack {
            cardBody
        }
        .padding(AppTheme.Layout.compactPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(
                    AppTheme.Border.color,
                    lineWidth: AppTheme.Border.thin
                )
        )
        .overlay(alignment: .leading) {
            if isConfirmed || isRejected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4)
                    .padding(.vertical, AppTheme.spacingSmall)
            }
        }
        .coDesignShadow(.card)
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

                if let quote = reliabilityLog?.evidenceQuote,
                   !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    evidenceChip(quote)
                }
            } else {
                Text("暂未提取，后续对话中会逐步补全")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
                    .italic()
                    .lineLimit(1)
            }

            // Rejected hint
            if isRejected {
                HStack(spacing: AppTheme.spacingXS) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(AppTheme.Typography.micro)
                    Text("已标记为需修正，可点击编辑调整")
                        .font(AppTheme.Typography.micro)
                }
                .foregroundStyle(Color.warning)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(1)
            }

            // Action buttons — compact single row
            if isFilled {
                HStack(spacing: AppTheme.spacingXS) {
                    quietFieldButton("编辑", icon: "pencil", tint: .primaryAccent, action: onEdit)

                    if !isConfirmed {
                        quietFieldButton("确认", icon: "checkmark", tint: .success, action: onConfirm)
                    }

                    if !isRejected {
                        Button {
                            onReject()
                        } label: {
                            Image(systemName: "exclamationmark.triangle")
                                .font(AppTheme.Typography.tinySemibold)
                                .foregroundStyle(Color.warning.opacity(AppTheme.Opacity.strong))
                                .frame(width: fieldActionHeight, height: fieldActionHeight)
                                .background(
                                    Circle()
                                        .fill(Color.warning.opacity(AppTheme.Opacity.light))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("标记不准确")
                    }
                }
            } else {
                HStack(spacing: AppTheme.spacingXS) {
                    quietFieldButton("手动填写", icon: "pencil", tint: .primaryAccent, action: onEdit)

                    Text("等待对话补全")
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }

    private func evidenceChip(_ quote: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            Button {
                withAnimation(AppTheme.Animation.quick) {
                    isEvidenceExpanded.toggle()
                }
            } label: {
                Label("Evidence", systemImage: "quote.bubble")
                    .font(AppTheme.Typography.microSemibold)
                    .foregroundStyle(Color.primaryAccent)
                    .padding(.horizontal, AppTheme.spacingSmall)
                    .frame(height: AppTheme.Layout.badgeHeight)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primaryAccent.opacity(AppTheme.Opacity.light))
                    )
            }
            .buttonStyle(.plain)

            if isEvidenceExpanded {
                Text(quote)
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(Color.textSecondary)
                    .padding(AppTheme.spacingSmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                            .fill(Color.primaryAccent.opacity(AppTheme.Opacity.subtle))
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func quietFieldButton(
        _ title: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(AppTheme.Typography.tinySemibold)
                .foregroundStyle(tint.opacity(AppTheme.Opacity.strong))
                .padding(.horizontal, AppTheme.spacingSmall)
                .frame(height: fieldActionHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint.opacity(AppTheme.Opacity.light))
                )
        }
        .buttonStyle(.plain)
    }

    private var fieldActionHeight: CGFloat {
        #if os(iOS)
        return 36
        #else
        return AppTheme.Layout.badgeHeight
        #endif
    }
}

#if os(iOS)
/// A direction-locked pan recognizer for card review gestures.
///
/// SwiftUI's `DragGesture` begins before its `onChanged` direction check runs,
/// which can prevent an ancestor `ScrollView` from ever receiving a vertical
/// drag. This recognizer rejects vertical pans in
/// `gestureRecognizerShouldBegin`, before gesture arbitration completes.
private struct HorizontalCardSwipeGesture: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat) -> Void

        init(
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat) -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }

            let velocity = panGesture.velocity(in: panGesture.view)
            return abs(velocity.x) > abs(velocity.y)
        }

    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x

        switch recognizer.state {
        case .began, .changed:
            context.coordinator.onChanged(translation)
        case .ended:
            context.coordinator.onEnded(translation)
        case .cancelled, .failed:
            context.coordinator.onEnded(0)
        default:
            break
        }
    }
}
#endif

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
                reliabilityLog: nil,
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
                reliabilityLog: nil,
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
                reliabilityLog: nil,
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
                reliabilityLog: nil,
                onEdit: {},
                onConfirm: {},
                onReject: {}
            )
        }
        .padding()
    }
    .background(Color.appBackground)
}
