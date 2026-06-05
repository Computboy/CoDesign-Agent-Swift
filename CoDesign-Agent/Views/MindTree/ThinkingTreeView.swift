import SwiftUI
import SwiftData

/// Interactive design-thinking tree.
/// The tree grows upward from the project root and follows the same staged
/// thinking questions used by the workspace.
struct ThinkingTreeView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext

    private let minimumScale: CGFloat = 0.12
    private let maximumScale: CGFloat = 2.5
    private let stageSpacing: CGFloat = 215
    private let contentSize = CGSize(width: 3200, height: 7200)
    private let viewportTopMargin: CGFloat = 90
    private let viewportBottomMargin: CGFloat = 120
    private let questionBoxSize = CGSize(width: 760, height: 260)

    @State private var selections: [String: FlowSelection] = [:]
    @State private var archivedSelections: [ArchivedFlowSelection] = []
    @State private var generatedSteps: [String: GeneratedFlowStep] = [:]
    @State private var generatingStepIDs: Set<String> = []
    @State private var generationErrors: [String: String] = [:]
    @State private var expandedStepID: String? = "stage-1-question-0"
    @State private var customInputs: [String: String] = [:]
    @State private var versionCounter = 0

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var originalScale: CGFloat = 1
    @State private var originalOffset: CGSize = .zero
    @State private var hasInitializedViewport = false

    private var baseFlowSteps: [FlowStep] {
        StageDefinition.all.flatMap { definition in
            definition.thinkingQuestions.enumerated().map { index, question in
                FlowStep(definition: definition, questionIndex: index, question: question)
            }
        }
    }

    private var flowSteps: [FlowStep] {
        StageDefinition.all.flatMap { definition in
            definition.thinkingQuestions.enumerated().map { index, question in
                let stepID = FlowStep.id(stageOrder: definition.order, questionIndex: index)
                return FlowStep(
                    definition: definition,
                    questionIndex: index,
                    question: question,
                    generated: generatedSteps[stepID]
                )
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let graph = makeGraph()

            ZStack {
                LinearGradient(
                    colors: [
                        Color.appBackground,
                        Color(red: 0.97, green: 0.985, blue: 0.99)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ZStack {
                    Canvas { context, _ in
                        drawEdges(context: context, graph: graph)
                    }
                    .frame(width: contentSize.width, height: contentSize.height)

                    ForEach(graph.nodes) { node in
                        FlowNodeView(node: node) {
                            handleTap(node)
                        }
                        .position(node.position)
                    }

                    if let expandedStepID,
                       let step = flowSteps.first(where: { $0.id == expandedStepID }) {
                        QuestionBoxView(
                            step: step,
                            selectedOptionID: selections[expandedStepID]?.optionID,
                            isGenerating: generatingStepIDs.contains(expandedStepID),
                            generationError: generationErrors[expandedStepID],
                            customText: Binding(
                                get: { customInputs[expandedStepID] ?? "" },
                                set: { customInputs[expandedStepID] = $0 }
                            ),
                            onSelect: { option in select(option, for: step) },
                            onCollapse: { self.expandedStepID = nil }
                        )
                        .frame(width: questionBoxSize.width)
                        .position(questionBoxPosition(for: step.id, in: graph))
                        .zIndex(20)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                    }
                }
                .frame(width: contentSize.width, height: contentSize.height)
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .gesture(magnificationGesture)
                .simultaneousGesture(panGesture)
            }
            .onAppear {
                if project.thinkingMoments.isEmpty, let ctx = project.modelContext {
                    project.ensureThinkingMoments(context: ctx)
                }
                if !hasInitializedViewport {
                    DispatchQueue.main.async {
                        resetOriginalViewport(viewportSize: geo.size)
                    }
                }
            }
            .onChange(of: geo.size) { _, newSize in
                guard hasInitializedViewport else { return }
                DispatchQueue.main.async {
                    resetOriginalViewport(viewportSize: newSize, preserveUserScale: true)
                }
            }
        }
        .overlay(alignment: .trailing) {
            zoomSidebar
        }
        .task(id: expandedStepID) {
            guard let expandedStepID else { return }
            await generateStepContentIfNeeded(stepID: expandedStepID)
        }
    }

    // MARK: - Interaction

    private func handleTap(_ node: FlowGraphNode) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            switch node.status {
            case .root:
                expandedStepID = nextUnansweredStepID() ?? flowSteps.first?.id
            case .selected, .unselected, .archived:
                if let stepID = node.stepID {
                    expandedStepID = stepID
                }
            }
        }
    }

    private func select(_ option: FlowOption, for step: FlowStep) {
        let resolvedTitle: String
        let resolvedDetail: String?

        if option.isCustom {
            let trimmed = (customInputs[step.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            resolvedTitle = trimmed.isEmpty ? "我的自定义回答" : trimmed
            resolvedDetail = "自定义回答"
            customInputs[step.id] = resolvedTitle
        } else {
            resolvedTitle = option.title
            resolvedDetail = option.detail
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            if selections[step.id]?.optionID != option.id ||
                selections[step.id]?.title != resolvedTitle {
                archiveAffectedSelections(from: step.id)
            }

            versionCounter += 1
            selections[step.id] = FlowSelection(
                stepID: step.id,
                stageOrder: step.stageOrder,
                questionIndex: step.questionIndex,
                optionID: option.id,
                optionIndex: option.index,
                title: resolvedTitle,
                detail: resolvedDetail,
                version: versionCounter
            )

            expandedStepID = nextUnansweredStepID(after: step.id)
        }
    }

    private func archiveAffectedSelections(from stepID: String) {
        guard let startIndex = flowSteps.firstIndex(where: { $0.id == stepID }) else { return }
        let graphBeforeArchive = makeGraph()
        let affectedStepIDs = flowSteps[startIndex...].map(\.id).filter { selections[$0] != nil }
            guard !affectedStepIDs.isEmpty else { return }

        let revision = (archivedSelections.map(\.revision).max() ?? 0) + 1

        for affectedID in affectedStepIDs {
            guard let selection = selections[affectedID] else { continue }
            let archiveID = FlowGraph.archivedNodeID(stepID: affectedID, revision: revision, version: selection.version)
            let oldNodeID = FlowGraph.optionNodeID(stepID: affectedID, optionID: selection.optionID)
            let oldPosition = graphBeforeArchive.node(for: oldNodeID)?.position
            let oldParentID = graphBeforeArchive.edge(to: oldNodeID)?.fromID ?? FlowGraph.rootID
            archivedSelections.append(
                ArchivedFlowSelection(
                    id: archiveID,
                    stepID: affectedID,
                    stageOrder: selection.stageOrder,
                    questionIndex: selection.questionIndex,
                    optionIndex: selection.optionIndex,
                    title: selection.title,
                    detail: selection.detail,
                    parentID: oldParentID,
                    position: oldPosition,
                    revision: revision
                )
            )
            selections[affectedID] = nil
        }

        for step in flowSteps[startIndex...] where step.id != stepID {
            generatedSteps[step.id] = nil
            generationErrors[step.id] = nil
        }
    }

    private func nextUnansweredStepID(after stepID: String? = nil) -> String? {
        let startIndex: Int
        if let stepID, let current = flowSteps.firstIndex(where: { $0.id == stepID }) {
            startIndex = current + 1
        } else {
            startIndex = 0
        }
        guard startIndex < flowSteps.count else { return nil }
        return flowSteps[startIndex...].first { selections[$0.id] == nil }?.id
    }

    private func generateStepContentIfNeeded(stepID: String) async {
        guard generatedSteps[stepID] == nil,
              !generatingStepIDs.contains(stepID),
              let baseStep = baseFlowSteps.first(where: { $0.id == stepID }) else {
            return
        }

        generatingStepIDs.insert(stepID)
        generationErrors[stepID] = nil

        let context = ThinkingTreeGenerationContext(
            projectName: project.name,
            projectDescription: project.briefDescription,
            briefSummary: briefSummaryText(),
            stageName: baseStep.stageName,
            stageOrder: baseStep.stageOrder,
            stagePurpose: baseStep.purpose,
            baseQuestion: baseStep.question,
            selectedPath: selectedPathSummary(before: stepID)
        )
        let result = await ThinkingTreeGenerationService().generate(context: context)

        generatedSteps[stepID] = result.step
        if let errorMessage = result.errorMessage {
            generationErrors[stepID] = errorMessage
        }
        generatingStepIDs.remove(stepID)
    }

    private func selectedPathSummary(before stepID: String) -> [String] {
        guard let currentIndex = flowSteps.firstIndex(where: { $0.id == stepID }) else { return [] }

        return flowSteps[..<currentIndex].compactMap { step in
            guard let selection = selections[step.id] else { return nil }
            return "Stage \(step.stageOrder) Q\(step.questionIndex + 1)：\(step.question) -> \(selection.title)"
        }
    }

    private func briefSummaryText() -> String {
        guard let brief = project.brief?.toSnapshot() else {
            return "暂无结构化简报"
        }

        var parts: [String] = []
        appendBriefValue("目标用户", brief.targetUser, to: &parts)
        appendBriefValue("核心痛点", brief.painPoint, to: &parts)
        appendBriefValue("使用场景", brief.useScenario, to: &parts)
        appendBriefValue("核心价值", brief.coreValue, to: &parts)
        appendBriefValue("差异化", brief.differentiation, to: &parts)
        appendBriefValue("MVP 功能", brief.mvpFeatures, to: &parts)
        appendBriefValue("技术模块", brief.technicalModules, to: &parts)
        appendBriefValue("交互流程", brief.interactionFlow, to: &parts)
        appendBriefValue("运行逻辑", brief.operationLogic, to: &parts)
        appendBriefValue("硬性约束", brief.hardConstraints, to: &parts)
        appendBriefValue("里程碑", brief.milestones, to: &parts)

        if !brief.boundaryItems.isEmpty {
            parts.append("边界：\(brief.boundaryItems.map(\.content).joined(separator: "；"))")
        }
        if !brief.successMetrics.isEmpty {
            parts.append("指标：\(brief.successMetrics.map { "\($0.metric) \($0.target)" }.joined(separator: "；"))")
        }
        if !brief.risks.isEmpty {
            parts.append("风险：\(brief.risks.map(\.desc).joined(separator: "；"))")
        }

        return parts.isEmpty ? "暂无结构化简报" : parts.joined(separator: "\n")
    }

    private func appendBriefValue(_ label: String, _ value: String?, to parts: inout [String]) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return
        }
        parts.append("\(label)：\(value)")
    }

    // MARK: - Graph

    private func makeGraph() -> FlowGraph {
        let centerX = contentSize.width / 2
        let rootY = contentSize.height - 170
        var nodes: [FlowGraphNode] = [
            FlowGraphNode(
                id: FlowGraph.rootID,
                stepID: nil,
                stageOrder: nil,
                optionIndex: nil,
                label: project.name,
                subtitle: "项目主题",
                status: .root,
                position: CGPoint(x: centerX, y: rootY)
            )
        ]
        var edges: [FlowGraphEdge] = []
        var activeParentID = FlowGraph.rootID
        var activeParentPosition = CGPoint(x: centerX, y: rootY)

        var occupied = [CGPoint(x: centerX, y: rootY)]
        let optionOffsets: [CGFloat] = [-390, -130, 130, 390]

        for step in flowSteps {
            guard let selection = selections[step.id] else { break }
            let stepY = activeParentPosition.y - stageSpacing
            var selectedNodeID = ""
            var selectedNodePosition = activeParentPosition

            for option in step.options {
                let optionID = FlowGraph.optionNodeID(stepID: step.id, optionID: option.id)
                let isSelected = option.id == selection.optionID
                let status: FlowNodeStatus = isSelected ? .selected : .unselected
                let label = isSelected ? selection.title : option.title
                let subtitle = isSelected ? selection.detail : option.detail

                let slotX = activeParentPosition.x + optionOffsets[min(option.index, optionOffsets.count - 1)]
                let candidate = CGPoint(x: slotX, y: stepY)
                let position = resolvedPosition(candidate, occupied: occupied, preferredDirection: option.index)
                occupied.append(position)

                nodes.append(
                    FlowGraphNode(
                        id: optionID,
                        stepID: step.id,
                        stageOrder: step.stageOrder,
                        optionIndex: option.index,
                        label: label,
                        subtitle: subtitle,
                        status: status,
                        position: position
                    )
                )
                edges.append(
                    FlowGraphEdge(
                        id: "\(activeParentID)-\(optionID)",
                        fromID: activeParentID,
                        toID: optionID,
                        style: isSelected ? .selected : .unselected
                    )
                )

                if isSelected {
                    selectedNodeID = optionID
                    selectedNodePosition = position
                }
            }

            activeParentID = selectedNodeID
            activeParentPosition = selectedNodePosition
        }

        for archive in archivedSelections {
            let fallbackY = rootY - CGFloat(archive.stageOrder * 3 + archive.questionIndex + 1) * stageSpacing
            let side = archive.revision % 2 == 0 ? CGFloat(-1) : CGFloat(1)
            let fallbackX = centerX + side * (650 + CGFloat(archive.revision - 1) * 120)
            let candidate = archive.position ?? CGPoint(x: fallbackX, y: fallbackY)
            let position = resolvedPosition(candidate, occupied: occupied, preferredDirection: archive.optionIndex + archive.revision)
            occupied.append(position)

            nodes.append(
                FlowGraphNode(
                    id: archive.id,
                    stepID: archive.stepID,
                    stageOrder: archive.stageOrder,
                    optionIndex: archive.optionIndex,
                    label: archive.title,
                    subtitle: archive.detail ?? "修改前选择",
                    status: .archived,
                    position: position
                )
            )
        }

        return FlowGraph(nodes: nodes, edges: edges, contentSize: contentSize)
    }

    private func questionBoxPosition(for stepID: String, in graph: FlowGraph) -> CGPoint {
        let anchor: CGPoint
        let yOffset: CGFloat

        if let selection = selections[stepID] {
            let nodeID = FlowGraph.optionNodeID(stepID: stepID, optionID: selection.optionID)
            anchor = graph.node(for: nodeID)?.position
                ?? CGPoint(x: contentSize.width / 2, y: contentSize.height - 170)
            yOffset = 170
        } else if let previous = previousSelectedStep(before: stepID),
                  let selection = selections[previous.id] {
            let nodeID = FlowGraph.optionNodeID(stepID: previous.id, optionID: selection.optionID)
            anchor = graph.node(for: nodeID)?.position
                ?? CGPoint(x: contentSize.width / 2, y: contentSize.height - 170)
            yOffset = 205
        } else {
            anchor = graph.node(for: FlowGraph.rootID)?.position
                ?? CGPoint(x: contentSize.width / 2, y: contentSize.height - 170)
            yOffset = 205
        }

        return CGPoint(
            x: min(max(anchor.x, questionBoxSize.width / 2 + 32), contentSize.width - questionBoxSize.width / 2 - 32),
            y: max(anchor.y - yOffset, questionBoxSize.height / 2 + 36)
        )
    }

    private func previousSelectedStep(before stepID: String) -> FlowStep? {
        guard let currentIndex = flowSteps.firstIndex(where: { $0.id == stepID }),
              currentIndex > 0 else {
            return nil
        }

        return flowSteps[..<currentIndex].reversed().first { selections[$0.id] != nil }
    }

    private func resolvedPosition(
        _ candidate: CGPoint,
        occupied: [CGPoint],
        preferredDirection: Int
    ) -> CGPoint {
        var position = clampedContentPoint(candidate)
        let minimumDistance: CGFloat = 168
        let direction = preferredDirection % 2 == 0 ? CGFloat(-1) : CGFloat(1)
        var attempt = 0

        while occupied.contains(where: { distance($0, position) < minimumDistance }) && attempt < 12 {
            let row = CGFloat(attempt / 3 + 1)
            let column = CGFloat(attempt % 3 + 1)
            position = clampedContentPoint(
                CGPoint(
                    x: candidate.x + direction * column * 78,
                    y: candidate.y - row * 48
                )
            )
            attempt += 1
        }

        return position
    }

    private func clampedContentPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 120), contentSize.width - 120),
            y: min(max(point.y, 100), contentSize.height - 120)
        )
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func drawEdges(context: GraphicsContext, graph: FlowGraph) {
        for edge in graph.edges {
            guard let from = graph.node(for: edge.fromID),
                  let to = graph.node(for: edge.toID) else { continue }

            var path = Path()
            path.move(to: from.position)
            let dy = abs(to.position.y - from.position.y)
            path.addCurve(
                to: to.position,
                control1: CGPoint(x: from.position.x, y: from.position.y - dy * 0.45),
                control2: CGPoint(x: to.position.x, y: to.position.y + dy * 0.45)
            )

            switch edge.style {
            case .selected:
                context.stroke(
                    path,
                    with: .color(Color(red: 0.73, green: 0.58, blue: 0.15).opacity(0.95)),
                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                )
            case .unselected:
                context.stroke(
                    path,
                    with: .color(Color.black.opacity(0.48)),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [5, 6])
                )
            case .archived:
                context.stroke(
                    path,
                    with: .color(FlowPalette.hazeBlue.opacity(0.82)),
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [7, 5])
                )
            }
        }
    }

    // MARK: - Gestures and Zoom

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

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumScale), maximumScale)
    }

    private func resetToOriginalViewport() {
        scale = originalScale
        lastScale = originalScale
        offset = originalOffset
        lastOffset = originalOffset
    }

    private func resetOriginalViewport(viewportSize: CGSize, preserveUserScale: Bool = false) {
        let graph = makeGraph()
        guard let root = graph.node(for: FlowGraph.rootID) else { return }

        var topY = graph.nodes.map(\.position.y).min() ?? root.position.y
        if let expandedStepID {
            let qPos = questionBoxPosition(for: expandedStepID, in: graph)
            topY = min(topY, qPos.y - questionBoxSize.height / 2)
        }

        let verticalSpan = max(root.position.y - topY, 1)
        let availableHeight = max(viewportSize.height - viewportTopMargin - viewportBottomMargin, 1)
        let fittedScale = clampedScale(availableHeight / verticalSpan)
        let appliedScale = preserveUserScale ? scale : fittedScale

        let contentCenter = CGPoint(x: graph.contentSize.width / 2, y: graph.contentSize.height / 2)
        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let targetRootPosition = CGPoint(
            x: viewportSize.width / 2,
            y: viewportSize.height - viewportBottomMargin
        )
        let fittedOffset = CGSize(
            width: targetRootPosition.x - viewportCenter.x - (root.position.x - contentCenter.x) * appliedScale,
            height: targetRootPosition.y - viewportCenter.y - (root.position.y - contentCenter.y) * appliedScale
        )

        originalScale = fittedScale
        originalOffset = fittedOffset
        scale = appliedScale
        lastScale = appliedScale
        offset = fittedOffset
        lastOffset = fittedOffset
        hasInitializedViewport = true
    }
}

