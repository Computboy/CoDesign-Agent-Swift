import SwiftUI

// MARK: - VisualBoardView

/// A visual final-output board for the project.
/// It turns the structured DesignBrief into maps, canvases, and matrices so
/// the result feels different from a plain AI-generated text summary.
struct VisualBoardView: View {
    let project: Project

    private var brief: DesignBrief? {
        project.brief
    }

    private var sortedStages: [ProgressStage] {
        project.stages.sorted { $0.order < $1.order }
    }

    private var sortedTraces: [LearningTrace] {
        project.learningTraces.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                VisualBoardHero(project: project, brief: brief, stages: sortedStages)

                ClarificationMapSection(project: project, brief: brief)

                MVPBoundaryCanvas(brief: brief)

                RiskMatrixSection(brief: brief)

                DesignEvolutionSection(stages: sortedStages, traces: sortedTraces)
            }
            .padding(.horizontal, AppTheme.spacingLarge)
            .padding(.vertical, AppTheme.spacingMedium)
        }
        .coDesignHideScrollIndicators()
        .background(Color.appBackground)
    }
}

// MARK: - Hero

private struct VisualBoardHero: View {
    let project: Project
    let brief: DesignBrief?
    let stages: [ProgressStage]

    private var filledFieldCount: Int {
        guard let brief else { return 0 }
        let snapshot = brief.toSnapshot()
        return BriefField.allCases.filter { $0.isFilled(in: snapshot) }.count
    }

    private var totalFieldCount: Int {
        BriefField.allCases.count
    }

    private var maturityText: String {
        let rate = project.completionRate
        if rate >= 1.0 { return "可展示" }
        if rate >= 0.66 { return "接近成型" }
        if rate >= 0.33 { return "正在收敛" }
        if rate > 0 { return "初步澄清" }
        return "待澄清"
    }

    private var oneLineDefinition: String {
        if let coreValue = cleanedText(brief?.coreValue) {
            return coreValue
        }
        if let painPoint = cleanedText(brief?.painPoint) {
            return "围绕「\(painPoint)」展开的设计项目"
        }
        if let desc = cleanedText(project.briefDescription) {
            return desc
        }
        return "项目定义还在生成中"
    }

    var body: some View {
        CoDesignCard(style: .elevated) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: AppTheme.spacingXL) {
                    heroText
                    Spacer(minLength: AppTheme.spacingLarge)
                    maturityRing
                    summaryStats
                }

                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    heroText
                    HStack(alignment: .center, spacing: AppTheme.spacingLarge) {
                        maturityRing
                        summaryStats
                    }
                }
            }
        }
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "map")
                    .foregroundStyle(Color.primaryAccent)

                Text("可视化成果看板")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.primaryAccent)
            }

            Text(project.name)
                .font(AppTheme.Typography.title)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            Text(oneLineDefinition)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var maturityRing: some View {
        ZStack {
            Circle()
                .stroke(Color.textTertiary.opacity(0.12), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0.02, project.completionRate))
                .stroke(
                    Color.primaryAccent,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(project.completionRate * 100))%")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(maturityText)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(width: 96, height: 96)
        .accessibilityLabel("项目成熟度 \(Int(project.completionRate * 100))%")
    }

    private var summaryStats: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            VisualStatPill(
                icon: "checklist",
                value: "\(filledFieldCount)/\(totalFieldCount)",
                label: "字段已澄清"
            )
            VisualStatPill(
                icon: "square.stack.3d.up",
                value: "\(stages.filter { $0.status == "completed" }.count)",
                label: "阶段已完成"
            )
            VisualStatPill(
                icon: "exclamationmark.triangle",
                value: "\(brief?.risks.count ?? 0)",
                label: "风险已识别"
            )
        }
    }
}

private struct VisualStatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primaryAccent)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(Color.primaryAccent.opacity(0.08))
                )

            Text(value)
                .font(AppTheme.Typography.captionMono)
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            Capsule(style: .continuous)
                .fill(Color.panelBackground)
        )
    }
}

