import Foundation
import SwiftUI

// MARK: - VisualBoardView

/// A visual summary of the project's structured design decisions.
///
/// The global project header and tab switcher live in `ProjectDetailView`.
/// The board remains scrollable so every result module can keep a comfortable
/// presentation size instead of being forced into one viewport.
struct VisualBoardView: View {
    let project: Project
    let onStartRiskDiscovery: () -> Void

    init(
        project: Project,
        onStartRiskDiscovery: @escaping () -> Void = {}
    ) {
        self.project = project
        self.onStartRiskDiscovery = onStartRiskDiscovery
    }

    private var sortedStages: [ProgressStage] {
        project.stages.sorted { $0.order < $1.order }
    }

    private var sortedTraces: [LearningTrace] {
        project.learningTraces.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: BoardLayout.sectionSpacing) {
                ClarificationMapSection(
                    project: project,
                    brief: project.brief,
                    stages: sortedStages
                )

                MVPBoundarySection(brief: project.brief)

                RiskMatrixSection(
                    brief: project.brief,
                    onStartDiscovery: onStartRiskDiscovery
                )

                DesignEvolutionSection(
                    stages: sortedStages,
                    traces: sortedTraces
                )
            }
            .padding(.horizontal, BoardLayout.pageInset)
            .padding(.vertical, BoardLayout.sectionSpacing)
        }
        .coDesignHideScrollIndicators()
        .background(BoardPalette.pageBackground)
    }
}

// MARK: - Project Clarification Map

private struct ClarificationMapSection: View {
    let project: Project
    let brief: DesignBrief?
    let stages: [ProgressStage]
    @State private var selectedNode: ClarificationNode?

    private var nodes: [ClarificationNode] {
        [
            ClarificationNode(
                field: .targetUser,
                systemImage: "person.2",
                accentColor: BoardPalette.violet,
                positionRole: .leftUpper,
                content: brief?.targetUser
            ),
            ClarificationNode(
                field: .painPoint,
                systemImage: "scope",
                accentColor: BoardPalette.coral,
                positionRole: .top,
                content: brief?.painPoint
            ),
            ClarificationNode(
                field: .useScenario,
                systemImage: "map",
                accentColor: BoardPalette.blue,
                positionRole: .rightUpper,
                content: brief?.useScenario
            ),
            ClarificationNode(
                field: .coreValue,
                systemImage: "sparkles",
                accentColor: BoardPalette.cyan,
                positionRole: .rightMiddle,
                content: brief?.coreValue
            ),
            ClarificationNode(
                field: .differentiation,
                systemImage: "arrow.triangle.branch",
                accentColor: BoardPalette.orange,
                positionRole: .rightLower,
                content: brief?.differentiation
            ),
            ClarificationNode(
                field: .hardConstraints,
                systemImage: "lock.shield",
                accentColor: BoardPalette.blue,
                positionRole: .bottom,
                content: brief?.hardConstraints
            ),
            ClarificationNode(
                field: .successMetrics,
                systemImage: "checkmark.seal",
                accentColor: BoardPalette.green,
                positionRole: .leftLower,
                content: Self.metricSummary(from: brief)
            ),
            ClarificationNode(
                field: .milestones,
                systemImage: "calendar",
                accentColor: BoardPalette.orange,
                positionRole: .leftMiddle,
                content: brief?.milestones
            ),
        ]
    }

    private var filledFieldCount: Int {
        guard let brief else { return 0 }
        let snapshot = brief.toSnapshot()
        return BriefField.allCases.filter { $0.isFilled(in: snapshot) }.count
    }

    private var completedStageCount: Int {
        stages.filter { $0.status == "completed" }.count
    }

    private var centralPrompt: String {
        cleanedText(project.briefDescription)
            ?? cleanedText(project.name)
            ?? "继续澄清核心设计命题"
    }

    var body: some View {
        BoardCard {
            ClarificationMapHeader {
                BoardProgressSummary(
                    progress: project.completionRate,
                    filledFields: filledFieldCount,
                    totalFields: BriefField.allCases.count,
                    completedStages: completedStageCount,
                    riskCount: brief?.risks.count ?? 0
                )
            }

            ClarificationOrbitMap(
                centralPrompt: centralPrompt,
                nodes: nodes,
                selectedNodeID: selectedNode?.id,
                onSelectNode: { node in
                    withAnimation(.easeOut(duration: 0.22)) {
                        selectedNode = node
                    }
                }
            )
        }
        .sheet(item: $selectedNode) { node in
            ClarificationNodeDetailSheet(node: node)
                #if os(iOS)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                #endif
        }
    }

