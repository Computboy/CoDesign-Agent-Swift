import SwiftUI
import SwiftData

struct InsightsPanel: View {
    let project: Project

    private var sortedLearningTraces: [LearningTrace] {
        project.learningTraces.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppTheme.spacingLarge) {
                BriefSummarySection(brief: project.brief)
                Divider()
                LearningTraceTimeline(traces: sortedLearningTraces)
            }
            .padding()
        }
        .coDesignHideScrollIndicators()
        .background(Color.appBackground)
    }
}

// MARK: - BriefSummarySection

private struct BriefSummarySection: View {
    let brief: DesignBrief?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            Text("设计简报")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)

            if let brief {
                let snapshot = brief.toSnapshot()

                ForEach(StageDefinition.all, id: \.order) { def in
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        // Stage header
                        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                            Text(def.name)
                                .font(.headline)
                                .foregroundStyle(Color.textPrimary)
                            Text(def.description)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(Color.textTertiary)
                        }

                        // Stage fields
                        ForEach(def.briefFields, id: \.rawValue) { field in
                            BriefFieldRow(field: field, snapshot: snapshot)
                        }
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                    .coDesignShadow(.card)
                }
            } else {
                Text("暂无设计简报数据")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(Color.textTertiary)
                    .padding()
            }
        }
    }
}

// MARK: - BriefFieldRow

private struct BriefFieldRow: View {
    let field: BriefField
    let snapshot: DesignBriefSnapshot

    private var isFilled: Bool {
        field.isFilled(in: snapshot)
    }

    private var fieldIcon: String {
        isFilled ? "checkmark.circle.fill" : "circle"
    }

    private var fieldColor: Color {
        isFilled ? Color.success : Color.textTertiary
    }

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

    private var fieldValue: String {
        guard isFilled else { return "尚未填写" }

        switch field {
        case .targetUser: return snapshot.targetUser ?? ""
        case .painPoint: return snapshot.painPoint ?? ""
        case .useScenario: return snapshot.useScenario ?? ""
        case .coreValue: return snapshot.coreValue ?? ""
        case .differentiation: return snapshot.differentiation ?? ""
        case .boundaryItems: return "已定义 \(snapshot.boundaryItems.count) 项边界"
        case .mvpFeatures: return snapshot.mvpFeatures ?? ""
        case .technicalModules: return snapshot.technicalModules ?? ""
        case .interactionFlow: return snapshot.interactionFlow ?? ""
        case .operationLogic: return snapshot.operationLogic ?? ""
        case .hardConstraints: return snapshot.hardConstraints ?? ""
        case .successMetrics: return "已定义 \(snapshot.successMetrics.count) 项指标"
        case .risks: return "已识别 \(snapshot.risks.count) 项风险"
        case .milestones: return snapshot.milestones ?? ""
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            Image(systemName: fieldIcon)
                .foregroundStyle(fieldColor)
                .frame(width: AppTheme.Layout.iconMedium)

            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(fieldDisplayName)
                    .font(AppTheme.Typography.subheadline.weight(.medium))
                    .foregroundStyle(Color.textPrimary)

                Text(fieldValue)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(isFilled ? Color.textSecondary : Color.textTertiary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}

// MARK: - LearningTraceTimeline

private struct LearningTraceTimeline: View {
    let traces: [LearningTrace]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            Text("学习轨迹")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)

            if traces.isEmpty {
                Text("还没有学习轨迹——开始和 AI 对话，你的设计思维动作会被记录在这里")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(Color.textTertiary)
                    .padding()
            } else {
                VStack(spacing: AppTheme.spacingSmall) {
                    ForEach(traces) { trace in
                        ReflectionCard(trace: trace)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        InsightsPanel(project: {
            let project = Project(
                name: "测试项目",
                briefDescription: "这是一个测试项目"
            )

            let brief = DesignBrief()
            brief.targetUser = "大一新生，尤其是来自外地的学生"
            brief.painPoint = "校园面积大、建筑命名混乱，新生经常找不到教室"
            brief.useScenario = "开学第一周，需要在 10 分钟内从宿舍赶到陌生的教学楼"
            project.brief = brief

            project.learningTraces = [
                LearningTrace(
                    stageOrder: 1,
                    actionType: "reframe",
                    title: "重新定义问题",
                    detail: "你把问题从'找不到教室'重新定义为'校园空间认知负担过重'",
                    timestamp: Date()
                ),
                LearningTrace(
                    stageOrder: 3,
                    actionType: "boundaryShrink",
                    title: "收缩项目边界",
                    detail: "你主动排除了'社交功能'和'外卖配送'，聚焦核心导航需求",
                    timestamp: Date().addingTimeInterval(-3600)
                )
            ]

            return project
        }())
        .navigationTitle("洞察")
    }
}