// MARK: - Clarification Map

private struct ClarificationMapSection: View {
    let project: Project
    let brief: DesignBrief?

    private var nodes: [ClarificationNode] {
        [
            ClarificationNode(
                title: "目标用户",
                value: brief?.targetUser,
                icon: "person.2",
                tint: .info
            ),
            ClarificationNode(
                title: "核心痛点",
                value: brief?.painPoint,
                icon: "scope",
                tint: .danger
            ),
            ClarificationNode(
                title: "使用场景",
                value: brief?.useScenario,
                icon: "map",
                tint: .primaryAccent
            ),
            ClarificationNode(
                title: "核心价值",
                value: brief?.coreValue,
                icon: "sparkles",
                tint: .secondaryAccent
            ),
            ClarificationNode(
                title: "差异化",
                value: brief?.differentiation,
                icon: "arrow.triangle.branch",
                tint: .success
            ),
            ClarificationNode(
                title: "硬性约束",
                value: brief?.hardConstraints,
                icon: "lock.shield",
                tint: .warning
            ),
            ClarificationNode(
                title: "验收标准",
                value: Self.metricSummary(from: brief),
                icon: "checkmark.seal",
                tint: .success
            ),
            ClarificationNode(
                title: "里程碑",
                value: brief?.milestones,
                icon: "calendar",
                tint: .info
            ),
        ]
    }

    var body: some View {
        VisualBoardSection(
            title: "项目澄清地图",
            subtitle: "用关系图展示设计判断之间的连接，而不是把字段排成报告"
        ) {
            ClarificationOrbitMap(
                coreDefinition: coreDefinition,
                projectCompletion: project.completionRate,
                hasBrief: brief != nil,
                nodes: nodes
            )
        }
    }

    private var coreDefinition: String {
        if let targetUser = cleanedText(brief?.targetUser),
           let painPoint = cleanedText(brief?.painPoint),
           let coreValue = cleanedText(brief?.coreValue) {
            return "为\(targetUser)解决「\(painPoint)」，核心价值是\(coreValue)。"
        }
        if let description = cleanedText(project.briefDescription) {
            return description
        }
        return "继续回答 AI 追问后，这里会形成项目的一句话定义。"
    }

    private static func metricSummary(from brief: DesignBrief?) -> String? {
        guard let metrics = brief?.successMetrics, !metrics.isEmpty else { return nil }
        return metrics
            .prefix(2)
            .map { "\($0.metric)：\($0.target)" }
            .joined(separator: "；")
    }
}

private struct ClarificationOrbitMap: View {
    let coreDefinition: String
    let projectCompletion: Double
    let hasBrief: Bool
    let nodes: [ClarificationNode]

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width < 720 {
                VStack(spacing: AppTheme.spacingMedium) {
                    OrbitHub(
                        coreDefinition: coreDefinition,
                        projectCompletion: projectCompletion,
                        hasBrief: hasBrief
                    )

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180), spacing: AppTheme.spacingMedium)],
                        spacing: AppTheme.spacingMedium
                    ) {
                        ForEach(nodes) { node in
                            OrbitNodeCard(node: node, isCompact: true)
                        }
                    }
                }
            } else {
                orbitCanvas(size: proxy.size)
            }
        }
        .frame(minHeight: 520)
    }

    private func orbitCanvas(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        return ZStack {
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

                for index in nodes.indices {
                    let node = nodes[index]
                    let position = nodePosition(index: index, in: canvasSize)
                    var line = Path()
                    line.move(to: center)
                    line.addLine(to: position)
                    context.stroke(
                        line,
                        with: .color((node.isFilled ? node.tint : Color.textTertiary).opacity(node.isFilled ? 0.28 : 0.12)),
                        lineWidth: node.isFilled ? 1.4 : 1
                    )
                }

                let orbit = Path(ellipseIn: CGRect(
                    x: center.x - min(canvasSize.width * 0.34, 340),
                    y: center.y - min(canvasSize.height * 0.32, 170),
                    width: min(canvasSize.width * 0.68, 680),
                    height: min(canvasSize.height * 0.64, 340)
                ))
                context.stroke(
                    orbit,
                    with: .color(Color.primaryAccent.opacity(0.09)),
                    style: StrokeStyle(lineWidth: 1.2, dash: [7, 8])
                )
            }

            OrbitHub(
                coreDefinition: coreDefinition,
                projectCompletion: projectCompletion,
                hasBrief: hasBrief
            )
            .frame(width: min(390, size.width * 0.40), height: 184)
            .position(center)

            ForEach(nodes.indices, id: \.self) { index in
                OrbitNodeCard(node: nodes[index], isCompact: false)
                    .frame(width: 220, height: 104)
                    .position(nodePosition(index: index, in: size))
            }
        }
    }

    private func nodePosition(index: Int, in size: CGSize) -> CGPoint {
        let positions: [CGPoint] = [
            CGPoint(x: 0.17, y: 0.20),
            CGPoint(x: 0.50, y: 0.10),
            CGPoint(x: 0.83, y: 0.20),
            CGPoint(x: 0.90, y: 0.50),
            CGPoint(x: 0.80, y: 0.82),
            CGPoint(x: 0.50, y: 0.90),
            CGPoint(x: 0.20, y: 0.82),
            CGPoint(x: 0.10, y: 0.50),
        ]
        let point = positions[index % positions.count]
        return CGPoint(x: size.width * point.x, y: size.height * point.y)
    }
}