    private static func metricSummary(from brief: DesignBrief?) -> String? {
        guard let metrics = brief?.successMetrics, !metrics.isEmpty else { return nil }
        return metrics
            .prefix(2)
            .map { "\($0.metric)：\($0.target)" }
            .joined(separator: "；")
    }
}

private struct ClarificationMapHeader<Trailing: View>: View {
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 24) {
                titleBlock
                Spacer(minLength: 28)
                trailing()
            }

            VStack(alignment: .leading, spacing: 18) {
                titleBlock
                trailing()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.bottom, 8)
    }

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(BoardPalette.indigo)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("项目澄清地图")
                    .font(.title2.bold())
                    .foregroundStyle(Color.primary)

                Text("用关系图展示设计判断之间的连接，而不是把字段排成报告")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct BoardProgressSummary: View {
    let progress: Double
    let filledFields: Int
    let totalFields: Int
    let completedStages: Int
    let riskCount: Int

    private var maturityText: String {
        if progress >= 1 { return "可展示" }
        if progress >= 0.66 { return "接近成型" }
        if progress >= 0.33 { return "正在收敛" }
        if progress > 0 { return "初步澄清" }
        return "待澄清"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(BoardPalette.indigo.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: max(0.015, min(1, progress)))
                    .stroke(
                        BoardPalette.indigo,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.primary)

                    Text(maturityText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(width: 78, height: 78)

            VStack(spacing: 7) {
                BoardMetricPill(
                    icon: "checklist",
                    value: "\(filledFields)/\(totalFields)",
                    label: "字段已澄清"
                )
                BoardMetricPill(
                    icon: "square.stack.3d.up",
                    value: "\(completedStages)",
                    label: "阶段已完成"
                )
                BoardMetricPill(
                    icon: "exclamationmark.triangle",
                    value: "\(riskCount)",
                    label: "风险已识别"
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "项目完成度 \(Int(progress * 100))%，"
            + "\(filledFields) 个字段已澄清，"
            + "\(completedStages) 个阶段已完成，"
            + "\(riskCount) 个风险已识别"
        )
    }
}

private struct BoardMetricPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BoardPalette.indigo)
                .frame(width: 20)

            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .frame(width: 38, alignment: .trailing)

            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .frame(width: 188, height: 30)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BoardPalette.subtleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(BoardPalette.border, lineWidth: 0.8)
        )
    }
}

private struct ClarificationOrbitMap: View {
    let centralPrompt: String
    let nodes: [ClarificationNode]
    let selectedNodeID: String?
    let onSelectNode: (ClarificationNode) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var revealsContent = false

    private var mapHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 680 : 510
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = ClarificationMapLayout(
                containerSize: proxy.size,
                usesAccessibilitySizes: dynamicTypeSize.isAccessibilitySize
            )