// MARK: - Flow Views

private struct QuestionBoxView: View {
    let step: FlowStep
    let selectedOptionID: String?
    let isGenerating: Bool
    let generationError: String?
    @Binding var customText: String
    var onSelect: (FlowOption) -> Void
    var onCollapse: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 310), spacing: 10, alignment: .top)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stage \(step.stageOrder) · Q\(step.questionIndex + 1) · \(step.stageName)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textTertiary)
                    Text(step.question)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(action: onCollapse) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.textSecondary)
                .accessibilityLabel("收起问题框")
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在根据项目主题生成问题和候选答案")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                }
            } else if let generationError {
                Text(generationError)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }

            Text(step.description)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(step.options) { option in
                    if option.isCustom {
                        customOption(option)
                    } else {
                        optionButton(option)
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardBackground.opacity(0.98))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    selectedOptionID == nil
                    ? Color.primaryAccent.opacity(0.18)
                    : Color.success.opacity(0.34),
                    lineWidth: 1.2
                )
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primaryAccent.opacity(0.82))
                .frame(width: 5)
                .padding(.vertical, 18)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: selectedOptionID)
    }

    private func optionButton(_ option: FlowOption) -> some View {
        Button {
            onSelect(option)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(option.displayIndex)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedOptionID == option.id ? .white : Color.primaryAccent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(selectedOptionID == option.id ? Color.success : Color.primaryAccent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = option.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selectedOptionID == option.id ? Color.success.opacity(0.16) : Color.appBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                selectedOptionID == option.id
                                ? Color.success.opacity(0.6)
                                : Color.primaryAccent.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func customOption(_ option: FlowOption) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(option.displayIndex)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(selectedOptionID == option.id ? .white : Color.primaryAccent)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(selectedOptionID == option.id ? Color.success : Color.primaryAccent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(option.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                TextField("输入你的答案", text: $customText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .textFieldStyle(.plain)
            }

            Button {
                onSelect(option)
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.success)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.success.opacity(0.14)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selectedOptionID == option.id ? Color.success.opacity(0.2) : Color.appBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            selectedOptionID == option.id
                            ? Color.success.opacity(0.6)
                            : Color.primaryAccent.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }
}

private struct FlowNodeView: View {
    let node: FlowGraphNode
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(node.fillColor.opacity(node.status == .unselected ? 0.55 : 1))
                        .frame(width: node.diameter, height: node.diameter)
                        .overlay(
                            Circle()
                                .strokeBorder(node.strokeColor, style: node.strokeStyle)
                        )
                        .shadow(color: node.fillColor.opacity(node.status == .selected ? 0.32 : 0.12), radius: 14, y: 5)

                    Text(node.centerText)
                        .font(.system(size: node.status == .root ? 18 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(node.textColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12)
                }

                Text(node.label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(node.labelColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(width: 150)

                if let subtitle = node.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(width: 150)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: node.status)
        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: node.position.x)
        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: node.position.y)
    }
}

// MARK: - Flow Data

private struct ThinkingTreeGenerationContext {
    let projectName: String
    let projectDescription: String
    let briefSummary: String
    let stageName: String
    let stageOrder: Int
    let stagePurpose: String
    let baseQuestion: String
    let selectedPath: [String]
}

private struct ThinkingTreeGenerationResult {
    let step: GeneratedFlowStep
    let errorMessage: String?
}

private struct ThinkingTreeGenerationService {
    private let apiClient = LLMAPIClient()

    func generate(context: ThinkingTreeGenerationContext) async -> ThinkingTreeGenerationResult {
        do {
            let raw = try await apiClient.completeJSON(messages: messages(for: context))
            let step = try decodeStep(from: raw, context: context)
            return ThinkingTreeGenerationResult(step: step, errorMessage: nil)
        } catch {
            return ThinkingTreeGenerationResult(
                step: fallbackStep(context: context),
                errorMessage: "API 生成失败，已使用本地兜底选项"
            )
        }
    }

    private func messages(for context: ThinkingTreeGenerationContext) -> [ChatCompletionMessage] {
        [
            ChatCompletionMessage(
                role: "system",
                content: """
                你是设计思维训练 App 的思维树生成器。你必须只输出 JSON 对象，不要 Markdown，不要解释。
                JSON schema:
                {
                  "question": "一个贴合项目主题的追问，18-32 个中文字符",
                  "description": "说明这个问题为什么在当前阶段重要，40-70 个中文字符",
                  "options": [
                    {"title": "候选答案标题，4-12 个中文字符", "detail": "候选答案解释，12-28 个中文字符"}
                  ]
                }
                规则：
                - options 必须正好 3 个，都是用户可能选择的具体答案，不是提问方式。
                - 不要输出“我已有答案/需要细化/先看示例”这类通用动作。
                - 选项要彼此有差异，并贴合项目主题、已有简报和已选择路径。
                - 每个字段都要简短，便于显示在节点上。
                """
            ),
            ChatCompletionMessage(
                role: "user",
                content: """
                项目名称：\(context.projectName)
                项目描述：\(context.projectDescription.isEmpty ? "暂无" : context.projectDescription)

                已有结构化简报：
                \(context.briefSummary)

                当前阶段：Stage \(context.stageOrder) \(context.stageName)
                阶段目的：\(context.stagePurpose)
                工作台原始问题：\(context.baseQuestion)

                已选择路径：
                \(context.selectedPath.isEmpty ? "暂无" : context.selectedPath.joined(separator: "\n"))

                请生成当前思维树问题和 3 个候选答案。
                """
            )
        ]
    }

    private func decodeStep(from raw: String, context: ThinkingTreeGenerationContext) throws -> GeneratedFlowStep {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText = extractJSONObject(from: trimmed) ?? trimmed
        guard let data = jsonText.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid UTF-8")
            )
        }

        let decoded = try JSONDecoder().decode(GeneratedFlowStep.self, from: data)
        let question = sanitized(decoded.question, fallback: context.baseQuestion, limit: 42)
        let description = sanitized(decoded.description, fallback: context.stagePurpose, limit: 86)
        let options = decoded.options
            .prefix(3)
            .enumerated()
            .map { index, option in
                GeneratedOption(
                    title: sanitized(option.title, fallback: "候选答案\(index + 1)", limit: 16),
                    detail: sanitized(option.detail, fallback: context.baseQuestion, limit: 36)
                )
            }

        guard options.count == 3 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Need exactly three options")
            )
        }

        return GeneratedFlowStep(question: question, description: description, options: options)
    }

    private func fallbackStep(context: ThinkingTreeGenerationContext) -> GeneratedFlowStep {
        let topic = context.projectName.isEmpty ? "项目" : context.projectName
        let question = sanitized(
            "\(topic)：\(context.baseQuestion)",
            fallback: context.baseQuestion,
            limit: 38
        )

        let options: [GeneratedOption]
        switch context.stageOrder {
        case 1:
            options = [
                GeneratedOption(title: "核心用户", detail: "先锁定最常遇到问题的人"),
                GeneratedOption(title: "高频场景", detail: "从最常发生的情境切入"),
                GeneratedOption(title: "痛点后果", detail: "描述不解决会造成什么")
            ]
        case 2:
            options = [
                GeneratedOption(title: "效率提升", detail: "让用户更快完成关键任务"),
                GeneratedOption(title: "门槛降低", detail: "减少理解和操作成本"),
                GeneratedOption(title: "体验陪伴", detail: "缓解焦虑并增强确定性")
            ]
        case 3:
            options = [
                GeneratedOption(title: "核心功能", detail: "只保留 V1 必须能力"),
                GeneratedOption(title: "暂缓功能", detail: "把非核心能力放到后续"),
                GeneratedOption(title: "排除边界", detail: "说明第一版明确不做什么")
            ]
        case 4:
            options = [
                GeneratedOption(title: "用户流程", detail: "按用户动作拆解体验"),
                GeneratedOption(title: "技术模块", detail: "按实现能力拆解结构"),
                GeneratedOption(title: "关键交互", detail: "聚焦最影响体验的操作")
            ]
        case 5:
            options = [
                GeneratedOption(title: "异常处理", detail: "定义出错后的反馈方式"),
                GeneratedOption(title: "权限规则", detail: "限定数据和操作边界"),
                GeneratedOption(title: "运行反馈", detail: "让系统状态可被理解")
            ]
        case 6:
            options = [
                GeneratedOption(title: "时间约束", detail: "按可完成周期收敛方案"),
                GeneratedOption(title: "平台约束", detail: "考虑设备和系统限制"),
                GeneratedOption(title: "资源约束", detail: "按人力预算选择实现")
            ]
        case 7:
            options = [
                GeneratedOption(title: "完成效率", detail: "用任务完成速度衡量"),
                GeneratedOption(title: "准确程度", detail: "用错误率或成功率衡量"),
                GeneratedOption(title: "用户反馈", detail: "用满意度验证体验")
            ]
        case 8:
            options = [
                GeneratedOption(title: "技术风险", detail: "识别实现最不确定处"),
                GeneratedOption(title: "用户风险", detail: "识别真实使用阻力"),
                GeneratedOption(title: "进度风险", detail: "识别时间和资源缺口")
            ]
        case 9:
            options = [
                GeneratedOption(title: "原型验证", detail: "先验证核心体验假设"),
                GeneratedOption(title: "用户测试", detail: "收集真实反馈再迭代"),
                GeneratedOption(title: "阶段交付", detail: "按里程碑拆分成果")
            ]
        default:
            options = [
                GeneratedOption(title: "方向一", detail: context.stageName),
                GeneratedOption(title: "方向二", detail: context.stageName),
                GeneratedOption(title: "方向三", detail: context.stageName)
            ]
        }

        return GeneratedFlowStep(
            question: question,
            description: "\(context.stagePurpose) 这些选项是离线兜底，开启 Live API 后会按主题生成。",
            options: options
        )
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            return nil
        }
        return String(text[start...end])
    }

    private func sanitized(_ value: String?, fallback: String, limit: Int) -> String {
        let source = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmpty = source?.isEmpty == false ? source! : fallback
        let flattened = nonEmpty
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        guard flattened.count > limit else { return flattened }
        return String(flattened.prefix(limit)) + "..."
    }
}