private struct OrbitHub: View {
    let coreDefinition: String
    let projectCompletion: Double
    let hasBrief: Bool

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            ZStack {
                Circle()
                    .fill(Color.primaryAccent.opacity(0.10))
                    .frame(width: 46, height: 46)

                Image(systemName: "scope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primaryAccent)
            }

            Text("核心设计命题")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.primaryAccent)

            Text(coreDefinition)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(4)

            HStack(spacing: AppTheme.spacingSmall) {
                CoDesignStatusBadge(
                    status: projectCompletion >= 0.5 ? .info : .partial,
                    text: "\(Int(projectCompletion * 100))% 成熟"
                )
                CoDesignStatusBadge(
                    status: hasBrief ? .complete : .locked,
                    text: hasBrief ? "可修正" : "待提取"
                )
            }
        }
        .padding(AppTheme.spacingLarge)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.22), lineWidth: AppTheme.Border.medium)
        )
        .coDesignShadow(.focus)
    }
}

private struct OrbitNodeCard: View {
    let node: ClarificationNode
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: node.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(node.isFilled ? node.tint : Color.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill((node.isFilled ? node.tint : Color.textTertiary).opacity(0.12))
                    )

                Text(node.title)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer(minLength: AppTheme.spacingXS)

                Circle()
                    .fill(node.isFilled ? Color.success : Color.textTertiary.opacity(0.45))
                    .frame(width: 8, height: 8)
            }

            Text(node.displayValue)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(node.isFilled ? Color.textSecondary : Color.textTertiary)
                .lineLimit(isCompact ? 3 : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(node.isFilled ? node.tint.opacity(0.055) : Color.textTertiary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(
                    node.isFilled ? node.tint.opacity(0.24) : AppTheme.Border.color,
                    lineWidth: AppTheme.Border.thin
                )
        )
    }
}

private struct ClarificationNode: Identifiable {
    let id = UUID()
    let title: String
    let value: String?
    let icon: String
    let tint: Color

    var isFilled: Bool {
        cleanedText(value) != nil
    }

    var displayValue: String {
        cleanedText(value) ?? "待澄清"
    }
}

private struct ClarificationNodeCard: View {
    let node: ClarificationNode

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: node.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(node.isFilled ? node.tint : Color.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill((node.isFilled ? node.tint : Color.textTertiary).opacity(0.10))
                    )

                Text(node.title)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer(minLength: AppTheme.spacingSmall)

                Image(systemName: node.isFilled ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(node.isFilled ? Color.success : Color.textTertiary)
            }