            if layout.canUseRadialLayout {
                radialCanvas(layout: layout)
            } else {
                compactGrid(layout: layout)
            }
        }
        .frame(height: mapHeight)
        .onAppear {
            withAnimation(.easeOut(duration: 0.56)) {
                revealsContent = true
            }
        }
    }

    private func radialCanvas(layout: ClarificationMapLayout) -> some View {
        ZStack {
            ClarificationConnectionLayer(
                nodes: nodes,
                layout: layout,
                selectedNodeID: selectedNodeID
            )

            OrbitHub(
                prompt: centralPrompt,
                usesAccessibilitySizes: dynamicTypeSize.isAccessibilitySize
            )
            .frame(width: layout.centerSize.width, height: layout.centerSize.height)
            .position(layout.centerPosition)
            .opacity(revealsContent ? 1 : 0)
            .scaleEffect(revealsContent ? 1 : 0.97)
            .animation(.easeOut(duration: 0.36), value: revealsContent)

            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                nodeButton(node, layout: layout)
                    .position(layout.position(for: node.positionRole))
                    .opacity(revealsContent ? 1 : 0)
                    .scaleEffect(
                        selectedNodeID == node.id
                            ? 1.01
                            : (revealsContent ? 1 : 0.975)
                    )
                    .animation(
                        .easeOut(duration: 0.30).delay(Double(index) * 0.045),
                        value: revealsContent
                    )
                    .animation(
                        .easeOut(duration: 0.20),
                        value: selectedNodeID
                    )
            }
        }
    }

    private func compactGrid(layout: ClarificationMapLayout) -> some View {
        VStack(spacing: 16) {
            OrbitHub(
                prompt: centralPrompt,
                usesAccessibilitySizes: dynamicTypeSize.isAccessibilitySize
            )
            .frame(
                maxWidth: min(
                    layout.centerSize.width,
                    layout.containerSize.width
                )
            )
            .frame(height: layout.centerSize.height)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                ForEach(nodes) { node in
                    nodeButton(node, layout: layout)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func nodeButton(
        _ node: ClarificationNode,
        layout: ClarificationMapLayout
    ) -> some View {
        Button {
            onSelectNode(node)
        } label: {
            OrbitNodeCard(
                node: node,
                isSelected: selectedNodeID == node.id
            )
            .frame(
                maxWidth: layout.nodeSize.width,
                minHeight: layout.nodeSize.height,
                maxHeight: layout.nodeSize.height
            )
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .accessibilityLabel(
            "\(node.title)，\(node.completionState.accessibilityLabel)，\(node.displayValue)"
        )
        .accessibilityHint("轻点查看字段详情")
    }
}

private struct ClarificationMapLayout {
    let containerSize: CGSize
    let usesAccessibilitySizes: Bool

    let centerPosition: CGPoint
    let centerSize: CGSize
    let nodeSize: CGSize
    let horizontalRadius: CGFloat
    let verticalRadius: CGFloat
    let leftColumnX: CGFloat
    let rightColumnX: CGFloat
    let upperRowY: CGFloat
    let middleRowY: CGFloat
    let lowerRowY: CGFloat

    var canUseRadialLayout: Bool {
        containerSize.width >= 980 && containerSize.height >= 480
    }

    init(containerSize: CGSize, usesAccessibilitySizes: Bool) {
        self.containerSize = containerSize
        self.usesAccessibilitySizes = usesAccessibilitySizes

        let centerPosition = CGPoint(
            x: containerSize.width / 2,
            y: containerSize.height / 2
        )
        let nodeWidth = Self.clamp(
            containerSize.width * 0.205,
            minimum: 230,
            maximum: 280
        )
        let nodeHeight: CGFloat = usesAccessibilitySizes ? 108 : 86
        let centerWidth = Self.clamp(
            containerSize.width * 0.30,
            minimum: 330,
            maximum: 400
        )
        let centerHeight: CGFloat = usesAccessibilitySizes ? 170 : 136
        let horizontalRadius = min(
            containerSize.width * 0.34,
            containerSize.width / 2 - nodeWidth / 2 - 24
        )
        let verticalRadius = min(
            containerSize.height * 0.36,
            containerSize.height / 2 - nodeHeight / 2 - 18
        )

        self.centerPosition = centerPosition
        self.centerSize = CGSize(width: centerWidth, height: centerHeight)
        self.nodeSize = CGSize(width: nodeWidth, height: nodeHeight)
        self.horizontalRadius = horizontalRadius
        self.verticalRadius = verticalRadius
        self.leftColumnX = centerPosition.x - horizontalRadius
        self.rightColumnX = centerPosition.x + horizontalRadius
        self.upperRowY = centerPosition.y - verticalRadius * 0.68
        self.middleRowY = centerPosition.y
        self.lowerRowY = centerPosition.y + verticalRadius * 0.68
    }

    func position(for role: ClarificationNodePositionRole) -> CGPoint {
        switch role {
        case .top:
            return CGPoint(
                x: centerPosition.x,
                y: centerPosition.y - verticalRadius
            )
        case .bottom:
            return CGPoint(
                x: centerPosition.x,
                y: centerPosition.y + verticalRadius
            )
        case .leftUpper:
            return CGPoint(x: leftColumnX, y: upperRowY)
        case .leftMiddle:
            return CGPoint(x: leftColumnX, y: middleRowY)
        case .leftLower:
            return CGPoint(x: leftColumnX, y: lowerRowY)
        case .rightUpper:
            return CGPoint(x: rightColumnX, y: upperRowY)
        case .rightMiddle:
            return CGPoint(x: rightColumnX, y: middleRowY)
        case .rightLower:
            return CGPoint(x: rightColumnX, y: lowerRowY)
        }
    }

    var centerRect: CGRect {
        CGRect(
            x: centerPosition.x - centerSize.width / 2,
            y: centerPosition.y - centerSize.height / 2,
            width: centerSize.width,
            height: centerSize.height
        )
    }

    func nodeRect(for role: ClarificationNodePositionRole) -> CGRect {
        let nodePosition = position(for: role)
        return CGRect(
            x: nodePosition.x - nodeSize.width / 2,
            y: nodePosition.y - nodeSize.height / 2,
            width: nodeSize.width,
            height: nodeSize.height
        )
    }

    var orbitRect: CGRect {
        CGRect(
            x: centerPosition.x - horizontalRadius * 0.88,
            y: centerPosition.y - verticalRadius * 0.76,
            width: horizontalRadius * 1.76,
            height: verticalRadius * 1.52
        )
    }

    private static func clamp(
        _ value: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        min(maximum, max(minimum, value))
    }
}

private struct ClarificationConnectionLayer: View {
    let nodes: [ClarificationNode]
    let layout: ClarificationMapLayout
    let selectedNodeID: String?

    var body: some View {
        Canvas { context, _ in
            context.stroke(
                Path(ellipseIn: layout.orbitRect),
                with: .color(BoardPalette.indigo.opacity(0.09)),
                style: StrokeStyle(
                    lineWidth: 1,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [6, 8]
                )
            )

            for node in nodes {
                let path = connectionPath(for: node)
                let isSelected = selectedNodeID == node.id
                let opacity: Double = isSelected
                    ? (node.completionState == .complete ? 0.72 : 0.90)
                    : (node.completionState == .complete ? 0.65 : 0.78)
                let lineWidth: CGFloat = isSelected
                    ? 2.3
                    : (node.completionState == .complete ? 2.1 : 1.85)

                context.stroke(
                    path,
                    with: .color(node.mapTint.opacity(opacity)),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.20), value: selectedNodeID)
    }

    private func connectionPath(for node: ClarificationNode) -> Path {
        let nodeRect = layout.nodeRect(for: node.positionRole)
        let centerRect = layout.centerRect
        let start = boundaryPoint(
            in: nodeRect,
            toward: layout.centerPosition
        )
        let end = boundaryPoint(
            in: centerRect,
            toward: layout.position(for: node.positionRole)
        )

        var path = Path()
        path.move(to: start)

        switch node.positionRole {
        case .top, .bottom:
            let middleY = (start.y + end.y) / 2
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: middleY),
                control2: CGPoint(x: end.x, y: middleY)
            )
        case .leftUpper, .leftMiddle, .leftLower,
             .rightUpper, .rightMiddle, .rightLower:
            let middleX = (start.x + end.x) / 2
            path.addCurve(
                to: end,
                control1: CGPoint(x: middleX, y: start.y),
                control2: CGPoint(x: middleX, y: end.y)
            )
        }

        return path
    }

    private func boundaryPoint(in rect: CGRect, toward target: CGPoint) -> CGPoint {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let deltaX = target.x - center.x
        let deltaY = target.y - center.y
        let scaleX = abs(deltaX) > 0.001
            ? rect.width / 2 / abs(deltaX)
            : CGFloat.greatestFiniteMagnitude
        let scaleY = abs(deltaY) > 0.001
            ? rect.height / 2 / abs(deltaY)
            : CGFloat.greatestFiniteMagnitude
        let scale = min(scaleX, scaleY)

        return CGPoint(
            x: center.x + deltaX * scale,
            y: center.y + deltaY * scale
        )
    }
}

private struct OrbitHub: View {
    let prompt: String
    let usesAccessibilitySizes: Bool

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "scope")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BoardPalette.indigo)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(BoardPalette.indigo.opacity(0.08))
                )

            Text("核心设计命题")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BoardPalette.indigo)

            Text(prompt)
                .font(usesAccessibilitySizes ? .headline.bold() : .title2.bold())
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BoardPalette.elevatedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    BoardPalette.indigo.opacity(0.48),
                    lineWidth: 1.4
                )
        )
        .shadow(
            color: BoardPalette.indigo.opacity(0.14),
            radius: 15,
            x: 0,
            y: 6
        )
    }
}

