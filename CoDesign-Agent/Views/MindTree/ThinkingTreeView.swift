import SwiftUI
import SwiftData

/// The main thinking tree visualization.
/// Renders an upward-growing tree showing the evolution of design thinking.
struct ThinkingTreeView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext

    // Layout
    private let engine = TreeLayoutEngine(
        stageHeight: 200,
        branchSpacing: 180,
        rootNodeHeight: 120,
        topPadding: 100,
        contentWidth: 2000
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
                // Premium background with subtle gradient
                LinearGradient(
                    colors: [
                        Color.appBackground,
                        Color(red: 0.96, green: 0.97, blue: 0.99)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
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

                // Stage level indicators (floating left panel)
                VStack(alignment: .leading, spacing: 3) {
                    Spacer()
                    ForEach((1...maxStage).reversed(), id: \.self) { stageOrder in
                        stageLevelIndicator(stageOrder: stageOrder, geo: geo)
                    }
                }
                .padding(.leading, 16)

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
                .presentationDetents([.medium, .large])
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

        return HStack(spacing: 10) {
            // Gradient dot with subtle glow
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .blur(radius: 3)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [statusColor, statusColor.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 9, height: 9)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                    )
            }

            Text("阶段 \(stageOrder)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Canvas Drawing

    private func drawEdges(context: GraphicsContext, data: TreeData) {
        for edge in data.edges {
            guard let fromNode = data.node(for: edge.fromID),
                  let toNode = data.node(for: edge.toID) else { continue }

            let path = curvePath(from: fromNode.position, to: toNode.position)

            switch edge.style {
            case .active:
                // Gradient stroke for active branches
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.primaryAccent.opacity(0.6),
                            Color.secondaryAccent.opacity(0.5)
                        ]),
                        startPoint: fromNode.position,
                        endPoint: toNode.position
                    ),
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                )

            case .archived:
                // Muted dashed lines for archived branches
                context.stroke(
                    path,
                    with: .color(Color(red: 0.58, green: 0.53, blue: 0.48).opacity(0.3)),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [6, 6])
                )

            case .transition:
                // Warm transition edge (edit point)
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.warning.opacity(0.65),
                            Color(red: 0.92, green: 0.68, blue: 0.32).opacity(0.5)
                        ]),
                        startPoint: fromNode.position,
                        endPoint: toNode.position
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
            }
        }
    }

    private func drawDecorations(context: GraphicsContext, data: TreeData) {
        // Soft glow on active root node
        for node in data.nodes where node.isActiveBranch && node.kind == .root {
            let glowRect = CGRect(
                x: node.position.x - 65,
                y: node.position.y - 65,
                width: 130, height: 130
            )
            context.fill(
                Circle().path(in: glowRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.primaryAccent.opacity(0.2),
                        Color.secondaryAccent.opacity(0.1),
                        .clear
                    ]),
                    center: node.position,
                    startRadius: 0,
                    endRadius: 65
                )
            )
        }

        // Subtle highlight on active stage nodes
        for node in data.nodes where node.isActiveBranch && node.kind == .stage {
            let glowRect = CGRect(
                x: node.position.x - 30,
                y: node.position.y - 30,
                width: 60, height: 60
            )
            context.fill(
                Circle().path(in: glowRect),
                with: .radialGradient(
                    Gradient(colors: [
                        node.nodeColor.opacity(0.12),
                        .clear
                    ]),
                    center: node.position,
                    startRadius: 0,
                    endRadius: 30
                )
            )
        }
    }

    private func curvePath(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)

        // Organic S-curve with variable curvature
        let dy = abs(from.y - to.y)
        let dx = abs(from.x - to.x)
        let distance = sqrt(dx * dx + dy * dy)

        // Curve strength scales with distance for more natural flow
        let curveStrength = min(distance * 0.35, 80)

        // Vertical-biased control points (tree grows upward)
        let controlPoint1 = CGPoint(
            x: from.x + (dx > 50 ? (to.x > from.x ? 10 : -10) : 0),
            y: from.y - curveStrength * 0.7
        )
        let controlPoint2 = CGPoint(
            x: to.x + (dx > 50 ? (from.x > to.x ? 10 : -10) : 0),
            y: to.y + curveStrength * 0.7
        )

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

    // Add thinking moments for preview
    let root = ThinkingMoment(momType: "seed", content: "项目想法诞生", stageOrder: 0)
    project.thinkingMoments.append(root)

    let s1 = ThinkingMoment(momType: "branch", content: "探索痛点", stageOrder: 1, parentMomentID: root.id)
    project.thinkingMoments.append(s1)

    let f1 = ThinkingMoment(momType: "deepen", content: "目标用户", stageOrder: 1,
                            relatedField: BriefField.targetUser.rawValue, parentMomentID: s1.id)
    let f2 = ThinkingMoment(momType: "deepen", content: "核心痛点", stageOrder: 1,
                            relatedField: BriefField.painPoint.rawValue, parentMomentID: s1.id)
    let f3 = ThinkingMoment(momType: "deepen", content: "使用场景", stageOrder: 1,
                            relatedField: BriefField.useScenario.rawValue, parentMomentID: s1.id)
    project.thinkingMoments.append(f1)
    project.thinkingMoments.append(f2)
    project.thinkingMoments.append(f3)

    let s2 = ThinkingMoment(momType: "branch", content: "差异化价值", stageOrder: 2, parentMomentID: root.id)
    project.thinkingMoments.append(s2)

    let f4 = ThinkingMoment(momType: "deepen", content: "核心价值", stageOrder: 2,
                            relatedField: BriefField.coreValue.rawValue, parentMomentID: s2.id)
    let f5 = ThinkingMoment(momType: "deepen", content: "差异化", stageOrder: 2,
                            relatedField: BriefField.differentiation.rawValue, parentMomentID: s2.id)
    project.thinkingMoments.append(f4)
    project.thinkingMoments.append(f5)

    let s3 = ThinkingMoment(momType: "converge", content: "划定边界", stageOrder: 3, parentMomentID: root.id)
    project.thinkingMoments.append(s3)

    let s4 = ThinkingMoment(momType: "branch", content: "功能拆解", stageOrder: 4, parentMomentID: root.id)
    project.thinkingMoments.append(s4)

    let f6 = ThinkingMoment(momType: "deepen", content: "MVP", stageOrder: 4,
                            relatedField: BriefField.mvpFeatures.rawValue, parentMomentID: s4.id)
    let f7 = ThinkingMoment(momType: "deepen", content: "技术选型", stageOrder: 4,
                            relatedField: BriefField.technicalModules.rawValue, parentMomentID: s4.id)
    project.thinkingMoments.append(f6)
    project.thinkingMoments.append(f7)

    return ThinkingTreeView(project: project)
}