            Text(node.displayValue)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(node.isFilled ? Color.textSecondary : Color.textTertiary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTheme.spacingMedium)
        .frame(minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(node.isFilled ? Color.elevatedCardBackground : Color.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(
                    node.isFilled ? node.tint.opacity(0.20) : AppTheme.Border.color,
                    lineWidth: AppTheme.Border.thin
                )
        )
    }
}

// MARK: - MVP Boundary Canvas

private struct MVPBoundaryCanvas: View {
    let brief: DesignBrief?

    private var includedItems: [String] {
        let boundary = brief?.includedFeatures.map(\.content) ?? []
        if !boundary.isEmpty { return boundary }
        return splitBriefList(brief?.mvpFeatures)
    }

    private var excludedItems: [String] {
        brief?.excludedFeatures.map(\.content) ?? []
    }

    private var futureItems: [String] {
        let excludedSet = Set(excludedItems)
        return splitBriefList(brief?.milestones)
            .filter { !excludedSet.contains($0) }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VisualBoardSection(
            title: "MVP 边界画布",
            subtitle: "把“要做什么”和“明确不做什么”从文字报告变成设计取舍"
        ) {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                ScopeDecisionStrip(
                    inCount: includedItems.count,
                    outCount: excludedItems.count,
                    laterCount: futureItems.count
                )

                boundaryColumns
            }
        }
    }

    private var boundaryColumns: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                boundaryColumnViews
            }

            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                boundaryColumnViews
            }
        }
    }

    @ViewBuilder
    private var boundaryColumnViews: some View {
        BoundaryColumn(
            title: "第一版必须做",
            subtitle: "MVP In",
            icon: "checkmark.circle",
            tint: .success,
            items: includedItems,
            emptyText: "继续澄清后，这里会显示第一版必须包含的核心功能。"
        )

        BoundaryColumn(
            title: "明确暂不做",
            subtitle: "MVP Out",
            icon: "nosign",
            tint: .danger,
            items: excludedItems,
            emptyText: "还没有明确排除项。建议让 AI 追问功能边界，避免范围膨胀。"
        )

        BoundaryColumn(
            title: "后续可扩展",
            subtitle: "Later",
            icon: "arrow.up.right.circle",
            tint: .info,
            items: futureItems,
            emptyText: "后续版本或里程碑还未拆分。"
        )
    }
}

private struct ScopeDecisionStrip: View {
    let inCount: Int
    let outCount: Int
    let laterCount: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                segments
            }

            VStack(spacing: 0) {
                segments
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
    }

    @ViewBuilder
    private var segments: some View {
        ScopeSegment(title: "保留", count: inCount, tint: .success, icon: "checkmark")
        ScopeSegment(title: "切掉", count: outCount, tint: .danger, icon: "xmark")
        ScopeSegment(title: "延后", count: laterCount, tint: .info, icon: "arrow.up.right")
    }
}

private struct ScopeSegment: View {
    let title: String
    let count: Int
    let tint: Color
    let icon: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(Circle().fill(tint.opacity(0.13)))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("\(count) 项判断")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer(minLength: AppTheme.spacingSmall)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .frame(height: 58)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.055))
    }
}

private struct BoundaryColumn: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let items: [String]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.13))
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tint.opacity(0.82))
                }

                Spacer(minLength: AppTheme.spacingSmall)

                Text("\(items.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }

            if items.isEmpty {
                Text(emptyText)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        BoundaryDecisionRow(index: index + 1, text: item, tint: tint)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(minWidth: 260, maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.095),
                            Color.elevatedCardBackground.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: AppTheme.Border.thin)
        )
    }
}

private struct BoundaryDecisionRow: View {
    let index: Int
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(tint.opacity(0.12))
                )

            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.elevatedCardBackground.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.10), lineWidth: AppTheme.Border.thin)
        )
    }
}

// MARK: - Risk Matrix

private struct RiskMatrixSection: View {
    let brief: DesignBrief?