private struct OrbitNodeCard: View {
    let node: ClarificationNode
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: node.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(node.mapTint)
                    .frame(width: 23)

                Text(node.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Circle()
                    .fill(
                        node.completionState == .complete
                            ? Color.success
                            : Color.secondary.opacity(0.42)
                    )
                    .frame(width: 9, height: 9)
                    .overlay {
                        if node.completionState == .complete {
                            Circle()
                                .stroke(Color.success.opacity(0.18), lineWidth: 4)
                        }
                    }
            }

            Text(node.displayValue)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.interpolate)
                .animation(.easeOut(duration: 0.22), value: node.displayValue)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    node.mapTint.opacity(
                        node.completionState == .complete ? 0.06 : 0.18
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    node.mapTint.opacity(
                        isSelected
                            ? (node.completionState == .complete ? 0.64 : 0.96)
                            : (node.completionState == .complete ? 0.42 : 0.72)
                    ),
                    lineWidth: isSelected ? 1.8 : 1.15
                )
        )
        .shadow(
            color: Color.black.opacity(isSelected ? 0.06 : 0.025),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: isSelected ? 3 : 1
        )
    }
}

private struct ClarificationNode: Identifiable {
    var id: String { field.rawValue }
    var title: String { field.displayName }

    let field: BriefField
    let systemImage: String
    let accentColor: Color
    let positionRole: ClarificationNodePositionRole
    let content: String?
    let completionState: ClarificationNodeCompletionState

