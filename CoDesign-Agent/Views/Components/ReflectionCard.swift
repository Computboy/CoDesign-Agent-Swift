import SwiftUI

struct ReflectionCard: View {
    let trace: LearningTrace

    private var iconAndColor: (String, Color) {
        switch trace.actionType {
        case "reframe":
            return ("arrow.triangle.2.circlepath", Color.primaryAccent)
        case "converge":
            return ("scope", Color.green)
        case "boundaryShrink":
            return ("rectangle.compress.vertical", Color.orange)
        default:
            return ("sparkles", Color.gray)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + title
            HStack(spacing: 8) {
                Image(systemName: iconAndColor.0)
                    .font(.title3)
                    .foregroundStyle(iconAndColor.1)

                Text(trace.title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Spacer()
            }

            // Detail
            Text(trace.detail)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(nil)

            // Footer: stage + timestamp
            HStack(spacing: 12) {
                Label("阶段 \(trace.stageOrder)", systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)

                Label(trace.timestamp.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)

                Spacer()
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }
}

#Preview {
    VStack(spacing: 12) {
        ReflectionCard(trace: LearningTrace(
            stageOrder: 1,
            actionType: "reframe",
            title: "重新定义问题",
            detail: "你把问题从'找不到教室'重新定义为'校园空间认知负担过重'",
            timestamp: Date()
        ))

        ReflectionCard(trace: LearningTrace(
            stageOrder: 3,
            actionType: "converge",
            title: "收敛核心痛点",
            detail: "通过对话，你明确了三个最关键的用户痛点",
            timestamp: Date().addingTimeInterval(-3600)
        ))

        ReflectionCard(trace: LearningTrace(
            stageOrder: 2,
            actionType: "boundaryShrink",
            title: "收缩项目边界",
            detail: "你主动排除了'社交功能'和'外卖配送'，聚焦核心导航需求",
            timestamp: Date().addingTimeInterval(-7200)
        ))
    }
    .padding()
}
