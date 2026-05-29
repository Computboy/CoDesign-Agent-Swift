import SwiftUI

// MARK: - StageRail

/// A horizontal scrollable rail displaying all 9 design clarification stages.
/// Each stage is rendered as a CoDesignStagePill with state derived from ProgressStage data.
struct StageRail: View {
    let stages: [ProgressStage]
    @State private var selectedStage: ProgressStage?
    @State private var selectedDefinition: StageDefinition?

    private var sortedStages: [ProgressStage] {
        stages.sorted { $0.order < $1.order }
    }

    private func pillState(for stage: ProgressStage) -> CoDesignStagePill.State {
        switch stage.status {
        case "active":      return .active
        case "completed":   return .complete
        case "needsReview": return .warning
        case "notStarted":  return .locked
        default:            return .locked
        }
    }

    var body: some View {
        ZStack {
            if sortedStages.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.spacingSmall) {
                        ForEach(sortedStages) { stage in
                            CoDesignStagePill(
                                order: stage.order,
                                name: stage.name,
                                state: pillState(for: stage),
                                isCompact: true
                            )
                            .onLongPressGesture(minimumDuration: 0.5) {
                                // 长按显示阶段解释
                                if let definition = StageDefinition.all.first(where: { $0.order == stage.order }) {
                                    withAnimation(AppTheme.Animation.spring) {
                                        selectedStage = stage
                                        selectedDefinition = definition
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingMedium)
                }
            }

            // 阶段解释弹窗
            if let stage = selectedStage, let definition = selectedDefinition {
                StageExplanationPopover(
                    stage: stage,
                    definition: definition,
                    onDismiss: {
                        withAnimation(AppTheme.Animation.spring) {
                            selectedStage = nil
                            selectedDefinition = nil
                        }
                    }
                )
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Text("暂无阶段数据")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: AppTheme.spacingLarge) {
        StageRail(stages: [
            ProgressStage(order: 1, name: "痛点与场景锚定", status: "completed", completionRatio: 1.0),
            ProgressStage(order: 2, name: "差异化价值提炼", status: "completed", completionRatio: 1.0),
            ProgressStage(order: 3, name: "项目边界定义", status: "active", completionRatio: 0.5),
            ProgressStage(order: 4, name: "功能与技术拆解", status: "notStarted", completionRatio: 0.0),
            ProgressStage(order: 5, name: "运行逻辑与规则", status: "notStarted", completionRatio: 0.0),
            ProgressStage(order: 6, name: "硬性约束设计", status: "notStarted", completionRatio: 0.0),
            ProgressStage(order: 7, name: "量化验收标准", status: "notStarted", completionRatio: 0.0),
            ProgressStage(order: 8, name: "风险识别与预案", status: "notStarted", completionRatio: 0.0),
            ProgressStage(order: 9, name: "项目阶段排期", status: "notStarted", completionRatio: 0.0),
        ])

        StageRail(stages: [])
    }
    .padding(.vertical)
    .background(Color.appBackground)
}
