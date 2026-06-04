import SwiftUI
import SwiftData

/// The main thinking tree visualization.
/// Renders an organic radial tree showing the growth of the user's design thinking.
struct ThinkingTreeView: View {
    let project: Project

    // Layout
    private let engine = TreeLayoutEngine(stageRadius: 170, fieldRadius: 310, stageFanDegrees: 24)
    private let builder = TreeBuilder()

    // Interaction state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectedNode: TreeNode?
    @State private var highlightStage: Int?

    var body: some View {
        GeometryReader { geo in
            let treeData = builder.build(project: project)
            let layoutData = engine.layout(treeData, in: engine.minimumContentSize())

            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                // Scrollable / zoomable tree content
                ZStack {
                    Canvas { context, size in
                        drawConnections(context: context, data: layoutData)
                        drawDecorations(context: context, data: layoutData)
                    }
                    .frame(
                        width: engine.minimumContentSize().width,
                        height: engine.minimumContentSize().height
                    )

                    ForEach(visibleNodes(layoutData)) { node in
                        TreeNodeView(node: node) {
                            withAnimation(AppTheme.Animation.standard) {
                                selectedNode = node
                            }
                        }
                        .position(node.position)
                    }
                }
                .frame(
                    width: engine.minimumContentSize().width,
                    height: engine.minimumContentSize().height
                )
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .gesture(magnificationGesture)
                .simultaneousGesture(panGesture)

                // Overlay controls
                VStack {
                    filterBar(data: layoutData)
                    Spacer()
                    TreeLegendView()
                        .padding(.trailing, AppTheme.spacingLarge)
                        .padding(.bottom, AppTheme.spacingLarge)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .onAppear {
                let contentSize = engine.minimumContentSize()
                let fitScale = min(
                    geo.size.width / contentSize.width,
                    geo.size.height / contentSize.height
                ) * 0.92
                scale = max(fitScale, 0.4)
                lastScale = scale
            }
        }
        .sheet(item: $selectedNode) { node in
            ThinkingNodeDetailSheet(node: node, project: project)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Visible Nodes (with optional stage filter)

    private func visibleNodes(_ data: TreeData) -> [TreeNode] {
        guard let filter = highlightStage else { return data.nodes }
        return data.nodes.filter { node in
            node.kind == .root || node.stageOrder == filter || node.stageOrder == nil
        }
    }

    private func visibleEdges(_ data: TreeData) -> [TreeEdge] {
        guard highlightStage != nil else { return data.edges }
        let visibleIDs = Set(visibleNodes(data).map { $0.id })
        return data.edges.filter { visibleIDs.contains($0.fromID) && visibleIDs.contains($0.toID) }
    }

    // MARK: - Canvas Drawing

    private func drawConnections(context: GraphicsContext, data: TreeData) {
        let edges = visibleEdges(data)
        for edge in edges {
            guard let fromNode = data.node(for: edge.fromID),
                  let toNode = data.node(for: edge.toID) else { continue }

            let path = bezierPath(from: fromNode.position, to: toNode.position)

            switch edge.style {
            case .branch:
                context.stroke(
                    path,
                    with: .color(Color.textTertiary.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
            case .twig:
                context.stroke(
                    path,
                    with: .color(Color.textTertiary.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
            case .ghost:
                context.stroke(
                    path,
                    with: .color(Color.stageNotStarted.opacity(0.20)),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [5, 4])
                )
            }
        }
    }

    private func drawDecorations(context: GraphicsContext, data: TreeData) {
        guard let root = data.nodes.first(where: { $0.kind == .root }) else { return }
        let glowRect = CGRect(
            x: root.position.x - 50,
            y: root.position.y - 50,
            width: 100, height: 100
        )
        context.fill(
            Circle().path(in: glowRect),
            with: .radialGradient(
                Gradient(colors: [Color.primaryAccent.opacity(0.08), .clear]),
                center: root.position,
                startRadius: 0,
                endRadius: 50
            )
        )

        for node in data.nodes where node.kind == .stage && node.nodeColor == .primaryAccent {
            let pulseRect = CGRect(
                x: node.position.x - 35,
                y: node.position.y - 35,
                width: 70, height: 70
            )
            context.fill(
                Circle().path(in: pulseRect),
                with: .radialGradient(
                    Gradient(colors: [Color.primaryAccent.opacity(0.10), .clear]),
                    center: node.position,
                    startRadius: 0,
                    endRadius: 35
                )
            )
        }
    }

    private func bezierPath(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)

        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dist = sqrt(dx * dx + dy * dy)
        let curvature = min(dist * 0.3, 60)

        let nx = -dy / max(dist, 1)
        let ny = dx / max(dist, 1)

        let cp1 = CGPoint(x: midX + nx * curvature * 0.3, y: midY + ny * curvature * 0.3)
        let cp2 = CGPoint(x: midX - nx * curvature * 0.1, y: midY - ny * curvature * 0.1)

        path.addCurve(to: to, control1: cp1, control2: cp2)
        return path
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 0.3), 2.5)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    // MARK: - Filter Bar

    private func filterBar(data: TreeData) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacingSmall) {
                filterChip(label: "全部", stage: nil)

                ForEach(StageDefinition.all, id: \.order) { def in
                    let hasFilledFields = def.briefFields.contains { field in
                        data.nodes.contains { $0.field == field && !$0.isGhost }
                    }
                    filterChip(label: "\(def.order). \(def.shortSubtitle)", stage: def.order)
                        .opacity(hasFilledFields ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, AppTheme.spacingLarge)
            .padding(.vertical, AppTheme.spacingSmall)
        }
        .background(.ultraThinMaterial)
    }

    private func filterChip(label: String, stage: Int?) -> some View {
        let isSelected = highlightStage == stage
        return Button {
            withAnimation(AppTheme.Animation.standard) {
                highlightStage = (highlightStage == stage) ? nil : stage
            }
        } label: {
            Text(label)
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.primaryAccent : Color.primaryAccent.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let project = Project(
        name: "智能校园导航助手",
        briefDescription: "帮助大学新生在复杂校园中快速找到目的地的智能导航应用"
    )
    let brief = DesignBrief(
        targetUser: "大一新生，尤其是来自外地的学生",
        painPoint: "校园面积大、建筑命名混乱，新生经常找不到教室和办公室",
        useScenario: "开学第一周，新生需要在 10 分钟内从宿舍赶到陌生的教学楼",
        coreValue: "基于 AR 的室内导航，解决 GPS 在建筑内失灵的问题",
        differentiation: "不同于百度/高德地图，专注室内场景 + 校园 POI 数据",
        mvpFeatures: "AR 导航 + POI 搜索 + 课表导入",
        technicalModules: "ARKit + CoreLocation + 本地 SQLite POI 数据库"
    )
    project.brief = brief

    brief.boundaryItems = [
        BoundaryItem(content: "AR 实时导航箭头", isIncluded: true),
        BoundaryItem(content: "校园 POI 搜索", isIncluded: true),
        BoundaryItem(content: "社交功能（找同学）", isIncluded: false)
    ]
    brief.successMetrics = [
        SuccessMetric(metric: "首次导航成功率", target: "≥ 90%"),
        SuccessMetric(metric: "平均找到目的地时间", target: "≤ 5 分钟")
    ]
    brief.risks = [
        RiskItem(desc: "AR 弱光识别不稳定", probability: 4, impact: 4, mitigation: "2D 地图备选")
    ]

    let stages = StageDefinition.all.map { def in
        ProgressStage(order: def.order, name: def.name)
    }
    stages[0].status = "completed"; stages[0].completionRatio = 1.0
    stages[1].status = "completed"; stages[1].completionRatio = 1.0
    stages[2].status = "completed"; stages[2].completionRatio = 1.0
    stages[3].status = "active"; stages[3].completionRatio = 0.67
    project.stages = stages

    return ThinkingTreeView(project: project)
}
