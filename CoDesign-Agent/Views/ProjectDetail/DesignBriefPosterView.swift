import SwiftUI

struct DesignBriefPosterView: View {
    let project: Project

    private var snapshot: DesignBriefSnapshot {
        project.brief?.toSnapshot() ?? DesignBriefSnapshot()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
            HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text(project.name)
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(nonEmpty(snapshot.coreValue) ?? nonEmpty(project.briefDescription) ?? emptyText)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Label("\(Int(project.completionRate * 100))%", systemImage: "chart.bar.fill")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.primaryAccent)
                    .padding(.horizontal, AppTheme.spacingSmall)
                    .frame(height: 30)
                    .background(Capsule(style: .continuous).fill(Color.primaryAccent.opacity(AppTheme.Opacity.light)))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: AppTheme.spacingMedium)], spacing: AppTheme.spacingMedium) {
                posterField("目标用户", snapshot.targetUser, icon: "person.2")
                posterField("核心痛点", snapshot.painPoint, icon: "exclamationmark.bubble")
                posterField("使用场景", snapshot.useScenario, icon: "map")
                posterField("设计目标", snapshot.coreValue, icon: "target")
                posterField("关键约束", constraintsText, icon: "lock.shield")
                posterField("评价标准", evaluationText, icon: "checklist")
                posterField("下一步 / 风险", nextStepText, icon: "arrow.forward.circle")
            }
        }
        .padding(AppTheme.spacingLarge)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
        .coDesignShadow(.card)
    }

    private var constraintsText: String? {
        if let hardConstraints = nonEmpty(snapshot.hardConstraints) {
            return hardConstraints
        }
        if !snapshot.boundaryItems.isEmpty {
            return "已定义 \(snapshot.boundaryItems.count) 项边界"
        }
        return nil
    }

    private var evaluationText: String? {
        guard !snapshot.successMetrics.isEmpty else { return nil }
        return snapshot.successMetrics.prefix(2).map { "\($0.metric)：\($0.target)" }.joined(separator: "；")
    }

    private var nextStepText: String? {
        if let milestones = nonEmpty(snapshot.milestones) {
            return milestones
        }
        if let risk = snapshot.risks.first {
            return "\(risk.desc)\(risk.mitigation.map { "；预案：\($0)" } ?? "")"
        }
        return nil
    }

    private var emptyText: String {
        "尚未明确，继续通过对话澄清。"
    }

    private func posterField(_ title: String, _ value: String?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Label(title, systemImage: icon)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textPrimary)

            Text(nonEmpty(value) ?? emptyText)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(nonEmpty(value) == nil ? Color.textTertiary : Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
