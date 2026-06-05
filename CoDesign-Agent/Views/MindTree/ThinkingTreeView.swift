import SwiftUI
import SwiftData

/// The main thinking tree visualization.
/// Renders an upward-growing tree showing the evolution of design thinking.
struct ThinkingTreeView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext

    // Layout
    private let engine = TreeLayoutEngine(
        stageHeight: 140,
        branchSpacing: 100,
        rootNodeHeight: 120,
        topPadding: 80
    )
    private let builder = TreeBuilder()

    // Interaction state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectedNode: TreeNode?
    @State private var editingNode: TreeNode?

    var body: some View {
        GeometryReader { geo in
            let treeData = builder.build(project: project)
            let maxStage = project.stages.map { $0.order }.max() ?? 9
            let layoutData = engine.layout(treeData, in: engine.minimumContentSize(maxStage: maxStage))

            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                // Scrollable / zoomable tree content
                ZStack {
                    Canvas { context, size in
                        drawEdges(context: context, data: layoutData)
                        drawDecorations(context: context, data: layoutData)
                    }
                    .frame(
                        width: engine.minimumContentSize(maxStage: maxStage).width,
                        height: engine.minimumContentSize(maxStage: maxStage).height
                    )

                    ForEach(layoutData.nodes) { node in
                        TreeNodeView(
                            node: node,
                            onTap: { selectedNode = node },
                            onEdit: { editingNode = node }
                        )
                        .position(node.position)
                    }
                }
                .frame(
                    width: engine.minimumContentSize(maxStage: maxStage).width,
                    height: engine.minimumContentSize(maxStage: maxStage).height
                )
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .gesture(magnificationGesture)
                .simultaneousGesture(panGesture)

                // Stage level indicators
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    ForEach((1...maxStage).reversed(), id: \.self) { stageOrder in
                        stageLevelIndicator(stageOrder: stageOrder, geo: geo)
                    }
                }
                .padding(.leading, AppTheme.spacingMedium)

                // Legend
                VStack {
                    Spacer()
                    TreeLegendView()
                        .padding(.trailing, AppTheme.spacingLarge)
                        .padding(.bottom, AppTheme.spacingLarge)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .onAppear {
                // Auto-generate thinking moments if missing (e.g. DB upgrade)
                if project.thinkingMoments.isEmpty, let ctx = project.modelContext {
                    project.ensureThinkingMoments(context: ctx)
                }

                // Auto-fit: scale to fit viewport
                let contentSize = engine.minimumContentSize(maxStage: maxStage)
                let fitScale = min(
                    geo.size.width / contentSize.width,
                    geo.size.height / contentSize.height
                ) * 0.85
                scale = max(fitScale, 0.3)
                lastScale = scale
            }
        }
        .sheet(item: $selectedNode) { node in
            ThinkingNodeDetailSheet(node: node, project: project)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingNode) { node in
            NodeEditSheet(node: node, project: project)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Stage Level Indicator

    private func stageLevelIndicator(stageOrder: Int, geo: GeometryProxy) -> some View {
        let stage = project.stages.first { $0.order == stageOrder }
        let statusColor: Color = {
            switch stage?.stageStatusValue ?? .notStarted {
            case .completed: return .success
            case .active: return .primaryAccent
            case .needsReview: return .warning
            case .notStarted: return .stageNotStarted
            }
        }()

        return HStack(spacing: AppTheme.spacingSmall) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text("阶段 \(stageOrder)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Canvas Drawing

    private func drawEdges(context: GraphicsContext, data: TreeData) {
        for edge in data.edges {
            guard let fromNode = data.node(for: edge.fromID),
                  let toNode = data.node(for: edge.toID) else { continue }

            let path = curvePath(from: fromNode.position, to: toNode.position)

            switch edge.style {
            case .active:
                context.stroke(
                    path,
                    with: .color(Color.primaryAccent.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
            case .archived:
                context.stroke(
                    path,
                    with: .color(Color(red: 0.6, green: 0.55, blue: 0.5).opacity(0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 4])
                )
            case .transition:
                context.stroke(
                    path,
                    with: .color(Color.warning.opacity(0.7)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            }
        }
    }

    private func drawDecorations(context: GraphicsContext, data: TreeData) {
        // Glow on active nodes
        for node in data.nodes where node.isActiveBranch && node.kind == .root {
            let glowRect = CGRect(
                x: node.position.x - 45,
                y: node.position.y - 45,
                width: 90, height: 90
            )
            context.fill(
                Circle().path(in: glowRect),
                with: .radialGradient(
                    Gradient(colors: [Color.primaryAccent.opacity(0.12), .clear]),
                    center: node.position,
                    startRadius: 0,
                    endRadius: 45
                )
            )
        }
    }

    private func curvePath(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)

        // Vertical curve (tree grows upward)
        let midY = (from.y + to.y) / 2
        let controlPoint1 = CGPoint(x: from.x, y: midY)
        let controlPoint2 = CGPoint(x: to.x, y: midY)

        path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)
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
