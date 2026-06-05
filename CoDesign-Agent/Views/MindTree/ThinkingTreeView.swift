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
    private let minimumScale: CGFloat = 0.3
    private let maximumScale: CGFloat = 2.5
    private let viewportTopMargin: CGFloat = 90
    private let viewportBottomMargin: CGFloat = 120

    // Interaction state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var originalScale: CGFloat = 1.0
    @State private var originalOffset: CGSize = .zero
    @State private var selectedNode: TreeNode?
    @State private var editingNode: TreeNode?
    @State private var hasInitializedViewport = false

    var body: some View {
        GeometryReader { geo in
            let treeData = builder.build(project: project)
            let maxStage = project.stages.map { $0.order }.max() ?? 9
            let contentSize = engine.minimumContentSize(maxStage: maxStage)
            let layoutData = engine.layout(treeData, in: contentSize)

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

                DispatchQueue.main.async {
                    resetOriginalViewport(maxStage: maxStage, viewportSize: geo.size)
                }
            }
        }
        .safeAreaInset(edge: .trailing, spacing: 0) {
            zoomSidebar
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
                scale = clampedScale(lastScale * value)
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

    // MARK: - Viewport

    private func initializeViewport(layoutData: TreeData, contentSize: CGSize, viewportSize: CGSize) {
        guard let rootNode = layoutData.nodes.first(where: { $0.kind == .root }) else {
            hasInitializedViewport = true
            return
        }

        let topNodeY = layoutData.nodes.map(\.position.y).min() ?? rootNode.position.y
        let verticalSpan = max(rootNode.position.y - topNodeY, 1)
        let availableHeight = max(viewportSize.height - viewportTopMargin - viewportBottomMargin, 1)
        let fittedScale = clampedScale(availableHeight / verticalSpan)

        let contentCenter = CGPoint(x: contentSize.width / 2, y: contentSize.height / 2)
        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let targetRootPosition = CGPoint(
            x: viewportSize.width / 2,
            y: viewportSize.height - viewportBottomMargin
        )
        let fittedOffset = CGSize(
            width: targetRootPosition.x - viewportCenter.x - (rootNode.position.x - contentCenter.x) * fittedScale,
            height: targetRootPosition.y - viewportCenter.y - (rootNode.position.y - contentCenter.y) * fittedScale
        )

        originalScale = fittedScale
        originalOffset = fittedOffset
        scale = fittedScale
        lastScale = fittedScale
        offset = fittedOffset
        lastOffset = fittedOffset
        hasInitializedViewport = true
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumScale), maximumScale)
    }

    private var zoomSidebar: some View {
        VStack {
            Spacer()
            zoomControl
            Spacer()
        }
        .frame(width: 76)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background(Color.cardBackground.opacity(0.92))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.primaryAccent.opacity(0.18))
                .frame(width: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 12, x: -3, y: 0)
    }

    private var zoomControl: some View {
        VStack(spacing: 10) {
            Button {
                setScale(scale + 0.1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("放大")

            zoomTrack
                .frame(width: 36, height: 180)

            Button {
                setScale(scale - 0.1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("缩小")

            Button {
                resetToOriginalViewport()
            } label: {
                Text("原始")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .frame(width: 40, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("原始缩放")

            Text("\(Int(scale * 100))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.textSecondary)
                .monospacedDigit()
                .frame(width: 44)
        }
        .foregroundStyle(Color.primaryAccent)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.cardBackground.opacity(0.96))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primaryAccent.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Color.primaryAccent.opacity(0.16), radius: 18, y: 6)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
    }

    private var zoomTrack: some View {
        GeometryReader { proxy in
            let trackHeight = proxy.size.height
            let progress = (scale - minimumScale) / (maximumScale - minimumScale)
            let knobY = (1 - progress) * trackHeight

            ZStack(alignment: .top) {
                Capsule(style: .continuous)
                    .fill(Color.primaryAccent.opacity(0.12))
                    .frame(width: 8)
                    .frame(maxHeight: .infinity)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.primaryAccent, Color.secondaryAccent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: max(trackHeight - knobY, 0))
                    .offset(y: knobY)

                Circle()
                    .fill(Color.primaryAccent)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                    )
                    .shadow(color: Color.primaryAccent.opacity(0.35), radius: 8, y: 3)
                    .offset(y: knobY - 11)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let y = min(max(value.location.y, 0), trackHeight)
                        let nextProgress = 1 - y / trackHeight
                        setScale(minimumScale + nextProgress * (maximumScale - minimumScale))
                    }
            )
            .accessibilityLabel("缩放条")
        }
    }

    private func setScale(_ value: CGFloat) {
        scale = clampedScale(value)
        lastScale = scale
    }

    private func resetToOriginalViewport() {
        scale = originalScale
        lastScale = originalScale
        offset = originalOffset
        lastOffset = originalOffset
    }

    private func resetOriginalViewport(maxStage: Int, viewportSize: CGSize) {
        let contentSize = engine.minimumContentSize(maxStage: maxStage)
        let treeData = builder.build(project: project)
        let layoutData = engine.layout(treeData, in: contentSize)
        initializeViewport(
            layoutData: layoutData,
            contentSize: contentSize,
            viewportSize: viewportSize
        )
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
