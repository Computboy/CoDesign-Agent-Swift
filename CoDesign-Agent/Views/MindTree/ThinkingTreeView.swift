import SwiftUI
import SwiftData

/// Design-thinking growth projection.
/// The workspace remains the primary interaction; this tree visualizes how
/// questions, answers, decisions, evidence, and revisions accumulate.
struct ThinkingTreeView: View {
    enum DisplayMode {
        case embedded
        case standalone
    }

    let project: Project
    var mode: DisplayMode = .standalone

    @Environment(\.modelContext) private var modelContext

    @State private var expandedStageOrders: Set<Int> = []
    @State private var selectedNode: TreeNode?
    @State private var editingNode: TreeNode?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var hasInitializedViewport = false
    @State private var lastViewportSize: CGSize = .zero

    private var minimumScale: CGFloat {
        mode == .embedded ? 0.34 : 0.28
    }

    private var maximumScale: CGFloat {
        mode == .embedded ? 1.8 : 2.2
    }

    var body: some View {
        GeometryReader { geo in
            let graph = layoutGraph(for: geo.size)

            ZStack {
                treeBackground

                ZStack {
                    Canvas { context, _ in
                        drawEdges(context: context, graph: graph)
                    }
                    .frame(width: graph.contentSize.width, height: graph.contentSize.height)

                    edgeHitAreas(graph: graph)

                    ForEach(graph.nodes) { node in
                        TreeNodeView(node: node) {
                            handleTap(node)
                        }
                        .position(node.position)
                        .zIndex(zIndex(for: node))
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.45)
                                .onEnded { _ in
                                    if node.isEditable {
                                        editingNode = node
                                    }
                                }
                        )
                    }
                }
                .frame(width: graph.contentSize.width, height: graph.contentSize.height)
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .gesture(panGesture)
                .simultaneousGesture(magnificationGesture)
            }
            .overlay(alignment: .topLeading) {
                treeHeader
                    .padding(mode == .embedded ? 12 : AppTheme.spacingLarge)
            }
            .overlay(alignment: .topTrailing) {
                treeToolbar
                    .padding(mode == .embedded ? 10 : AppTheme.spacingLarge)
            }
            .onAppear {
                lastViewportSize = geo.size
                seedExpandedStageIfNeeded()
                if !hasInitializedViewport {
                    DispatchQueue.main.async {
                        locateCurrentStage(in: geo.size, preserveScale: false)
                    }
                }
            }
            .onChange(of: geo.size) { _, newSize in
                lastViewportSize = newSize
                guard hasInitializedViewport else { return }
                DispatchQueue.main.async {
                    locateCurrentStage(in: newSize, preserveScale: true)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: mode == .embedded ? AppTheme.cornerRadiusLarge : 0, style: .continuous))
        .overlay {
            if mode == .embedded {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
            }
        }
        .coDesignShadow(mode == .embedded ? .card : .elevated)
        .sheet(item: $selectedNode) { node in
            ThinkingNodeDetailSheet(
                node: node,
                project: project,
                onAdoptEvidence: adoptEvidence
            )
        }
        .sheet(item: $editingNode) { node in
            NodeEditSheet(node: node, project: project)
        }
    }

    // MARK: - Graph

    private func layoutGraph(for viewport: CGSize) -> TreeData {
        let evidence = evidenceResourcesByStage()
        let raw = TreeBuilder().build(
            project: project,
            expandedStageOrders: expandedStageOrders,
            evidenceResourcesByStage: evidence,
            visibleStageLimit: visibleStageLimit
        )
        let engine = layoutEngine(for: viewport)
        return engine.layout(raw, in: engine.minimumContentSize(maxStage: visibleStageLimit))
    }

    private var visibleStageLimit: Int {
        mode == .embedded ? project.currentStageOrder : 9
    }

    private func layoutEngine(for viewport: CGSize) -> TreeLayoutEngine {
        switch mode {
        case .embedded:
            let stageSpacing = clamp(
                (viewport.height - 220) / CGFloat(max(visibleStageLimit, 1)),
                min: 145,
                max: 180
            )
            return TreeLayoutEngine(
                stageSpacing: stageSpacing,
                sideBranchSpacing: 220,
                topPadding: 82,
                bottomPadding: 112,
                contentWidth: max(viewport.width * 1.24, 720)
            )
        case .standalone:
            return TreeLayoutEngine(
                stageSpacing: 150,
                sideBranchSpacing: 235,
                topPadding: 110,
                bottomPadding: 150,
                contentWidth: max(viewport.width * 1.45, 1180)
            )
        }
    }

    private func evidenceResourcesByStage() -> [Int: [ResourceCard]] {
        let visibleStages = mode == .embedded
            ? expandedStageOrders
            : expandedStageOrders.union([project.currentStageOrder])
        var result: [Int: [ResourceCard]] = [:]
        let limit = mode == .embedded ? 2 : 3
        let service = ResourceRecommendationService()

        for order in visibleStages where (1...9).contains(order) {
            result[order] = service.recommend(
                currentStageOrder: order,
                brief: project.brief,
                recentMessage: project.latestConversationText,
                limit: limit
            )
        }
        return result
    }

    // MARK: - Header and Controls

    private var treeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "tree")
                    .font(.system(size: mode == .embedded ? 12 : 15, weight: .semibold))
                    .foregroundStyle(Color.primaryAccent)

                Text("思维树")
                    .font(mode == .embedded ? AppTheme.Typography.caption.weight(.bold) : AppTheme.Typography.subheadline.weight(.bold))
                    .foregroundStyle(Color.textPrimary)

                if mode == .embedded {
                    Text("投影")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.primaryAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primaryAccent.opacity(0.09)))
                }
            }

            Text("Stage \(project.currentStageOrder) · \(currentStageName)")
                .font(.system(size: mode == .embedded ? 10 : 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textTertiary)

            if let review = needsReviewNotice {
                Text(review)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.warning)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.warning.opacity(0.10))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cardBackground.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.10), lineWidth: 1)
        )
    }

    private var treeToolbar: some View {
        HStack(spacing: 8) {
            toolbarButton("定位当前阶段", icon: "scope") {
                expandedStageOrders.insert(project.currentStageOrder)
                locateCurrentStage(in: lastViewportSize, preserveScale: true)
            }

            toolbarButton("重置视图", icon: "arrow.counterclockwise") {
                resetViewport(in: lastViewportSize)
            }

            if mode == .standalone {
                toolbarButton("\(Int(scale * 100))%", icon: "plus.magnifyingglass") {
                    setScale(scale + 0.12)
                }
            }
        }
        .padding(7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.cardBackground.opacity(0.94))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.12), lineWidth: 1)
        )
    }

    private func toolbarButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.primaryAccent)
            .padding(.horizontal, mode == .embedded ? 8 : 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.primaryAccent.opacity(0.075)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var treeBackground: some View {
        LinearGradient(
            colors: [
                Color.panelBackground,
                Color.appBackground,
                Color.softAccentBackground.opacity(0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var currentStageName: String {
        StageDefinition.all.first { $0.order == project.currentStageOrder }?.shortSubtitle ?? "设计澄清"
    }

    private var needsReviewNotice: String? {
        guard let stage = project.stages.sorted(by: { $0.order < $1.order }).first(where: { $0.status == "needsReview" }) else {
            return nil
        }
        return "已回溯，请从 Stage \(stage.order) 继续澄清"
    }

    // MARK: - Interaction

    private func handleTap(_ node: TreeNode) {
        if node.kind == .stage, let order = node.stageOrder {
            toggleStage(order)
        }
        selectedNode = node
    }

    private func toggleStage(_ order: Int) {
        withAnimation(AppTheme.Animation.spring) {
            if expandedStageOrders.contains(order) {
                expandedStageOrders.remove(order)
            } else {
                expandedStageOrders.insert(order)
            }
        }
    }

    private func seedExpandedStageIfNeeded() {
        guard expandedStageOrders.isEmpty else { return }
        guard mode == .standalone else { return }
        expandedStageOrders.insert(project.currentStageOrder)
    }

    private func adoptEvidence(_ resource: ResourceCard, stageOrder: Int) {
        let duplicate = project.thinkingMoments.contains { moment in
            moment.stageOrder == stageOrder &&
            moment.momType == "evidence" &&
            moment.content == resource.title &&
            moment.isActiveBranch
        }
        guard !duplicate else {
            selectedNode = nil
            return
        }

        let moment = ThinkingMoment(
            momType: "evidence",
            content: resource.title,
            stageOrder: stageOrder,
            relatedField: nil,
            timestamp: Date(),
            isActiveBranch: true
        )
        modelContext.insert(moment)
        project.thinkingMoments.append(moment)
        project.updatedAt = Date()
        expandedStageOrders.insert(stageOrder)
        try? modelContext.save()
        selectedNode = nil
    }

    @ViewBuilder
    private func edgeHitAreas(graph: TreeData) -> some View {
        ForEach(graph.edges.filter { $0.togglesStageOrder != nil }) { edge in
            if let from = graph.node(for: edge.fromID),
               let to = graph.node(for: edge.toID),
               let stageOrder = edge.togglesStageOrder {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 190, height: max(abs(from.position.y - to.position.y), 42))
                    .contentShape(Rectangle())
                    .position(
                        CGPoint(
                            x: (from.position.x + to.position.x) / 2,
                            y: (from.position.y + to.position.y) / 2
                        )
                    )
                    .onTapGesture {
                        toggleStage(stageOrder)
                    }
                    .zIndex(1)
            }
        }
    }

    private func zIndex(for node: TreeNode) -> Double {
        switch node.kind {
        case .root: return 6
        case .stage: return 5
        case .field, .process, .evidence, .revision: return 4
        }
    }

    // MARK: - Drawing

    private func drawEdges(context: GraphicsContext, graph: TreeData) {
        for edge in graph.edges {
            guard let from = graph.node(for: edge.fromID),
                  let to = graph.node(for: edge.toID) else {
                continue
            }

            var path = Path()
            path.move(to: from.position)

            let dy = abs(to.position.y - from.position.y)
            let isTrunk = from.kind == .root || from.kind == .stage && to.kind == .stage
            if isTrunk {
                path.addLine(to: to.position)
            } else {
                path.addCurve(
                    to: to.position,
                    control1: CGPoint(x: from.position.x, y: from.position.y - max(dy * 0.34, 24)),
                    control2: CGPoint(x: to.position.x, y: to.position.y + max(dy * 0.18, 18))
                )
            }

            context.stroke(
                path,
                with: .color(edgeColor(edge, to: to)),
                style: edgeStroke(edge)
            )
        }
    }

    private func edgeColor(_ edge: TreeEdge, to node: TreeNode) -> Color {
        switch edge.style {
        case .active:
            return node.kind == .stage ? node.nodeColor.opacity(0.72) : Color.primaryAccent.opacity(0.52)
        case .archived:
            return Color(red: 0.58, green: 0.53, blue: 0.48).opacity(0.50)
        case .transition:
            return Color.warning.opacity(0.58)
        case .ghost:
            return Color.stageNotStarted.opacity(0.34)
        case .evidence:
            return Color.secondaryAccent.opacity(0.38)
        }
    }

    private func edgeStroke(_ edge: TreeEdge) -> StrokeStyle {
        switch edge.style {
        case .active:
            return StrokeStyle(lineWidth: 2.2, lineCap: .round)
        case .transition:
            return StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [7, 5])
        case .archived:
            return StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 5])
        case .ghost:
            return StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [4, 6])
        case .evidence:
            return StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 5])
        }
    }

    // MARK: - Viewport

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
        DragGesture(minimumDistance: 1)
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

    private func locateCurrentStage(in viewport: CGSize, preserveScale: Bool) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        seedExpandedStageIfNeeded()
        let graph = layoutGraph(for: viewport)
        let targetID = TreeBuilder.stageNodeID(project.currentStageOrder)
        guard let node = graph.node(for: targetID) else { return }

        let nextScale = preserveScale ? scale : max(fitScale(for: graph, viewport: viewport), mode == .embedded ? 0.46 : 0.58)
        let desired = CGPoint(x: viewport.width / 2, y: viewport.height * (mode == .embedded ? 0.48 : 0.50))
        let nextOffset = offsetToPlace(
            node.position,
            at: desired,
            graph: graph,
            viewport: viewport,
            scale: nextScale
        )

        withAnimation(AppTheme.Animation.standard) {
            scale = clampedScale(nextScale)
            lastScale = scale
            offset = nextOffset
            lastOffset = nextOffset
            hasInitializedViewport = true
        }
    }

    private func resetViewport(in viewport: CGSize) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let graph = layoutGraph(for: viewport)
        let nextScale = fitScale(for: graph, viewport: viewport)

        withAnimation(AppTheme.Animation.standard) {
            scale = nextScale
            lastScale = nextScale
            offset = .zero
            lastOffset = .zero
            hasInitializedViewport = true
        }
    }

    private func fitScale(for graph: TreeData, viewport: CGSize) -> CGFloat {
        let horizontalInset: CGFloat = mode == .embedded ? 34 : 72
        let verticalInset: CGFloat = mode == .embedded ? 42 : 90
        let widthScale = max(viewport.width - horizontalInset, 1) / max(graph.contentSize.width, 1)
        let heightScale = max(viewport.height - verticalInset, 1) / max(graph.contentSize.height, 1)
        return clampedScale(min(widthScale, heightScale))
    }

    private func offsetToPlace(
        _ point: CGPoint,
        at desired: CGPoint,
        graph: TreeData,
        viewport: CGSize,
        scale: CGFloat
    ) -> CGSize {
        let contentCenter = CGPoint(x: graph.contentSize.width / 2, y: graph.contentSize.height / 2)
        let viewportCenter = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        return CGSize(
            width: desired.x - viewportCenter.x - (point.x - contentCenter.x) * scale,
            height: desired.y - viewportCenter.y - (point.y - contentCenter.y) * scale
        )
    }

    private func setScale(_ value: CGFloat) {
        withAnimation(AppTheme.Animation.quick) {
            scale = clampedScale(value)
            lastScale = scale
        }
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumScale), maximumScale)
    }

    private func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, lower), upper)
    }
}

#Preview {
    let project = Project(
        name: "智能校园导航助手",
        briefDescription: "帮助大学新生在复杂校园中快速找到目的地的智能导航应用"
    )
    project.stages = StageDefinition.all.map { definition in
        ProgressStage(
            order: definition.order,
            name: definition.name,
            status: definition.order < 3 ? "completed" : (definition.order == 3 ? "active" : "notStarted"),
            completionRatio: definition.order < 3 ? 1 : 0
        )
    }
    project.thinkingMoments = [
        ThinkingMoment(momType: "question", content: "你希望先解决哪个具体场景？", stageOrder: 3),
        ThinkingMoment(momType: "answer", content: "先覆盖宿舍区到教学楼的路线", stageOrder: 3),
        ThinkingMoment(momType: "decision", content: "确认：项目边界", stageOrder: 3, relatedField: BriefField.boundaryItems.rawValue)
    ]
    return ThinkingTreeView(project: project)
}