    private var risks: [RiskItem] {
        brief?.risks.sorted { lhs, rhs in
            (lhs.probability * lhs.impact) > (rhs.probability * rhs.impact)
        } ?? []
    }

    var body: some View {
        VisualBoardSection(
            title: "风险矩阵",
            subtitle: "把风险从列表变成概率与影响的二维判断"
        ) {
            if risks.isEmpty {
                EmptyBoardHint(
                    icon: "exclamationmark.triangle",
                    text: "还没有风险数据。让 AI 追问“最可能失败在哪里”，这里会自动形成风险矩阵。"
                )
            } else {
                RiskScatterMatrix(risks: risks)
            }
        }
    }

    private func filteredRisks(highImpact: Bool, highProbability: Bool) -> [RiskItem] {
        risks.filter { risk in
            let isHighImpact = risk.impact >= 4
            let isHighProbability = risk.probability >= 4
            return isHighImpact == highImpact && isHighProbability == highProbability
        }
    }
}

private struct RiskScatterMatrix: View {
    let risks: [RiskItem]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                matrix
                    .frame(minWidth: 520)

                riskLegend
                    .frame(width: 280)
            }

            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                matrix
                riskLegend
            }
        }
    }

    private var matrix: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let plot = CGRect(
                x: 58,
                y: 26,
                width: max(120, size.width - 86),
                height: max(120, size.height - 70)
            )

            ZStack(alignment: .topLeading) {
                matrixBackground(plot: plot)

                ForEach(Array(risks.enumerated()), id: \.element.id) { index, risk in
                    RiskBubble(index: index + 1, risk: risk)
                        .position(position(for: risk, in: plot))
                }

                Text("影响高")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
                    .position(x: 26, y: plot.minY + 14)

                Text("影响低")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
                    .position(x: 26, y: plot.maxY - 10)

                Text("概率低")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
                    .position(x: plot.minX + 28, y: plot.maxY + 24)

                Text("概率高")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
                    .position(x: plot.maxX - 30, y: plot.maxY + 24)
            }
        }
        .frame(height: 330)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
    }

    private var riskLegend: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("风险索引")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textPrimary)

            ForEach(Array(risks.enumerated()), id: \.element.id) { index, risk in
                HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                    Text("R\(index + 1)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(riskTint(for: risk))
                        .frame(width: 32, height: 24)
                        .background(
                            Capsule(style: .continuous)
                                .fill(riskTint(for: risk).opacity(0.10))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(risk.desc)
                            .font(AppTheme.Typography.caption.weight(.medium))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)

                        if let mitigation = cleanedText(risk.mitigation) {
                            Text("预案：\(mitigation)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(riskTint(for: risk).opacity(0.045))
                )
            }
        }
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.panelBackground)
        )
    }

    private func matrixBackground(plot: CGRect) -> some View {
        Canvas { context, _ in
            let quadrants = [
                (CGRect(x: plot.midX, y: plot.minY, width: plot.width / 2, height: plot.height / 2), Color.danger.opacity(0.085)),
                (CGRect(x: plot.minX, y: plot.minY, width: plot.width / 2, height: plot.height / 2), Color.warning.opacity(0.075)),
                (CGRect(x: plot.midX, y: plot.midY, width: plot.width / 2, height: plot.height / 2), Color.info.opacity(0.065)),
                (CGRect(x: plot.minX, y: plot.midY, width: plot.width / 2, height: plot.height / 2), Color.textTertiary.opacity(0.045)),
            ]

            for (rect, color) in quadrants {
                context.fill(Path(roundedRect: rect, cornerRadius: 0), with: .color(color))
            }

            let border = Path(roundedRect: plot, cornerRadius: 12)
            context.stroke(border, with: .color(Color.textTertiary.opacity(0.16)), lineWidth: 1)

            var vertical = Path()
            vertical.move(to: CGPoint(x: plot.midX, y: plot.minY))
            vertical.addLine(to: CGPoint(x: plot.midX, y: plot.maxY))
            context.stroke(vertical, with: .color(Color.textTertiary.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))

            var horizontal = Path()
            horizontal.move(to: CGPoint(x: plot.minX, y: plot.midY))
            horizontal.addLine(to: CGPoint(x: plot.maxX, y: plot.midY))
            context.stroke(horizontal, with: .color(Color.textTertiary.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        }
    }

    private func position(for risk: RiskItem, in plot: CGRect) -> CGPoint {
        let xRatio = clampedRatio(Double(risk.probability - 1) / 4.0)
        let yRatio = 1 - clampedRatio(Double(risk.impact - 1) / 4.0)
        return CGPoint(
            x: plot.minX + plot.width * xRatio,
            y: plot.minY + plot.height * yRatio
        )
    }
}

private struct RiskBubble: View {
    let index: Int
    let risk: RiskItem

    private var tint: Color {
        riskTint(for: risk)
    }

    private var diameter: CGFloat {
        CGFloat(34 + min(22, risk.probability * risk.impact))
    }

    var body: some View {
        VStack(spacing: 1) {
            Text("R\(index)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Text("P\(risk.probability) I\(risk.impact)")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(tint)
        .frame(width: diameter, height: diameter)
        .background(
            Circle()
                .fill(tint.opacity(0.13))
        )
        .overlay(
            Circle()
                .strokeBorder(tint.opacity(0.45), lineWidth: AppTheme.Border.thin)
        )
        .shadow(color: tint.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

private struct RiskQuadrantCell: View {
    let title: String
    let subtitle: String
    let tint: Color
    let risks: [RiskItem]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(tint.opacity(0.82))
                }

                Spacer()

                Text("\(risks.count)")
                    .font(AppTheme.Typography.captionMono)
                    .foregroundStyle(tint)
            }

            if risks.isEmpty {
                Text(emptyText)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    ForEach(risks) { risk in
                        RiskMiniCard(risk: risk, tint: tint)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            }
        }
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(tint.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: AppTheme.Border.thin)
        )
    }
}

private struct RiskMiniCard: View {
    let risk: RiskItem
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            Text(risk.desc)
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            HStack(spacing: AppTheme.spacingSmall) {
                RiskScoreLabel(title: "P", value: risk.probability, tint: tint)
                RiskScoreLabel(title: "I", value: risk.impact, tint: tint)
                Spacer()
            }

            if let mitigation = cleanedText(risk.mitigation) {
                Text("预案：\(mitigation)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.elevatedCardBackground.opacity(0.9))
        )
    }
}

private struct RiskScoreLabel: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        Text("\(title)\(value)")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.10))
            )
    }
}

