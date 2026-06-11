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

    @State private var expandedTransitionOrders: Set<Int> = []
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

                    edgeHitAreas(graph: graph, viewport: geo.size)

                    ForEach(graph.nodes) { node in
                        let nodeView = TreeNodeView(node: node) {
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

                        #if os(iOS)
                        nodeView
                        #else
                        nodeView
                        .popover(
                            isPresented: Binding(
                                get: { selectedNode?.id == node.id },
                                set: { isPresented in
                                    if !isPresented && selectedNode?.id == node.id {
                                        selectedNode = nil
                                    }
                                }
                            ),
                            attachmentAnchor: .rect(.bounds),
                            arrowEdge: .trailing
                        ) {
                            nodeDetailPopover(node)
                        }
                        #endif
                    }
                }
                .frame(width: graph.contentSize.width, height: graph.contentSize.height)
                .scaleEffect(scale, anchor: .topLeading)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            .overlay(alignment: .topLeading) {
                rootCenteredZoomControl(graph: graph, viewport: geo.size)
                    .position(zoomControlCenter(in: geo.size))
            }
            .onAppear {
                lastViewportSize = geo.size
                if !hasInitializedViewport {
                    DispatchQueue.main.async {
                        fitTreeToViewport(in: geo.size, preserveScale: false)
                    }
                }
            }
            .onChange(of: geo.size) { _, newSize in
                lastViewportSize = newSize
                guard hasInitializedViewport else { return }
                DispatchQueue.main.async {
                    fitTreeToViewport(in: newSize, preserveScale: true)
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
        #if os(iOS)
        .sheet(item: $selectedNode) { node in
            nodeDetailSheet(node)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        #endif
        .sheet(item: $editingNode) { node in
            NodeEditSheet(node: node, project: project)
                .presentationDragIndicator(.visible)
        }
    }

    private func nodeDetailPopover(_ node: TreeNode) -> some View {
        ThinkingNodeDetailSheet(
            node: node,
            project: project,
            onAdoptEvidence: adoptEvidence,
            onEditNode: beginEditing
        )
        .frame(
            minWidth: mode == .embedded ? 340 : 420,
            idealWidth: mode == .embedded ? 420 : 540,
            maxWidth: mode == .embedded ? 480 : 620,
            minHeight: 360,
            idealHeight: mode == .embedded ? 520 : 620,
            maxHeight: mode == .embedded ? 620 : 720
        )
        #if os(iOS)
        .presentationCompactAdaptation(.popover)
        #endif
    }

    private func nodeDetailSheet(_ node: TreeNode) -> some View {
        ThinkingNodeDetailSheet(
            node: node,
            project: project,
            onAdoptEvidence: adoptEvidence,
            onEditNode: beginEditing
        )
    }

    // MARK: - Graph

    private func layoutGraph(for viewport: CGSize) -> TreeData {
        layoutGraph(for: viewport, expandedTransitions: expandedTransitionOrders)
    }

    private func layoutGraph(for viewport: CGSize, expandedTransitions: Set<Int>) -> TreeData {
        let effectiveExpandedTransitions = expandedTransitions
        let evidence = evidenceResourcesByStage(expandedTransitions: effectiveExpandedTransitions)
        let raw = TreeBuilder().build(
            project: project,
            expandedTransitionOrders: effectiveExpandedTransitions,
            evidenceResourcesByStage: evidence,
            visibleStageLimit: visibleStageLimit
        )
        let engine = layoutEngine(for: viewport)
        return engine.layout(raw, in: engine.minimumContentSize(maxStage: visibleStageLimit))
    }

    private var visibleStageLimit: Int {
        guard mode == .embedded else { return 9 }
        let expandedMaxOrder = expandedTransitionOrders.max() ?? project.currentStageOrder
        return min(max(project.currentStageOrder, expandedMaxOrder), 9)
    }

    private func layoutEngine(for viewport: CGSize) -> TreeLayoutEngine {
        switch mode {
        case .embedded:
            let stageSpacing = clamp(
                (viewport.height - 170) / CGFloat(max(visibleStageLimit, 1)),
                min: 96,
                max: 132
            )
            return TreeLayoutEngine(
                stageSpacing: stageSpacing,
                sideBranchSpacing: 320,
                sideNodeVerticalSpacing: 42,
                topPadding: 82,
                bottomPadding: 112,
                contentWidth: max(viewport.width * 2.35, 1_260)
            )
        case .standalone:
            return TreeLayoutEngine(
                stageSpacing: 146,
                sideBranchSpacing: 410,
                sideNodeVerticalSpacing: 46,
                topPadding: 110,
                bottomPadding: 150,
                contentWidth: max(viewport.width * 1.9, 1_520)
            )
        }
    }

    private func evidenceResourcesByStage(expandedTransitions: Set<Int>) -> [Int: [ResourceCard]] {
        let visibleStages = mode == .embedded
            ? expandedTransitions.union([project.currentStageOrder])
            : expandedTransitions.union([project.currentStageOrder])
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
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.cardBackground.opacity(AppTheme.Opacity.nearFull))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(AppTheme.Opacity.light), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var treeToolbar: some View {
        if mode == .embedded {
            HStack(spacing: 6) {
                compactToolbarButton("定位当前阶段", icon: "scope") {
                    locateCurrentStage(in: lastViewportSize, preserveScale: true)
                }

                compactToolbarButton("重置视图", icon: "arrow.counterclockwise") {
                    resetViewport(in: lastViewportSize)
                }
            }
            .padding(5)
            .fixedSize()
            .background(
                Capsule(style: .continuous)
                    .fill(Color.cardBackground.opacity(0.94))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primaryAccent.opacity(0.12), lineWidth: 1)
            )
        } else {
            HStack(spacing: 8) {
                toolbarButton("定位当前阶段", icon: "scope") {
                    locateCurrentStage(in: lastViewportSize, preserveScale: true)
                }

                toolbarButton("重置视图", icon: "arrow.counterclockwise") {
                    resetViewport(in: lastViewportSize)
                }

                toolbarButton("\(Int(scale * 100))%", icon: "plus.magnifyingglass") {
                    setScalePreservingViewportCenter(scale + 0.12, viewport: lastViewportSize, animated: true)
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

    private func compactToolbarButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.primaryAccent)
                .frame(width: compactToolbarSize, height: compactToolbarSize)
                .background(Circle().fill(Color.primaryAccent.opacity(0.075)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func rootCenteredZoomControl(graph: TreeData, viewport: CGSize) -> some View {
        VStack(spacing: 8) {
            Button {
                setScaleCenteredOnRoot(scale, graph: graph, viewport: viewport, animated: true)
            } label: {
                Image(systemName: "smallcircle.filled.circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.primaryAccent)
                    .frame(width: zoomButtonSize, height: zoomButtonSize)
                    .background(Circle().fill(Color.cardBackground.opacity(0.92)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("以根节点为中心")

            Slider(
                value: Binding(
                    get: { Double(scale) },
                    set: { newValue in
                        setScalePreservingViewportCenter(CGFloat(newValue), graph: graph, viewport: viewport, animated: false)
                    }
                ),
                in: Double(minimumScale)...Double(maximumScale)
            )
            .tint(Color.primaryAccent)
            .frame(width: mode == .embedded ? 104 : 136)
            .rotationEffect(.degrees(-90))
            .frame(width: 28, height: mode == .embedded ? 116 : 148)
            .accessibilityLabel("缩放范围")
            .accessibilityValue("\(Int(scale * 100))%")

            Text("\(Int(scale * 100))%")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.textTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.cardBackground.opacity(0.90))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.12), lineWidth: 1)
        )
        .coDesignShadow(.card)
    }

    private func zoomControlCenter(in viewport: CGSize) -> CGPoint {
        let controlHeight: CGFloat = mode == .embedded ? 184 : 218
        let halfHeight = controlHeight / 2
        let minY = halfHeight + 14
        let maxY = max(minY, viewport.height - halfHeight - 14)

        return CGPoint(
            x: mode == .embedded ? 42 : 48,
            y: clamp(viewport.height / 2, min: minY, max: maxY)
        )
    }

    private var compactToolbarSize: CGFloat {
        #if os(iOS)
        return mode == .embedded ? 40 : 44
        #else
        return 28
        #endif
    }

    private var zoomButtonSize: CGFloat {
        #if os(iOS)
        return 38
        #else
        return 26
        #endif
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
            if mode == .embedded {
                locateStage(order, in: lastViewportSize, preserveScale: true)
            }
        }
        selectedNode = node
    }

    private func toggleTransition(_ order: Int, graph: TreeData, viewport: CGSize) {
        guard viewport.width > 0, viewport.height > 0 else {
            toggleTransition(order)
            return
        }

        var nextExpanded = expandedTransitionOrders
        if nextExpanded.contains(order) {
            nextExpanded.remove(order)
        } else {
            nextExpanded.insert(order)
        }

        guard let oldAnchor = transitionAnchorPosition(order: order, in: graph) else {
            withAnimation(AppTheme.Animation.spring) {
                expandedTransitionOrders = nextExpanded
            }
            return
        }

        let oldScreenPoint = screenPoint(for: oldAnchor)
        let nextGraph = layoutGraph(for: viewport, expandedTransitions: nextExpanded)
        guard let nextAnchor = transitionAnchorPosition(order: order, in: nextGraph) else {
            withAnimation(AppTheme.Animation.spring) {
                expandedTransitionOrders = nextExpanded
            }
            return
        }

        let nextOffset = offsetToPlace(
            nextAnchor,
            at: oldScreenPoint,
            graph: nextGraph,
            viewport: viewport,
            scale: scale
        )

        withAnimation(AppTheme.Animation.spring) {
            expandedTransitionOrders = nextExpanded
            offset = nextOffset
            lastOffset = nextOffset
        }
    }

    private func toggleTransition(_ order: Int) {
        withAnimation(AppTheme.Animation.spring) {
            if expandedTransitionOrders.contains(order) {
                expandedTransitionOrders.remove(order)
            } else {
                expandedTransitionOrders.insert(order)
            }
        }
    }

    private func transitionAnchorPosition(order: Int, in graph: TreeData) -> CGPoint? {
        guard let edge = graph.edges.first(where: { $0.togglesTransitionOrder == order }),
              let from = graph.node(for: edge.fromID),
              let to = graph.node(for: edge.toID)
        else {
            return nil
        }

        return CGPoint(
            x: (from.position.x + to.position.x) / 2,
            y: (from.position.y + to.position.y) / 2
        )
    }

    private func screenPoint(for contentPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: contentPoint.x * scale + offset.width,
            y: contentPoint.y * scale + offset.height
        )
    }

    private func beginEditing(_ node: TreeNode) {
        selectedNode = nil
        DispatchQueue.main.async {
            editingNode = node
        }
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
            parentMomentID: lastActiveQuestionMoment(stageOrder: stageOrder)?.id,
            timestamp: Date(),
            isActiveBranch: true
        )
        modelContext.insert(moment)
        project.thinkingMoments.append(moment)
        project.updatedAt = Date()
        expandedTransitionOrders.insert(stageOrder)
        try? modelContext.save()
        selectedNode = nil
    }

    private func lastActiveQuestionMoment(stageOrder: Int) -> ThinkingMoment? {
        project.thinkingMoments
            .filter {
                $0.stageOrder == stageOrder &&
                $0.momType == "question" &&
                $0.isActiveBranch &&
                ThinkingTreeMomentProjector.isVisibleInTree($0)
            }
            .sorted { $0.timestamp < $1.timestamp }
            .last
    }

    @ViewBuilder
    private func edgeHitAreas(graph: TreeData, viewport: CGSize) -> some View {
        ForEach(graph.edges.filter { $0.togglesTransitionOrder != nil }) { edge in
            if let from = graph.node(for: edge.fromID),
               let to = graph.node(for: edge.toID),
               let transitionOrder = edge.togglesTransitionOrder {
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: edgeHitWidth, height: max(abs(from.position.y - to.position.y), edgeHitMinHeight))
                        .contentShape(Rectangle())

                    transitionLabel(order: transitionOrder)
                        .offset(x: 112)
                }
                .position(
                    CGPoint(
                        x: (from.position.x + to.position.x) / 2,
                        y: (from.position.y + to.position.y) / 2
                    )
                )
                .onTapGesture {
                    toggleTransition(transitionOrder, graph: graph, viewport: viewport)
                }
                .zIndex(1)
            }
        }
    }

    private func transitionLabel(order: Int) -> some View {
        let count = transitionNodeCount(order)
        let isExpanded = isTransitionExpanded(order)
        return Text(isExpanded ? "已展开 · \(count) 个问题/节点" : "点击展开问题链")
            .font(.system(size: transitionLabelFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(isExpanded ? Color.primaryAccent : Color.textTertiary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.cardBackground.opacity(isExpanded ? 0.94 : 0.78))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        (isExpanded ? Color.primaryAccent : Color.textTertiary).opacity(0.16),
                        lineWidth: 1
                    )
            )
    }

    private var edgeHitWidth: CGFloat {
        #if os(iOS)
        return 230
        #else
        return 190
        #endif
    }

    private var edgeHitMinHeight: CGFloat {
        #if os(iOS)
        return 58
        #else
        return 42
        #endif
    }

    private var transitionLabelFontSize: CGFloat {
        #if os(iOS)
        return mode == .embedded ? 10 : 11
        #else
        return mode == .embedded ? 8.5 : 10
        #endif
    }

    private func isTransitionExpanded(_ order: Int) -> Bool {
        expandedTransitionOrders.contains(order)
    }

    private func transitionNodeCount(_ order: Int) -> Int {
        ThinkingTreeMomentProjector.visibleMoments(
            project.thinkingMoments.filter { $0.stageOrder == order }
        ).count +
        project.learningTraces.filter { $0.stageOrder == order }.count
    }

    private func zIndex(for node: TreeNode) -> Double {
        switch node.kind {
        case .root: return 6
        case .stage: return 5
        case .branchStage: return 4
        case .question, .field, .process, .evidence, .revision: return 4
        }
    }

    private func isBranchNode(_ node: TreeNode) -> Bool {
        switch node.kind {
        case .branchStage:
            return true
        case .question, .field, .process, .evidence, .revision:
            return true
        case .root, .stage:
            return false
        }
    }

    // MARK: - Drawing

    private func drawEdges(context: GraphicsContext, graph: TreeData) {
        for edge in graph.edges {
            guard let from = graph.node(for: edge.fromID),
                  let to = graph.node(for: edge.toID) else {
                continue
            }

            let path = edgePath(from: from, to: to, graph: graph)

            context.stroke(
                path,
                with: .color(edgeColor(edge, to: to)),
                style: edgeStroke(edge)
            )
        }
    }

    private func edgePath(from: TreeNode, to: TreeNode, graph: TreeData) -> Path {
        let trunkX = graph.contentSize.width / 2
        let isTrunk = (from.kind == .root || from.kind == .stage) && to.kind == .stage

        var path = Path()

        if isTrunk {
            path.move(to: from.position)
            path.addLine(to: to.position)
            return path
        }

        if isBranchNode(to) {
            return branchEdgePath(from: from, to: to, trunkX: trunkX)
        }

        if isBranchNode(from) {
            path.move(to: from.position)
            path.addLine(to: CGPoint(x: trunkX, y: from.position.y))
            return path
        }

        let dy = abs(to.position.y - from.position.y)
        path.move(to: from.position)
        path.addCurve(
            to: to.position,
            control1: CGPoint(x: from.position.x, y: from.position.y - max(dy * 0.34, 24)),
            control2: CGPoint(x: to.position.x, y: to.position.y + max(dy * 0.18, 18))
        )
        return path
    }

    private func branchEdgePath(from: TreeNode, to: TreeNode, trunkX: CGFloat) -> Path {
        var path = Path()

        if to.kind == .question && !to.isArchived {
            path.move(to: CGPoint(x: trunkX, y: from.position.y))
            path.addLine(to: to.position)
            return path
        }

        let side: CGFloat = to.position.x >= trunkX ? 1 : -1
        let railX = to.position.x - side * branchRailInset(for: to)
        let sourceY = to.kind == .branchStage ? from.position.y : (isBranchNode(from) ? from.position.y : to.position.y)
        let startX = isBranchNode(from) ? from.position.x : trunkX
        let start = CGPoint(x: startX, y: sourceY)
        let railStart = CGPoint(x: railX, y: sourceY)
        let railEnd = CGPoint(x: railX, y: to.position.y)

        path.move(to: start)
        path.addLine(to: railStart)
        if abs(sourceY - to.position.y) > 1 {
            path.addLine(to: railEnd)
        }
        path.addLine(to: to.position)

        return path
    }

    private func branchRailInset(for node: TreeNode) -> CGFloat {
        switch node.kind {
        case .evidence:
            return 104
        case .field:
            return 100
        case .process, .revision:
            return 96
        case .question:
            return 42
        case .branchStage:
            return 0
        case .root, .stage:
            return 0
        }
    }

    private func edgeColor(_ edge: TreeEdge, to node: TreeNode) -> Color {
        if let order = edge.togglesTransitionOrder,
           isTransitionExpanded(order) {
            return Color.primaryAccent.opacity(0.62)
        }

        switch edge.style {
        case .active:
            return node.kind == .stage ? node.nodeColor.opacity(0.68) : Color.primaryAccent.opacity(0.30)
        case .archived:
            return Color(red: 0.58, green: 0.53, blue: 0.48).opacity(0.32)
        case .transition:
            return Color.warning.opacity(0.34)
        case .ghost:
            return Color.stageNotStarted.opacity(0.22)
        case .evidence:
            return Color.secondaryAccent.opacity(0.24)
        }
    }

    private func edgeStroke(_ edge: TreeEdge) -> StrokeStyle {
        if let order = edge.togglesTransitionOrder,
           isTransitionExpanded(order) {
            return StrokeStyle(lineWidth: 2.2, lineCap: .round)
        }

        switch edge.style {
        case .active:
            return StrokeStyle(lineWidth: 1.6, lineCap: .round)
        case .transition:
            return StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [6, 7])
        case .archived:
            return StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [5, 7])
        case .ghost:
            return StrokeStyle(lineWidth: 1.0, lineCap: .round, dash: [3, 7])
        case .evidence:
            return StrokeStyle(lineWidth: 1.0, lineCap: .round, dash: [3, 7])
        }
    }

    // MARK: - Viewport

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                setScalePreservingViewportCenter(
                    lastScale * value,
                    viewport: lastViewportSize,
                    animated: false,
                    commit: false
                )
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
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
        locateStage(project.currentStageOrder, in: viewport, preserveScale: preserveScale)
    }

    private func locateStage(_ stageOrder: Int, in viewport: CGSize, preserveScale: Bool) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let graph = layoutGraph(for: viewport)
        let targetID = TreeBuilder.stageNodeID(stageOrder)
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
        guard let root = graph.node(for: TreeBuilder.rootID) else { return }
        let nextScale = resetScale(for: graph, viewport: viewport)
        let nextOffset = offsetToPlace(
            root.position,
            at: centeredRootAnchor(in: viewport),
            graph: graph,
            viewport: viewport,
            scale: nextScale
        )

        withAnimation(AppTheme.Animation.standard) {
            scale = nextScale
            lastScale = nextScale
            offset = nextOffset
            lastOffset = nextOffset
            hasInitializedViewport = true
        }
    }

    private func fitTreeToViewport(in viewport: CGSize, preserveScale: Bool) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let graph = layoutGraph(for: viewport)
        guard let root = graph.node(for: TreeBuilder.rootID) else { return }
        let nextScale = preserveScale ? clampedScale(scale) : initialFitScale(for: graph, viewport: viewport)
        let nextOffset = offsetToPlace(
            root.position,
            at: rootAnchor(in: viewport),
            graph: graph,
            viewport: viewport,
            scale: nextScale
        )

        withAnimation(AppTheme.Animation.standard) {
            scale = nextScale
            lastScale = nextScale
            offset = nextOffset
            lastOffset = nextOffset
            hasInitializedViewport = true
        }
    }

    private func fitScale(for graph: TreeData, viewport: CGSize) -> CGFloat {
        let bounds = graphBounds(for: graph)
        let horizontalInset: CGFloat = mode == .embedded ? 28 : 64
        let verticalInset: CGFloat = mode == .embedded ? 36 : 84
        let widthScale = max(viewport.width - horizontalInset * 2, 1) / max(bounds.width, 1)
        let heightScale = max(viewport.height - verticalInset * 2, 1) / max(bounds.height, 1)
        return clampedScale(min(widthScale, heightScale, 1))
    }

    private func initialFitScale(for graph: TreeData, viewport: CGSize) -> CGFloat {
        guard let root = graph.node(for: TreeBuilder.rootID) else {
            return fitScale(for: graph, viewport: viewport)
        }

        let bounds = graphBounds(for: graph)
        let horizontalInset: CGFloat = mode == .embedded ? 30 : 72
        let widthScale = max(viewport.width - horizontalInset * 2, 1) / max(bounds.width, 1)
        let availableHeight = max(rootAnchor(in: viewport).y - topViewportInset, 1)
        let rootToTopSpan = max(root.position.y - bounds.minY, 1)
        let heightScale = availableHeight / rootToTopSpan

        let fittedScale = min(widthScale, heightScale, 1)
        return clampedScale(max(fittedScale, minimumReadableScale))
    }

    private func resetScale(for graph: TreeData, viewport: CGSize) -> CGFloat {
        max(fitScale(for: graph, viewport: viewport), minimumReadableScale)
    }

    private var minimumReadableScale: CGFloat {
        mode == .embedded ? 0.58 : 0.72
    }

    private func graphBounds(for graph: TreeData) -> CGRect {
        guard let first = graph.nodes.first else {
            return CGRect(origin: .zero, size: graph.contentSize)
        }

        var minX = first.position.x
        var maxX = first.position.x
        var minY = first.position.y
        var maxY = first.position.y

        for node in graph.nodes.dropFirst() {
            minX = min(minX, node.position.x)
            maxX = max(maxX, node.position.x)
            minY = min(minY, node.position.y)
            maxY = max(maxY, node.position.y)
        }

        let horizontalPadding: CGFloat = graph.nodes.contains(where: isBranchNode) ? (mode == .embedded ? 122 : 150) : 122
        let verticalPadding: CGFloat = mode == .embedded ? 64 : 78
        return CGRect(
            x: minX - horizontalPadding,
            y: minY - verticalPadding,
            width: max(maxX - minX + horizontalPadding * 2, 1),
            height: max(maxY - minY + verticalPadding * 2, 1)
        )
    }

    private var topViewportInset: CGFloat {
        mode == .embedded ? 44 : 72
    }

    private func rootAnchor(in viewport: CGSize) -> CGPoint {
        CGPoint(
            x: viewport.width / 2,
            y: mode == .embedded
                ? viewport.height / 2
                : viewport.height - 116
        )
    }

    private func centeredRootAnchor(in viewport: CGSize) -> CGPoint {
        CGPoint(x: viewport.width / 2, y: viewport.height / 2)
    }

    private func offsetToPlace(
        _ point: CGPoint,
        at desired: CGPoint,
        graph: TreeData,
        viewport: CGSize,
        scale: CGFloat
    ) -> CGSize {
        return CGSize(
            width: desired.x - point.x * scale,
            height: desired.y - point.y * scale
        )
    }

    private func setScaleCenteredOnRoot(_ value: CGFloat, viewport: CGSize, animated: Bool) {
        guard viewport.width > 0, viewport.height > 0 else {
            scale = clampedScale(value)
            lastScale = scale
            return
        }
        let graph = layoutGraph(for: viewport)
        setScaleCenteredOnRoot(value, graph: graph, viewport: viewport, animated: animated)
    }

    private func setScaleCenteredOnRoot(_ value: CGFloat, graph: TreeData, viewport: CGSize, animated: Bool) {
        let nextScale = clampedScale(value)
        guard viewport.width > 0,
              viewport.height > 0,
              let root = graph.node(for: TreeBuilder.rootID)
        else {
            scale = nextScale
            lastScale = nextScale
            return
        }

        let nextOffset = offsetToPlace(
            root.position,
            at: CGPoint(x: viewport.width / 2, y: viewport.height / 2),
            graph: graph,
            viewport: viewport,
            scale: nextScale
        )

        let updates = {
            scale = nextScale
            lastScale = nextScale
            offset = nextOffset
            lastOffset = nextOffset
            hasInitializedViewport = true
        }

        if animated {
            withAnimation(AppTheme.Animation.quick, updates)
        } else {
            updates()
        }
    }

    private func setScalePreservingViewportCenter(
        _ value: CGFloat,
        viewport: CGSize,
        animated: Bool,
        commit: Bool = true
    ) {
        guard viewport.width > 0, viewport.height > 0 else {
            let nextScale = clampedScale(value)
            scale = nextScale
            if commit {
                lastScale = nextScale
            }
            return
        }
        let graph = layoutGraph(for: viewport)
        setScalePreservingViewportCenter(
            value,
            graph: graph,
            viewport: viewport,
            animated: animated,
            commit: commit
        )
    }

    private func setScalePreservingViewportCenter(
        _ value: CGFloat,
        graph: TreeData,
        viewport: CGSize,
        animated: Bool,
        commit: Bool = true
    ) {
        let nextScale = clampedScale(value)
        let nextOffset = offsetPreservingViewportPoint(
            CGPoint(x: viewport.width / 2, y: viewport.height / 2),
            graph: graph,
            viewport: viewport,
            nextScale: nextScale
        )

        let updates = {
            scale = nextScale
            offset = nextOffset
            if commit {
                lastScale = nextScale
                lastOffset = nextOffset
            }
            hasInitializedViewport = true
        }

        if animated {
            withAnimation(AppTheme.Animation.quick, updates)
        } else {
            updates()
        }
    }

    private func offsetPreservingViewportPoint(
        _ point: CGPoint,
        graph: TreeData,
        viewport: CGSize,
        nextScale: CGFloat
    ) -> CGSize {
        let currentScale = max(scale, 0.0001)
        let anchoredContentPoint = CGPoint(
            x: (point.x - offset.width) / currentScale,
            y: (point.y - offset.height) / currentScale
        )

        return CGSize(
            width: point.x - anchoredContentPoint.x * nextScale,
            height: point.y - anchoredContentPoint.y * nextScale
        )
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