    init(
        field: BriefField,
        systemImage: String,
        accentColor: Color,
        positionRole: ClarificationNodePositionRole,
        content: String?
    ) {
        self.field = field
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.positionRole = positionRole
        self.content = content
        self.completionState = cleanedText(content) == nil ? .pending : .complete
    }

    var displayValue: String {
        cleanedText(content) ?? "待澄清"
    }

    var mapTint: Color {
        completionState == .complete ? accentColor : .stageNotStarted
    }
}

private enum ClarificationNodePositionRole: String, CaseIterable {
    case top
    case bottom
    case leftUpper
    case leftMiddle
    case leftLower
    case rightUpper
    case rightMiddle
    case rightLower
}

private enum ClarificationNodeCompletionState: Equatable {
    case pending
    case complete

    var accessibilityLabel: String {
        switch self {
        case .pending: return "待澄清"
        case .complete: return "已完成"
        }
    }
}

private struct ClarificationNodeDetailSheet: View {
    let node: ClarificationNode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Image(systemName: node.systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(node.accentColor)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(node.accentColor.opacity(0.08))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.title)
                            .font(.title2.bold())
                            .foregroundStyle(Color.primary)

                        Label(
                            node.completionState.accessibilityLabel,
                            systemImage: node.completionState == .complete
                                ? "checkmark.circle.fill"
                                : "circle.dotted"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(
                            node.completionState == .complete
                                ? Color.success
                                : Color.secondary
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("当前字段内容")
                        .font(.headline)
                        .foregroundStyle(Color.primary)

                    Text(node.displayValue)
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(node.accentColor.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            node.accentColor.opacity(0.28),
                            lineWidth: 1
                        )
                )

                Spacer(minLength: 0)
            }
            .padding(24)
            .background(BoardPalette.pageBackground)
            .navigationTitle("字段详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - MVP Boundary

private struct MVPBoundarySection: View {
    let brief: DesignBrief?

    private var includedItems: [String] {
        let items = brief?.includedFeatures.map(\.content) ?? []
        return items.isEmpty ? splitBriefList(brief?.mvpFeatures) : items
    }

    private var excludedItems: [String] {
        brief?.excludedFeatures.map(\.content) ?? []
    }

    private var futureItems: [String] {
        let excluded = Set(excludedItems)
        return splitBriefList(brief?.milestones)
            .filter { !excluded.contains($0) }
    }

    var body: some View {
        BoardCard {
            BoardSectionHeader(
                icon: "rectangle.split.3x1",
                title: "MVP 边界画布",
                subtitle: "把“要做什么”和“明确不做什么”从文字报告变成设计取舍"
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    boundaryColumns
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        boundaryColumns
                    }
                }
                .coDesignHideScrollIndicators()
            }
        }
    }

    @ViewBuilder
    private var boundaryColumns: some View {
        BoundaryColumn(
            title: "保留",
            subtitle: "MVP In",
            icon: "checkmark.circle.fill",
            tint: BoardPalette.mint,
            items: includedItems,
            emptyText: "继续澄清后，这里会显示第一版必须包含的核心功能。"
        )

        BoundaryColumn(
            title: "切掉",
            subtitle: "MVP Out",
            icon: "xmark.circle.fill",
            tint: BoardPalette.coral,
            items: excludedItems,
            emptyText: "还没有明确排除项。建议让 AI 追问边界，避免范围膨胀。"
        )

        BoundaryColumn(
            title: "延后",
            subtitle: "Later",
            icon: "clock.fill",
            tint: BoardPalette.blue,
            items: futureItems,
            emptyText: "后续版本或里程碑还未拆分。"
        )
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
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(tint)
                .frame(height: 3)
                .clipShape(Capsule())

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(tint))

                Text(title)
                    .font(BoardTypography.cardTitle)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("\(items.count)")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            Text(subtitle)
                .font(BoardTypography.metadata.weight(.semibold).monospaced())
                .foregroundStyle(tint.opacity(0.84))

