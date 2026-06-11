import SwiftUI
import SwiftData

// MARK: - InsightCardsPanel

/// An interactive panel that displays DesignBrief fields as editable cards.
/// Users can view, edit, confirm, and mark fields as inaccurate.
/// This replaces the read-only BriefSummarySection in the workspace.
/// Supports swipe gestures on cards and shows toast notifications for actions.
struct InsightCardsPanel: View {
    let project: Project
    var showsPanelChrome: Bool = true
    var showsSectionHeader: Bool = true

    @Environment(\.modelContext) private var modelContext
    @State private var confirmedFields: Set<String> = []
    @State private var rejectedFields: Set<String> = []
    @State private var editingField: BriefField?
    @State private var toastMessage: String?
    @State private var toastType: InlineToast.ToastType = .info
    @State private var recentlyConfirmedField: String?
    @State private var toastID: UUID = UUID()

    // The 6 fields to display in v1
    private let displayFields: [BriefField] = [
        .targetUser,
        .painPoint,
        .useScenario,
        .coreValue,
        .mvpFeatures,
        .successMetrics,
    ]

    var body: some View {
        Group {
            if showsPanelChrome {
                panelContent
                    .padding(AppTheme.Layout.cardPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                            .fill(Color.panelBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                            .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
                    )
                    .coDesignShadow(.card)
            } else {
                panelContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .sheet(item: $editingField) { field in
            if let brief = project.brief {
                InsightFieldEditSheet(
                    field: field,
                    brief: brief,
                    onSaveSuccess: {
                        confirmedFields.remove(field.rawValue)
                        rejectedFields.remove(field.rawValue)
                        showToast("\(field.displayName) 编辑已保存", type: .success)
                    }
                )
                .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {

            // Section header
            if showsSectionHeader {
                CoDesignSectionHeader(
                    title: "设计产物",
                    subtitle: briefSummaryText
                )
            }

            // Toast notification
            if let message = toastMessage {
                InlineToast(type: toastType, message: message) {
                    toastMessage = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let brief = project.brief {
                ExtractionReviewView(
                    brief: brief,
                    onToast: { message, type in
                        showToast(message, type: type)
                    }
                )

                if let failure = brief.latestExtractionFailureLog() {
                    extractionFailureNotice(failure)
                }

                // Field cards
                ForEach(displayFields, id: \.rawValue) { field in
                    EditableInsightCard(
                        field: field,
                        brief: brief,
                        isConfirmed: confirmedFields.contains(field.rawValue),
                        isRejected: rejectedFields.contains(field.rawValue),
                        reliabilityLog: brief.latestReliabilityLog(for: field),
                        onEdit: {
                            editingField = field
                        },
                        onConfirm: {
                            withAnimation(AppTheme.Animation.spring) {
                                toggleConfirm(field)
                                showToast("\(field.displayName) 已确认", type: .success)
                                recentlyConfirmedField = field.rawValue
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                recentlyConfirmedField = nil
                            }
                        },
                        onReject: {
                            withAnimation(AppTheme.Animation.standard) {
                                toggleReject(field)
                                showToast("\(field.displayName) 已标记为不准确", type: .warning)
                            }
                        }
                    )
                    .scaleEffect(recentlyConfirmedField == field.rawValue ? 1.02 : 1.0)
                    .animation(AppTheme.Animation.spring, value: recentlyConfirmedField)
                }

                ExtractionAuditDisclosure(brief: brief)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("暂无设计简报数据")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textTertiary)

                    Text("开始和 AI 对话后，提取的字段会显示在这里")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }

        }
    }

    // MARK: - Helpers

    private var briefSummaryText: String {
        guard let brief = project.brief else { return "暂无数据" }
        let snapshot = brief.toSnapshot()
        let filledCount = displayFields.filter { $0.isFilled(in: snapshot) }.count
        let confirmedCount = confirmedFields.count
        return "\(filledCount)/\(displayFields.count) 已提取 · \(confirmedCount) 已确认"
    }

    private func toggleConfirm(_ field: BriefField) {
        let key = field.rawValue
        if confirmedFields.contains(key) {
            confirmedFields.remove(key)
        } else {
            confirmedFields.insert(key)
            rejectedFields.remove(key)
        }
    }

    private func showToast(_ message: String, type: InlineToast.ToastType) {
        // Generate new ID for this toast to prevent old dismissal tasks from clearing it
        let currentToastID = UUID()
        toastID = currentToastID

        withAnimation(AppTheme.Animation.standard) {
            toastMessage = message
            toastType = type
        }

        // Auto-dismiss after 3 seconds, but only if this is still the current toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if toastID == currentToastID {
                withAnimation(AppTheme.Animation.standard) {
                    toastMessage = nil
                }
            }
        }
    }

    private func toggleReject(_ field: BriefField) {
        let key = field.rawValue
        if rejectedFields.contains(key) {
            rejectedFields.remove(key)
        } else {
            rejectedFields.insert(key)
            confirmedFields.remove(key)
        }
    }

    private func extractionFailureNotice(_ log: ExtractionAuditLog) -> some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.warning)

            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text("本轮未可靠提取，已保留原字段")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.warning)
                if let value = log.candidateValue {
                    Text(value)
                        .font(AppTheme.Typography.micro)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(AppTheme.Layout.compactPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.warning.opacity(AppTheme.Opacity.light))
        )
    }
}

// MARK: - ExtractionReviewView

private struct ExtractionReviewView: View {
    let brief: DesignBrief
    let onToast: (String, InlineToast.ToastType) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var editingLogID: UUID?
    @State private var draftText: String = ""