private struct GeneratedFlowStep: Codable, Hashable {
    let question: String
    let description: String
    let options: [GeneratedOption]
}

private struct GeneratedOption: Codable, Hashable {
    let title: String
    let detail: String?
}

private struct FlowStep: Identifiable, Hashable {
    let id: String
    let stageOrder: Int
    let stageName: String
    let questionIndex: Int
    let question: String
    let description: String
    let purpose: String
    let options: [FlowOption]

    static func id(stageOrder: Int, questionIndex: Int) -> String {
        "stage-\(stageOrder)-question-\(questionIndex)"
    }

    init(
        definition: StageDefinition,
        questionIndex: Int,
        question: String,
        generated: GeneratedFlowStep? = nil
    ) {
        id = Self.id(stageOrder: definition.order, questionIndex: questionIndex)
        stageOrder = definition.order
        stageName = definition.shortSubtitle
        self.questionIndex = questionIndex
        purpose = definition.compactPurpose
        self.question = generated?.question ?? question
        description = generated?.description ?? "\(definition.compactPurpose) 请选择最贴近你项目的一种回答，或使用自定义。"

        let generatedOptions = generated?.options.prefix(3).enumerated().map { index, option in
            FlowOption(
                id: "answer-\(index)",
                index: index,
                title: option.title,
                detail: option.detail,
                isCustom: false
            )
        } ?? Self.fallbackOptions(definition: definition, question: question)

        options = generatedOptions + [
            FlowOption(
                id: "answer-custom",
                index: generatedOptions.count,
                title: "自定义",
                detail: "手动填写更准确的答案",
                isCustom: true
            )
        ]
    }

