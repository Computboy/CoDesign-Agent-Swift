import SwiftUI

struct ProgressPanel: View {
    let project: Project

    private var sortedStages: [ProgressStage] {
        project.stages.sorted { $0.order < $1.order }
    }

    private var overallCompletion: Double {
        project.completionRate
    }

    private var overallCompletionPercent: Int {
        Int(overallCompletion * 100)
    }

    var body: some View {
        if project.stages.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall progress summary
                    overallProgressSection

                    Divider()
                        .padding(.vertical, 8)

                    // Stage list
                    stagesSection
                }
                .padding()
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Overall Progress Section

    private var overallProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("9 步设计澄清进度")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline) {
                Text("\(overallCompletionPercent)%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primaryAccent)

                Spacer()

                Text("整体完成度")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: overallCompletion)
                .progressViewStyle(.linear)
                .tint(Color.primaryAccent)
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stages Section

    private var stagesSection: some View {
        VStack(spacing: 12) {
            ForEach(sortedStages) { stage in
                StageNodeView(stage: stage)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("暂无进度数据")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("请先创建项目或开始对话")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    NavigationStack {
        ProgressPanel(project: {
            let project = Project(
                name: "测试项目",
                briefDescription: "这是一个测试项目"
            )

            // Add 9 stages with different statuses
            project.stages = [
                ProgressStage(order: 1, name: "痛点与场景锚定", status: "completed", completionRatio: 1.0),
                ProgressStage(order: 2, name: "利益相关者分析", status: "completed", completionRatio: 1.0),
                ProgressStage(order: 3, name: "价值主张设计", status: "active", completionRatio: 0.7),
                ProgressStage(order: 4, name: "原型设计", status: "notStarted", completionRatio: 0.0),
                ProgressStage(order: 5, name: "用户测试", status: "notStarted", completionRatio: 0.0),
                ProgressStage(order: 6, name: "技术方案", status: "notStarted", completionRatio: 0.0),
                ProgressStage(order: 7, name: "商业模式", status: "notStarted", completionRatio: 0.0),
                ProgressStage(order: 8, name: "团队组建", status: "notStarted", completionRatio: 0.0),
                ProgressStage(order: 9, name: "项目规划", status: "notStarted", completionRatio: 0.0)
            ]

            return project
        }())
        .navigationTitle("进度")
    }
}