    private var pendingLogs: [ExtractionAuditLog] {
        brief.pendingExtractionReviewLogs()
    }

    var body: some View {
        if !pendingLogs.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                HStack(spacing: AppTheme.spacingXS) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primaryAccent)
                    Text("AI 提取了 \(pendingLogs.count) 个需要确认的字段")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                }

                ForEach(pendingLogs, id: \.id) { log in
                    reviewRow(log)
                }
            }
            .padding(AppTheme.Layout.compactPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .fill(Color.primaryAccent.opacity(AppTheme.Opacity.subtle))
            )
        }
    }

    private func reviewRow(_ log: ExtractionAuditLog) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            HStack(alignment: .firstTextBaseline) {
                Text(fieldTitle(log.fieldName))
                    .font(AppTheme.Typography.tinySemibold)
                    .foregroundStyle(Color.textPrimary)
                Text("Needs Review · \(Int((log.confidence * 100).rounded()))%")
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(Color.warning)
                Spacer()
            }

            if editingLogID == log.id {
                TextField("编辑候选值", text: $draftText, axis: .vertical)
                    .font(AppTheme.Typography.caption)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(log.candidateValue ?? "")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }

            if let quote = log.evidenceQuote, !quote.isEmpty {
                Text("“\(quote)”")
                    .font(AppTheme.Typography.micro)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
            }

            HStack(spacing: AppTheme.spacingXS) {
                reviewButton("接受", icon: "checkmark", tint: .success) {
                    brief.acceptPendingExtraction(log, context: modelContext)
                    try? modelContext.save()
                    onToast("\(fieldTitle(log.fieldName)) 已接受", .success)
                }

                reviewButton(editingLogID == log.id ? "保存" : "编辑", icon: "pencil", tint: .primaryAccent) {
                    if editingLogID == log.id {
                        brief.editPendingExtraction(log, editedValue: draftText, context: modelContext)
                        editingLogID = nil
                        draftText = ""
                        try? modelContext.save()
                        onToast("\(fieldTitle(log.fieldName)) 已编辑并写入", .success)
                    } else {
                        editingLogID = log.id
                        draftText = log.candidateValue ?? ""
                    }
                }

                reviewButton("忽略", icon: "xmark", tint: .textTertiary) {
                    brief.ignorePendingExtraction(log)
                    try? modelContext.save()
                    onToast("\(fieldTitle(log.fieldName)) 已忽略", .info)
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
    }

    private func reviewButton(
        _ title: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(AppTheme.Typography.micro)
                .foregroundStyle(tint)
                .padding(.horizontal, AppTheme.spacingSM)
                .frame(height: reviewButtonHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint.opacity(AppTheme.Opacity.light))
                )
        }
        .buttonStyle(.plain)
    }

    private var reviewButtonHeight: CGFloat {
        #if os(iOS)
        return 36
        #else
        return AppTheme.Layout.badgeHeight
        #endif
    }

    private func fieldTitle(_ fieldName: String) -> String {
        BriefField(rawValue: fieldName)?.displayName ?? fieldName
    }
}

// MARK: - ExtractionAuditDisclosure

private struct ExtractionAuditDisclosure: View {
    let brief: DesignBrief

    private var rejectedLogs: [ExtractionAuditLog] {
        brief.extractionAuditLogs
            .filter { $0.decisionValue == .rejected && $0.fieldName != "extraction" }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        if !rejectedLogs.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                    ForEach(rejectedLogs, id: \.id) { log in
                        VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                            Text("\(fieldTitle(log.fieldName)) · Rejected · \(Int((log.confidence * 100).rounded()))%")
                                .font(AppTheme.Typography.microSemibold)
                                .foregroundStyle(Color.textSecondary)
                            Text(log.validationNotes.isEmpty ? (log.candidateValue ?? "") : log.validationNotes)
                                .font(AppTheme.Typography.micro)
                                .foregroundStyle(Color.textTertiary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.top, AppTheme.spacingXS)
            } label: {
                Text("Extraction Audit")
                    .font(AppTheme.Typography.tinySemibold)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private func fieldTitle(_ fieldName: String) -> String {
        BriefField(rawValue: fieldName)?.displayName ?? fieldName
    }
}

// MARK: - Make BriefField Identifiable for sheet

extension BriefField: Identifiable {
    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    ScrollView {
        InsightCardsPanel(project: {
            let p = Project(name: "测试项目", briefDescription: "测试")
            let brief = DesignBrief()
            brief.targetUser = "大一新生，尤其是来自外地的学生"
            brief.painPoint = "校园面积大、建筑命名混乱，新生经常找不到教室"
            brief.useScenario = "开学第一周，需要在 10 分钟内从宿舍赶到陌生的教学楼"
            brief.coreValue = "智能路径规划，减少迷路焦虑"
            p.brief = brief
            return p
        }())
        .padding()
    }
    .background(Color.appBackground)
}