    private static func fallbackOptions(definition: StageDefinition, question: String) -> [FlowOption] {
        let fallbackTitles: [String]
        switch definition.order {
        case 1:
            fallbackTitles = ["新生群体", "高频场景", "具体痛点"]
        case 2:
            fallbackTitles = ["更省时间", "更低门槛", "更有陪伴感"]
        case 3:
            fallbackTitles = ["保留核心功能", "暂缓扩展功能", "明确不做范围"]
        case 4:
            fallbackTitles = ["用户流程", "技术模块", "关键交互"]
        case 5:
            fallbackTitles = ["异常处理", "权限规则", "反馈机制"]
        case 6:
            fallbackTitles = ["时间限制", "平台限制", "资源限制"]
        case 7:
            fallbackTitles = ["任务完成率", "使用时长", "满意度反馈"]
        case 8:
            fallbackTitles = ["技术风险", "用户风险", "进度风险"]
        case 9:
            fallbackTitles = ["原型阶段", "测试阶段", "迭代阶段"]
        default:
            fallbackTitles = ["选项一", "选项二", "选项三"]
        }

        return fallbackTitles.enumerated().map { index, title in
            FlowOption(
                id: "answer-\(index)",
                index: index,
                title: title,
                detail: index == 0 ? question : definition.shortSubtitle,
                isCustom: false
            )
        }
    }
}