// MARK: - Design Evolution

private struct DesignEvolutionSection: View {
    let stages: [ProgressStage]
    let traces: [LearningTrace]

    private var displayItems: [EvolutionItem] {
        if !traces.isEmpty {
            return traces.prefix(5).map {
                EvolutionItem(
                    title: $0.title,
                    detail: $0.detail,
                    stageOrder: $0.stageOrder,
                    isComplete: true
                )
            }
        }

        return stages.prefix(5).map {
            EvolutionItem(
                title: $0.name,
                detail: stageText(for: $0),
                stageOrder: $0.order,
                isComplete: $0.status == "completed"
            )
        }
    }

    var body: some View {
        VisualBoardSection(
            title: "设计思考演化线",
            subtitle: "展示从模糊想法到清晰方案的思考痕迹"
        ) {
            if displayItems.isEmpty {
                EmptyBoardHint(
                    icon: "point.3.connected.trianglepath.dotted",
                    text: "开始回答 AI 追问后，这里会记录你的关键设计思考动作。"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                        ForEach(displayItems) { item in
                            EvolutionStepCard(item: item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .coDesignHideScrollIndicators()
            }
        }
    }

    private func stageText(for stage: ProgressStage) -> String {
        switch stage.status {
        case "completed": return "该阶段已经形成明确判断。"
        case "active": return "当前正在澄清这一阶段。"
        case "needsReview": return "该阶段需要回看和修正。"
        default: return "等待后续追问推进。"
        }
    }
}

private struct EvolutionItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let stageOrder: Int
    let isComplete: Bool
}

private struct EvolutionStepCard: View {
    let item: EvolutionItem

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(spacing: AppTheme.spacingSmall) {
                Text(String(format: "%02d", item.stageOrder))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(item.isComplete ? Color.success : Color.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill((item.isComplete ? Color.success : Color.textTertiary).opacity(0.10))
                    )

                Image(systemName: item.isComplete ? "checkmark" : "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(item.isComplete ? Color.success : Color.textTertiary)
            }

            Text(item.title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            Text(item.detail)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(4)
        }
        .padding(AppTheme.spacingMedium)
        .frame(width: 210, alignment: .topLeading)
        .frame(minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
    }
}

// MARK: - Shared Board Components

private struct VisualBoardSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            CoDesignSectionHeader(title: title, subtitle: subtitle)

            content()
        }
        .padding(AppTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
        )
        .coDesignShadow(.card)
    }
}

