import SwiftUI

struct LearningReflectionSummaryView: View {
    let project: Project

    private var snapshot: DesignBriefSnapshot {
        project.brief?.toSnapshot() ?? DesignBriefSnapshot()
    }

    private var completedStages: Int {
        project.stages.filter { $0.stageStatusValue == .completed }.count
    }

    private var filledFields: [BriefField] {
        BriefField.allCases.filter { $0.isFilled(in: snapshot) }
    }

    private var missingFields: [BriefField] {
        BriefField.allCases.filter { !$0.isFilled(in: snapshot) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "Learning Reflection Summary", subtitle: "基于当前数据自动生成的学习小结")

            Text(summaryText)
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppTheme.spacingSmall) {
                summaryBadge("\(completedStages)/9 阶段", icon: "chart.line.uptrend.xyaxis")
                summaryBadge("\(filledFields.count)/\(BriefField.allCases.count) 字段", icon: "doc.text.magnifyingglass")
                summaryBadge("\(project.learningTraces.count) 张反思卡", icon: "lightbulb")
            }
        }
        .padding(AppTheme.spacingLarge)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.primaryAccent.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.18), lineWidth: AppTheme.Border.thin)
        )
    }

    private var summaryText: String {
        let clearFields = filledFields.prefix(2).map(\.displayName).joined(separator: "和")
        let needsFocus = missingFields.prefix(2).map(\.displayName).joined(separator: "和")

        if filledFields.isEmpty {
            return "你正在开始第一个澄清循环。下一步建议先聚焦：目标用户、核心痛点和使用场景，让项目从想法进入具体情境。"
        }

        let clearPart = clearFields.isEmpty ? "部分信息" : clearFields
        let focusPart = needsFocus.isEmpty ? "最终汇报表达" : needsFocus
        return "你已经完成 \(completedStages)/9 个澄清阶段，当前 Design Brief 中\(clearPart)较清晰，但\(focusPart)仍需补充。下一步建议聚焦：如何判断这个设计方案是否有效。"
    }

    private func summaryBadge(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(AppTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(Color.primaryAccent)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Capsule(style: .continuous).fill(Color.elevatedCardBackground.opacity(0.78)))
    }
}