private struct FlowOption: Identifiable, Hashable {
    let id: String
    let index: Int
    let title: String
    let detail: String?
    let isCustom: Bool

    var displayIndex: String {
        if isCustom {
            return "自"
        }
        return String(index + 1)
    }
}

private struct FlowSelection: Hashable {
    let stepID: String
    let stageOrder: Int
    let questionIndex: Int
    let optionID: String
    let optionIndex: Int
    let title: String
    let detail: String?
    let version: Int
}

private struct ArchivedFlowSelection: Identifiable {
    let id: String
    let stepID: String
    let stageOrder: Int
    let questionIndex: Int
    let optionIndex: Int
    let title: String
    let detail: String?
    let parentID: String
    let position: CGPoint?
    let revision: Int
}

private struct FlowGraph {
    static let rootID = "root"

    let nodes: [FlowGraphNode]
    let edges: [FlowGraphEdge]
    let contentSize: CGSize

    func node(for id: String) -> FlowGraphNode? {
        nodes.first { $0.id == id }
    }

    func edge(to id: String) -> FlowGraphEdge? {
        edges.first { $0.toID == id }
    }

    static func optionNodeID(stepID: String, optionID: String) -> String {
        "option-\(stepID)-\(optionID)"
    }

    static func archivedNodeID(stepID: String, revision: Int, version: Int) -> String {
        "archive-\(revision)-\(stepID)-\(version)"
    }
}

