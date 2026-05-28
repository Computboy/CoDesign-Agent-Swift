import SwiftUI

struct StageNodeView: View {
    let stage: ProgressStage

    private var statusColor: Color {
        switch stage.status {
        case "notStarted":
            return Color.gray
        case "active":
            return Color.primaryAccent
        case "completed":
            return Color.green
        case "needsReview":
            return Color.orange
        default:
            return Color.gray
        }
    }

    private var statusText: String {
        switch stage.status {
        case "notStarted":
            return "未开始"
        case "active":
            return "进行中"
        case "completed":
            return "已完成"
        case "needsReview":
            return "需复查"
        default:
            return "未知"
        }
    }

    private var stageNumber: String {
        String(format: "%02d", stage.order)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: stage number + name + status
            HStack(spacing: 12) {
                Text(stageNumber)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(statusColor)

                Text(stage.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Fill
                    Capsule()
                        .fill(statusColor)
                        .frame(width: geometry.size.width * stage.completionRatio, height: 6)
                }
            }
            .frame(height: 6)

            // Completion ratio
            HStack {
                Spacer()
                Text("\(Int(stage.completionRatio * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 12) {
        StageNodeView(stage: ProgressStage(
            order: 1,
            name: "痛点与场景锚定",
            status: "completed",
            completionRatio: 1.0
        ))

        StageNodeView(stage: ProgressStage(
            order: 2,
            name: "利益相关者分析",
            status: "active",
            completionRatio: 0.6
        ))

        StageNodeView(stage: ProgressStage(
            order: 3,
            name: "价值主张设计",
            status: "notStarted",
            completionRatio: 0.0
        ))

        StageNodeView(stage: ProgressStage(
            order: 4,
            name: "原型设计",
            status: "needsReview",
            completionRatio: 0.8
        ))
    }
    .padding()
}
