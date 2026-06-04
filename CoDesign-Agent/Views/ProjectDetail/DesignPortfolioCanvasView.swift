import SwiftUI

struct DesignPortfolioCanvasView: View {
    let project: Project

    private var snapshot: DesignBriefSnapshot {
        project.brief?.toSnapshot() ?? DesignBriefSnapshot()
    }

    private var stageProgress: [Double] {
        let stages = project.stages.sorted { $0.order < $1.order }
        return StageDefinition.all.map { definition in
            stages.first(where: { $0.order == definition.order })?.completionRatio ?? 0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: "设计过程图谱", subtitle: "把项目从模糊想法到方案证据的推进关系可视化")

            graphLayer
                .frame(height: 360)

            stageTrack
                .padding(.horizontal, AppTheme.spacingSmall)
                .padding(.top, AppTheme.spacingSmall)
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
    }

    private var centerNode: some View {
        VStack(spacing: AppTheme.spacingXS) {
            Image(systemName: "target")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white)

            Text(project.name)
                .font(AppTheme.Typography.subheadline.weight(.bold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 170)

            Text("当前阶段 \(project.currentStageOrder)")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(AppTheme.spacingMedium)
        .frame(width: 190, height: 126)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.primaryAccent)
        )
        .coDesignShadow(.focus)
    }

    private var stageTrack: some View {
        HStack(spacing: 6) {
            ForEach(Array(stageProgress.enumerated()), id: \.offset) { index, progress in
                VStack(spacing: 4) {
                    Capsule(style: .continuous)
                        .fill(progress > 0 ? Color.primaryAccent.opacity(0.35 + progress * 0.55) : Color.textTertiary.opacity(0.16))
                        .frame(height: 10)
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(index + 1 == project.currentStageOrder ? Color.primaryAccent : Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var graphLayer: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let center = CGPoint(x: width * 0.5, y: height * 0.48)
            let nodes = evidenceNodes(in: proxy.size)

            ZStack {
                Canvas { context, _ in
                    for node in nodes {
                        var path = Path()
                        path.move(to: center)
                        path.addLine(to: node.point)
                        context.stroke(
                            path,
                            with: .color(node.color.opacity(node.isFilled ? 0.58 : 0.18)),
                            style: StrokeStyle(lineWidth: node.isFilled ? 2.5 : 1.5, dash: node.isFilled ? [] : [5, 5])
                        )
                    }
                }

                ForEach(nodes) { node in
                    visualNode(node)
                        .position(node.point)
                }

                centerNode
                    .position(center)
            }
        }
    }

    private func visualNode(_ node: EvidenceNode) -> some View {
        VStack(spacing: AppTheme.spacingXS) {
            Image(systemName: node.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(node.color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(node.color.opacity(0.12)))

            Text(node.title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textPrimary)

            Text(node.value)
                .font(.system(size: 11))
                .foregroundStyle(node.isFilled ? Color.textSecondary : Color.textTertiary)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(width: 140)
        }
        .padding(AppTheme.spacingSmall)
        .frame(width: 164, height: 112)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.elevatedCardBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(node.color.opacity(node.isFilled ? 0.28 : 0.10), lineWidth: AppTheme.Border.thin)
        )
    }

    private func evidenceNodes(in size: CGSize) -> [EvidenceNode] {
        [
            EvidenceNode(
                title: "用户证据",
                value: filled(snapshot.targetUser),
                icon: "person.2",
                color: .success,
                point: CGPoint(x: size.width * 0.20, y: size.height * 0.20)
            ),
            EvidenceNode(
                title: "痛点场景",
                value: filled(snapshot.painPoint ?? snapshot.useScenario),
                icon: "scope",
                color: .warning,
                point: CGPoint(x: size.width * 0.80, y: size.height * 0.20)
            ),
            EvidenceNode(
                title: "核心价值",
                value: filled(snapshot.coreValue),
                icon: "sparkles",
                color: .primaryAccent,
                point: CGPoint(x: size.width * 0.20, y: size.height * 0.78)
            ),
            EvidenceNode(
                title: "风险假设",
                value: snapshot.risks.first?.desc ?? "尚未明确，继续通过对话澄清。",
                icon: "exclamationmark.triangle",
                color: .danger,
                point: CGPoint(x: size.width * 0.80, y: size.height * 0.78)
            )
        ]
    }

    private func filled(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "尚未明确，继续通过对话澄清。"
        }
        return value
    }
}

private struct EvidenceNode: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
    let point: CGPoint

    var isFilled: Bool {
        !value.contains("尚未明确")
    }
}