            if items.isEmpty {
                Text(emptyText)
                    .font(BoardTypography.cardBody)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(items.prefix(2).enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Circle()
                                .fill(tint)
                                .frame(width: 4, height: 4)

                            Text(item)
                                .font(BoardTypography.cardBody)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .frame(minWidth: 230, maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BoardPalette.elevatedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(BoardPalette.border, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.025), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Risk Matrix

private struct RiskMatrixSection: View {
    let brief: DesignBrief?
    let onStartDiscovery: () -> Void

    private var risks: [RiskItem] {
        brief?.risks.sorted {
            ($0.probability * $0.impact) > ($1.probability * $1.impact)
        } ?? []
    }

    var body: some View {
        BoardCard {
            BoardSectionHeader(
                icon: "shield.lefthalf.filled",
                title: "风险矩阵",
                subtitle: "把风险从列表变成概率与影响的二维判断"
            )

            if risks.isEmpty {
                RiskEmptyState(onStartDiscovery: onStartDiscovery)
            } else {
                CompactRiskMatrix(risks: risks)
            }
        }
    }
}

private struct RiskEmptyState: View {
    let onStartDiscovery: () -> Void

    var body: some View {
        HStack(spacing: 22) {
            RiskEmptyIllustration()
                .frame(width: 170, height: 76)

            VStack(alignment: .leading, spacing: 5) {
                Text("暂无风险数据")
                    .font(BoardTypography.cardTitle)
                    .foregroundStyle(Color.textPrimary)

                Text("让 AI 追问“最可能失败在哪里”，这里会自动形成风险矩阵。")
                    .font(BoardTypography.cardBody)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)

                Button(action: onStartDiscovery) {
                    Label("开始识别风险", systemImage: "sparkles")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(BoardPalette.indigo)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(BoardPalette.indigo.opacity(0.065))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(
                                    BoardPalette.indigo.opacity(0.34),
                                    lineWidth: 0.8
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("visualBoard.startRiskDiscovery")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }
}

private struct RiskEmptyIllustration: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(BoardPalette.indigo.opacity(0.045))
                .frame(width: 156, height: 42)
                .offset(y: 17)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { column in
                    VStack(spacing: 3) {
                        ForEach(0..<2, id: \.self) { row in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    BoardPalette.indigo.opacity(
                                        0.045 + Double(column + row) * 0.025
                                    )
                                )
                                .frame(width: 36, height: 22)
                        }
                    }
                }
            }
            .rotation3DEffect(.degrees(48), axis: (x: 1, y: 0, z: 0))
            .offset(y: 13)

            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 35, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, BoardPalette.indigo.opacity(0.72))
                .shadow(
                    color: BoardPalette.indigo.opacity(0.18),
                    radius: 8,
                    x: 0,
                    y: 5
                )
                .offset(y: -10)
        }
    }
}

private struct CompactRiskMatrix: View {
    let risks: [RiskItem]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                riskPlot
                    .frame(minWidth: 440)

                riskLegend
                    .frame(width: 300)
            }

