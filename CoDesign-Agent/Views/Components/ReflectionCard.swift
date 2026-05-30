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

    /// Stage-differentiated title for converge actions, avoiding repetitive text.
    private var displayTitle: String {
        guard trace.actionType == "converge" else { return trace.title }
        switch trace.stageOrder {
        case 1: return "你完成了一次问题收敛"
        case 2: return "你完成了一次价值判断"
        case 3: return "你完成了一次边界澄清"
        case 4: return "你完成了一次方案拆解"
        default: return "你完成了一次设计推进"
        }
    }

    /// Stage-differentiated detail for converge actions.
    private var displayDetail: String {
        guard trace.actionType == "converge" else { return trace.detail }
        switch trace.stageOrder {
        case 1: return "你把模糊想法推进到了更具体的痛点与使用场景。"
        case 2: return "你开始区分「这个产品能做什么」和「为什么值得做」。"
        case 3: return "你把发散的想法收束成了更清晰的范围与约束。"
        case 4: return "你开始把目标转化为可实现的功能模块。"
        default: return "你让项目从模糊想法向清晰方案前进了一步。"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + title
            HStack(spacing: 8) {
                Image(systemName: iconAndColor.0)
                    .font(.title3)
                    .foregroundStyle(iconAndColor.1)

                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Spacer()
            }

            // Detail
            Text(displayDetail)
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
