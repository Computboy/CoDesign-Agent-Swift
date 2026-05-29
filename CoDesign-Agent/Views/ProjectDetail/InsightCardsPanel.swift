import SwiftUI
import SwiftData

// MARK: - InsightCardsPanel

/// An interactive panel that displays DesignBrief fields as editable cards.
/// Users can view, edit, confirm, and mark fields as inaccurate.
/// This replaces the read-only BriefSummarySection in the workspace.
/// Supports swipe gestures on cards and shows toast notifications for actions.
struct InsightCardsPanel: View {
    let project: Project

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

    private var sortedLearningTraces: [LearningTrace] {
        project.learningTraces.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {

            // Section header
            CoDesignSectionHeader(
                title: "设计产物",
                subtitle: briefSummaryText
            )

            // Toast notification
            if let message = toastMessage {
                InlineToast(type: toastType, message: message) {
                    toastMessage = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let brief = project.brief {
                // Field cards
                ForEach(displayFields, id: \.rawValue) { field in
                    EditableInsightCard(
                        field: field,
                        brief: brief,
                        isConfirmed: confirmedFields.contains(field.rawValue),
                        isRejected: rejectedFields.contains(field.rawValue),
                        onEdit: {
                            editingField = field
                        },
                        onConfirm: {
                            withAnimation(AppTheme.Animation.spring) {
                                toggleConfirm(field)
                                showToast("\(field.displayName) 已确认", type: .success)
                                recentlyConfirmedField = field.rawValue
                            }
                            // Clear animation state after delay
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
            } else {
                CoDesignCard {
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

            // Learning Trace Timeline (preserved from original InsightsPanel)
            learningTraceSection
        }
        .sheet(item: $editingField) { field in
            if let brief = project.brief {
                InsightFieldEditSheet(
                    field: field,
                    brief: brief,
                    onSaveSuccess: {
                        // Clear confirmed/rejected status for this field after edit
                        confirmedFields.remove(field.rawValue)
                        rejectedFields.remove(field.rawValue)
                        // Show success toast
                        showToast("\(field.displayName) 编辑已保存", type: .success)
                    }
                )
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

    // MARK: - Learning Trace Section

    private var learningTraceSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            CoDesignSectionHeader(
                title: "学习轨迹",
                subtitle: "\(sortedLearningTraces.count) 条记录"
            )

            if sortedLearningTraces.isEmpty {
                CoDesignCard {
                    Text("还没有学习轨迹——开始和 AI 对话，你的设计思维动作会被记录在这里")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(Color.textTertiary)
                }
            } else {
                ForEach(sortedLearningTraces) { trace in
                    ReflectionCard(trace: trace)
                }
            }
        }
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