            VStack(spacing: 12) {
                riskPlot
                riskLegend
            }
        }
    }

    private var riskPlot: some View {
        GeometryReader { proxy in
            let plot = CGRect(
                x: 42,
                y: 14,
                width: max(120, proxy.size.width - 56),
                height: max(80, proxy.size.height - 34)
            )

            ZStack(alignment: .topLeading) {
                RiskPlotBackground(plot: plot)

                ForEach(Array(risks.enumerated()), id: \.element.id) { index, risk in
                    RiskBubble(index: index + 1, risk: risk)
                        .position(position(for: risk, in: plot))
                }

                Text("影响")
                    .font(BoardTypography.metadata.weight(.medium))
                    .foregroundStyle(Color.textTertiary)
                    .position(x: 18, y: plot.minY + 7)

                Text("概率")
                    .font(BoardTypography.metadata.weight(.medium))
                    .foregroundStyle(Color.textTertiary)
                    .position(x: plot.maxX - 8, y: plot.maxY + 13)
            }
        }
        .frame(height: 156)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BoardPalette.subtleFill)
        )
    }

    private var riskLegend: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(Array(risks.enumerated()), id: \.element.id) { index, risk in
                    HStack(alignment: .top, spacing: 7) {
                        Text("R\(index + 1)")
                            .font(BoardTypography.metadata.bold().monospaced())
                            .foregroundStyle(riskTint(for: risk))
                            .frame(width: 34, height: 24)
                            .background(
                                Capsule().fill(riskTint(for: risk).opacity(0.10))
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(risk.desc)
                                .font(BoardTypography.cardBody.weight(.medium))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(2)

                            if let mitigation = cleanedText(risk.mitigation) {
                                Text("预案：\(mitigation)")
                                    .font(BoardTypography.supporting)
                                    .foregroundStyle(Color.textTertiary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 156)
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

private struct RiskPlotBackground: View {
    let plot: CGRect

    var body: some View {
        Canvas { context, _ in
            let quadrants = [
                (
                    CGRect(
                        x: plot.midX,
                        y: plot.minY,
                        width: plot.width / 2,
                        height: plot.height / 2
                    ),
                    BoardPalette.coral.opacity(0.09)
                ),
                (
                    CGRect(
                        x: plot.minX,
                        y: plot.minY,
                        width: plot.width / 2,
                        height: plot.height / 2
                    ),
                    BoardPalette.orange.opacity(0.08)
                ),
                (
                    CGRect(
                        x: plot.midX,
                        y: plot.midY,
                        width: plot.width / 2,
                        height: plot.height / 2
                    ),
                    BoardPalette.blue.opacity(0.065)
                ),
                (
                    CGRect(
                        x: plot.minX,
                        y: plot.midY,
                        width: plot.width / 2,
                        height: plot.height / 2
                    ),
                    Color.textTertiary.opacity(0.035)
                ),
            ]

            for (rect, color) in quadrants {
                context.fill(Path(rect), with: .color(color))
            }

            context.stroke(
                Path(roundedRect: plot, cornerRadius: 8),
                with: .color(BoardPalette.border),
                lineWidth: 0.8
            )

            var vertical = Path()
            vertical.move(to: CGPoint(x: plot.midX, y: plot.minY))
            vertical.addLine(to: CGPoint(x: plot.midX, y: plot.maxY))
            context.stroke(
                vertical,
                with: .color(Color.textTertiary.opacity(0.16)),
                style: StrokeStyle(lineWidth: 0.8, dash: [4, 4])
            )

            var horizontal = Path()
            horizontal.move(to: CGPoint(x: plot.minX, y: plot.midY))
            horizontal.addLine(to: CGPoint(x: plot.maxX, y: plot.midY))
            context.stroke(
                horizontal,
                with: .color(Color.textTertiary.opacity(0.16)),
                style: StrokeStyle(lineWidth: 0.8, dash: [4, 4])
            )
        }
    }
}

private struct RiskBubble: View {
    let index: Int
    let risk: RiskItem

    var body: some View {
        Text("R\(index)")
            .font(BoardTypography.metadata.bold().monospaced())
            .foregroundStyle(riskTint(for: risk))
            .frame(width: 30, height: 30)
            .background(
                Circle().fill(riskTint(for: risk).opacity(0.14))
            )
            .overlay(
                Circle().strokeBorder(
                    riskTint(for: risk).opacity(0.4),
                    lineWidth: 0.8
                )
            )
    }
}

// MARK: - Design Evolution

private struct DesignEvolutionSection: View {
    let stages: [ProgressStage]
    let traces: [LearningTrace]

    private var displayItems: [EvolutionItem] {
        if !traces.isEmpty {
            return traces.map {
                EvolutionItem(
                    id: $0.id.uuidString,
                    title: $0.title,
                    detail: $0.detail,
                    stageOrder: $0.stageOrder,
                    actionType: $0.actionType,
                    isComplete: true
                )
            }
        }

        return stages.map {
            EvolutionItem(
                id: $0.id.uuidString,
                title: $0.name,
                detail: stageText(for: $0),
                stageOrder: $0.order,
                actionType: "stage",
                isComplete: $0.status == "completed"
            )
        }
    }

    var body: some View {
        BoardCard {
            BoardSectionHeader(
                icon: "point.3.filled.connected.trianglepath.dotted",
                title: "设计思考演化线",
                subtitle: "展示从模糊想法到清晰方案的思考痕迹"
            )

            if displayItems.isEmpty {
                BoardEmptyHint(
                    icon: "point.3.connected.trianglepath.dotted",
                    text: "开始回答 AI 追问后，这里会记录你的关键设计思考动作。"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: 0) {
                        ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                            EvolutionStepCard(item: item)

                            if index < displayItems.count - 1 {
                                EvolutionConnector()
                            }
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
        case "completed":
            return "该阶段已经形成明确判断。"
        case "active":
            return "当前正在澄清这一阶段。"
        case "needsReview":
            return "该阶段需要回看和修正。"
        default:
            return "等待后续追问推进。"
        }
    }
}

private struct EvolutionItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let stageOrder: Int
    let actionType: String
    let isComplete: Bool

    var icon: String {
        switch actionType.lowercased() {
        case "reframe":
            return "arrow.triangle.2.circlepath"
        case "converge":
            return "arrow.down.right.and.arrow.up.left"
        case "boundaryshrink":
            return "rectangle.compress.vertical"
        default:
            return isComplete ? "checkmark" : "arrow.right"
        }
    }
}

private struct EvolutionStepCard: View {
    let item: EvolutionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(String(format: "%02d", item.stageOrder))
                    .font(BoardTypography.metadata.bold())
                    .monospacedDigit()
                    .foregroundStyle(BoardPalette.indigo)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(BoardPalette.indigo.opacity(0.09))
                    )

                Image(systemName: item.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(
                        item.isComplete
                            ? BoardPalette.mint
                            : Color.textTertiary
                    )
            }

            Text(item.title)
                .font(BoardTypography.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            Text(item.detail)
                .font(BoardTypography.cardBody)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(3)
        }
        .padding(14)
        .frame(width: 264, height: 142, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BoardPalette.elevatedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(BoardPalette.border, lineWidth: 0.8)
        )
    }
}

private struct EvolutionConnector: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(BoardPalette.indigo.opacity(0.28))
                .frame(width: 13, height: 1)

            Circle()
                .fill(BoardPalette.elevatedBackground)
                .frame(width: 9, height: 9)
                .overlay(
                    Circle().strokeBorder(
                        BoardPalette.indigo.opacity(0.45),
                        lineWidth: 1
                    )
                )

            Rectangle()
                .fill(BoardPalette.indigo.opacity(0.28))
                .frame(width: 13, height: 1)
        }
        .frame(width: 35)
    }
}

