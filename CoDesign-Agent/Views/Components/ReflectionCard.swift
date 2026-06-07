import SwiftUI

struct ReflectionCard: View {
    let trace: LearningTrace

    private var iconAndColor: (String, Color) {
        switch trace.actionType {
        case "reframe":
            return ("arrow.triangle.2.circlepath", Color.primaryAccent)
        case "converge":
            return ("scope", Color.success)
        case "boundaryShrink":
            return ("rectangle.compress.vertical", Color.warning)
        case "differentiate":
            return ("square.grid.2x2", Color.secondaryAccent)
        case "challenge":
            return ("questionmark.diamond", Color.warning)
        case "prioritize":
            return ("arrow.down.right.and.arrow.up.left", Color.success)
        case "bound":
            return ("lock.shield", Color.primaryAccent)
        default:
            return ("sparkles", Color.textTertiary)
        }
    }

    /// Stage-differentiated title for converge actions, avoiding repetitive text.
    private var displayTitle: String {
        switch trace.stageOrder {
        case 1: return "你锚定了痛点场景"
        case 2: return "你提炼了差异价值"
        case 3: return "你收缩了项目范围"
        case 4: return "你拆解了功能方案"
        case 5: return "你明确了运行规则"
        case 6: return "你识别了硬性约束"
        case 7: return "你明确了验收标准"
        case 8: return "你识别了核心风险"
        case 9: return "你排定了推进阶段"
        default:
            switch trace.actionType {
            case "reframe": return "你重新定义了问题"
            case "boundaryShrink": return "你收缩了项目范围"
            case "converge": return "你形成了设计判断"
            default: return trace.title
            }
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
        case 5: return "你把体验推进为更明确的运行逻辑和规则。"
        case 6: return "你识别了必须遵守的资源、技术或场景限制。"
        case 7: return "你把“做好”转化为可以检查的验收标准。"
        case 8: return "你提前识别了可能阻碍项目成立的关键风险。"
        case 9: return "你把方案拆成了更可执行的阶段和里程碑。"
        default: return "你让项目从模糊想法向清晰方案前进了一步。"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + title
            HStack(spacing: 8) {
                Image(systemName: iconAndColor.0)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconAndColor.1)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(iconAndColor.1.opacity(0.08))
                    )

                Text(displayTitle)
                    .font(AppTheme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()
            }

            // Detail
            Text(displayDetail)
                .font(AppTheme.Typography.caption)
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
        .background(Color.elevatedCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
        .coDesignShadow(.card)
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