private struct FlowGraphNode: Identifiable {
    let id: String
    let stepID: String?
    let stageOrder: Int?
    let optionIndex: Int?
    let label: String
    let subtitle: String?
    let status: FlowNodeStatus
    let position: CGPoint

    var diameter: CGFloat {
        switch status {
        case .root: return 110
        case .selected: return 118
        case .unselected, .archived: return 70
        }
    }

    var centerText: String {
        switch status {
        case .root: return "主题"
        case .selected: return optionIndex.map { "已选\n\($0 + 1)" } ?? "已选"
        case .unselected: return optionIndex.map { "\($0 + 1)" } ?? ""
        case .archived: return optionIndex.map { "旧\n\($0 + 1)" } ?? "旧"
        }
    }

    var fillColor: Color {
        switch status {
        case .root, .selected: return Color.success
        case .unselected: return Color(red: 0.91, green: 0.91, blue: 0.91)
        case .archived: return FlowPalette.hazeBlue
        }
    }

    var strokeColor: Color {
        switch status {
        case .root, .selected: return Color.success.opacity(0.95)
        case .unselected: return Color.gray.opacity(0.85)
        case .archived: return FlowPalette.hazeBlue.opacity(0.95)
        }
    }

    var strokeStyle: StrokeStyle {
        switch status {
        case .root, .selected:
            return StrokeStyle(lineWidth: 2)
        case .unselected, .archived:
            return StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4])
        }
    }

    var textColor: Color {
        status == .unselected || status == .archived ? Color.textSecondary : .white
    }

    var labelColor: Color {
        switch status {
        case .root, .selected: return Color.textPrimary
        case .unselected: return Color.textTertiary
        case .archived: return Color(red: 0.34, green: 0.52, blue: 0.58)
        }
    }
}

private enum FlowNodeStatus: Equatable {
    case root
    case selected
    case unselected
    case archived
}

private struct FlowGraphEdge: Identifiable {
    let id: String
    let fromID: String
    let toID: String
    let style: FlowEdgeStyle
}

private enum FlowEdgeStyle {
    case selected
    case unselected
    case archived
}

private enum FlowPalette {
    static let hazeBlue = Color(red: 0.68, green: 0.82, blue: 0.86)
}

#Preview {
    let project = Project(
        name: "智能校园导航助手",
        briefDescription: "帮助大学新生在复杂校园中快速找到目的地的智能导航应用"
    )
    project.stages = StageDefinition.all.map { def in
        ProgressStage(order: def.order, name: def.name)
    }
    return ThinkingTreeView(project: project)
}