// MARK: - Shared Board Components

private struct BoardCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(BoardLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(
                cornerRadius: BoardLayout.cardCornerRadius,
                style: .continuous
            )
            .fill(BoardPalette.cardBackground)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: BoardLayout.cardCornerRadius,
                style: .continuous
            )
            .strokeBorder(BoardPalette.border, lineWidth: 0.8)
        )
        .shadow(
            color: Color.black.opacity(0.035),
            radius: 10,
            x: 0,
            y: 3
        )
    }
}

private struct BoardSectionHeader<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let trailing: Trailing?

    init(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(BoardPalette.indigo)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(BoardPalette.indigo.opacity(0.065))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BoardTypography.sectionTitle)
                    .foregroundStyle(Color.textPrimary)

                Text(subtitle)
                    .font(BoardTypography.sectionSubtitle)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if let trailing {
                trailing
            }
        }
    }
}

private extension BoardSectionHeader where Trailing == EmptyView {
    init(icon: String, title: String, subtitle: String) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }
}

private struct BoardEmptyHint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.textTertiary)

            Text(text)
                .font(BoardTypography.cardBody)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BoardPalette.subtleFill)
        )
    }
}

private enum BoardLayout {
    static let pageInset: CGFloat = 14
    static let sectionSpacing: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let cardCornerRadius: CGFloat = 14
}

private enum BoardTypography {
    static let sectionTitle = Font.title3.weight(.semibold)
    static let sectionSubtitle = Font.subheadline
    static let cardTitle = Font.headline.weight(.semibold)
    static let cardBody = Font.subheadline
    static let supporting = Font.footnote
    static let metadata = Font.caption
}

private enum BoardPalette {
    static let pageBackground = Color.panelBackground
    static let cardBackground = Color.appBackground
    static let elevatedBackground = Color.elevatedCardBackground
    static let subtleFill = Color.panelBackground
    static let border = AppTheme.Border.color

    static let indigo = Color(
        red: 0.37,
        green: 0.32,
        blue: 0.93
    )
    static let violet = Color(
        red: 0.47,
        green: 0.42,
        blue: 0.93
    )
    static let blue = Color(
        red: 0.34,
        green: 0.57,
        blue: 0.92
    )
    static let cyan = Color(
        red: 0.16,
        green: 0.68,
        blue: 0.63
    )
    static let green = Color(
        red: 0.22,
        green: 0.68,
        blue: 0.42
    )
    static let mint = Color(
        red: 0.20,
        green: 0.72,
        blue: 0.54
    )
    static let coral = Color(
        red: 0.94,
        green: 0.35,
        blue: 0.39
    )
    static let orange = Color(
        red: 0.96,
        green: 0.57,
        blue: 0.27
    )
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
    if score >= 16 { return BoardPalette.coral }
    if risk.impact >= 4 { return BoardPalette.orange }
    if risk.probability >= 4 { return BoardPalette.blue }
    return Color.textTertiary
}

#Preview("成果看板 · iPad 横屏") {
    VisualBoardView(project: {
        let project = Project(
            name: "我想做一个智能狗窝",
            briefDescription: "我想做一个智能狗窝"
        )
        let brief = DesignBrief()
        brief.targetUser = "经常离家的养犬人"
        brief.painPoint = "主人不在家的焦虑"
        brief.useScenario = "主人外出时远程确认状态"
        brief.coreValue = "随时确认宠物安全与舒适"
        brief.differentiation = "先聚焦状态确认而非复杂互动"
        project.brief = brief
        project.stages = [
            ProgressStage(
                order: 1,
                name: "痛点与场景锚定",
                status: "active",
                completionRatio: 0.65
            ),
            ProgressStage(order: 2, name: "差异化价值提炼"),
            ProgressStage(order: 3, name: "项目边界划定"),
        ]
        return project
    }())
    .frame(width: 1366, height: 920)
}