private struct EmptyBoardHint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            Image(systemName: icon)
                .foregroundStyle(Color.textTertiary)

            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(3)
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(Color.textTertiary.opacity(0.06))
        )
    }
}

// MARK: - Helpers

private func cleanedText(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func splitBriefList(_ value: String?) -> [String] {
    guard let value = cleanedText(value) else { return [] }
    let separators = CharacterSet(charactersIn: "\n,，、+；;")
    return value
        .components(separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func clampedRatio(_ value: Double) -> CGFloat {
    CGFloat(max(0, min(1, value)))
}

private func riskTint(for risk: RiskItem) -> Color {
    let score = risk.probability * risk.impact
    if score >= 16 { return .danger }
    if risk.impact >= 4 { return .warning }
    if risk.probability >= 4 { return .info }
    return .stageNotStarted
}

#Preview {
    NavigationStack {
        VisualBoardView(project: {
            let p = Project(
                name: "智能校园导航助手",
                briefDescription: "帮助大学新生在复杂校园中快速找到目的地"
            )
            let brief = DesignBrief()
            brief.targetUser = "大一新生，尤其是来自外地的学生"
            brief.painPoint = "校园面积大、建筑命名混乱，新生经常找不到教室"
            brief.useScenario = "开学第一周，需要在 10 分钟内从宿舍赶到陌生教学楼"
            brief.coreValue = "用 AR 和校园 POI 数据降低新生找路焦虑"
            brief.differentiation = "聚焦校园室内导航，而不是泛地图导航"
            brief.boundaryItems = [
                BoundaryItem(content: "AR 实时导航箭头", isIncluded: true),
                BoundaryItem(content: "校园 POI 搜索", isIncluded: true),
                BoundaryItem(content: "课表导入", isIncluded: true),
                BoundaryItem(content: "社交找同学", isIncluded: false),
                BoundaryItem(content: "外卖配送", isIncluded: false),
            ]
            brief.successMetrics = [
                SuccessMetric(metric: "首次导航成功率", target: "≥ 90%"),
                SuccessMetric(metric: "平均找到目的地时间", target: "≤ 5 分钟"),
            ]
            brief.risks = [
                RiskItem(desc: "AR 在弱光环境下识别不稳定", probability: 4, impact: 4, mitigation: "提供 2D 地图备选路径"),
                RiskItem(desc: "POI 数据采集工作量大", probability: 3, impact: 5, mitigation: "先覆盖主教学楼"),
            ]
            p.brief = brief
            p.stages = [
                ProgressStage(order: 1, name: "痛点与场景锚定", status: "completed", completionRatio: 1),
                ProgressStage(order: 2, name: "差异化价值提炼", status: "completed", completionRatio: 1),
                ProgressStage(order: 3, name: "项目边界划定", status: "completed", completionRatio: 1),
                ProgressStage(order: 4, name: "功能与技术方案拆解", status: "active", completionRatio: 0.67),
            ]
            return p
        }())
        .navigationTitle("成果")
    }
}
