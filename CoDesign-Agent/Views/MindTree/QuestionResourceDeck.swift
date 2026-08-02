import SwiftUI

enum QuestionResourceDeckMetrics {
    static let cardSize = CGSize(width: 224, height: 112)
    static let firstCardGap: CGFloat = 22
    static let cardSpacing: CGFloat = 16
    static let collapsedEdgeWidth: CGFloat = 8
    static let maximumVisibleCollapsedEdges = 3
    static let expansionDragDistance: CGFloat = 176
    static let completionThreshold: CGFloat = 0.46
    static let collapseCommitDistance: CGFloat = 56
    static let horizontalIntentRatio: CGFloat = 1.05
    static let dragMinimumDistance: CGFloat = 6
    static let canvasTrailingPadding: CGFloat = 96
}

enum QuestionResourceDeckDragSource: Equatable {
    case questionNode
    case resourceCard
}

enum QuestionResourceDeckInteraction {
    static func acceptsDrag(
        source: QuestionResourceDeckDragSource,
        isExpanded: Bool,
        translation: CGSize
    ) -> Bool {
        guard abs(translation.width)
                > abs(translation.height)
                    * QuestionResourceDeckMetrics.horizontalIntentRatio else {
            return false
        }

        switch source {
        case .questionNode:
            return !isExpanded && translation.width > 0
        case .resourceCard:
            return isExpanded && translation.width < 0
        }
    }
}

struct QuestionResourceAttachmentPresentation: Identifiable {
    let questionID: String
    let questionSummary: String
    let questionStageOrder: Int
    let questionBranchVersion: Int
    let binding: QuestionResourceBinding
    let center: CGPoint
    let deckProgress: CGFloat
    let cardProgress: CGFloat

    var id: String { binding.id }
}

/// Resource cards never receive persisted or global tree coordinates.
/// Every position is derived from the owning question's center plus a local
/// horizontal-deck offset.
enum QuestionResourceDeckLayout {
    static func clampedProgress(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    static func progress(
        isExpanded: Bool,
        translationX: CGFloat
    ) -> CGFloat {
        let origin: CGFloat = isExpanded ? 1 : 0
        return clampedProgress(
            origin + translationX
                / QuestionResourceDeckMetrics.expansionDragDistance
        )
    }

    static func shouldExpand(
        isExpanded: Bool,
        translationX: CGFloat,
        predictedTranslationX: CGFloat
    ) -> Bool {
        let decisiveTranslationX = isExpanded
            ? min(translationX, predictedTranslationX)
            : max(translationX, predictedTranslationX)

        if isExpanded {
            return decisiveTranslationX
                > -QuestionResourceDeckMetrics.collapseCommitDistance
        }

        return progress(
            isExpanded: isExpanded,
            translationX: decisiveTranslationX
        ) >= QuestionResourceDeckMetrics.completionThreshold
    }

    static func localCenterOffset(
        cardIndex: Int,
        cardCount: Int,
        deckProgress: CGFloat
    ) -> CGPoint {
        let visibleEdgeIndex = min(
            cardIndex,
            QuestionResourceDeckMetrics.maximumVisibleCollapsedEdges - 1
        )
        let collapsedX = (
            TreeNodeMetrics.questionSize.width
                - QuestionResourceDeckMetrics.cardSize.width
        ) / 2
            + CGFloat(visibleEdgeIndex + 1)
                * QuestionResourceDeckMetrics.collapsedEdgeWidth

        let expandedX = TreeNodeMetrics.questionSize.width / 2
            + QuestionResourceDeckMetrics.firstCardGap
            + QuestionResourceDeckMetrics.cardSize.width / 2
            + CGFloat(cardIndex) * (
                QuestionResourceDeckMetrics.cardSize.width
                    + QuestionResourceDeckMetrics.cardSpacing
            )

        let progress = staggeredCardProgress(
            deckProgress,
            cardIndex: cardIndex,
            cardCount: cardCount
        )
        return CGPoint(
            x: collapsedX + (expandedX - collapsedX) * progress,
            y: 0
        )
    }

    static func cardCenter(
        questionCenter: CGPoint,
        cardIndex: Int,
        cardCount: Int,
        deckProgress: CGFloat
    ) -> CGPoint {
        let offset = localCenterOffset(
            cardIndex: cardIndex,
            cardCount: cardCount,
            deckProgress: deckProgress
        )
        return CGPoint(
            x: questionCenter.x + offset.x,
            y: questionCenter.y + offset.y
        )
    }

    static func presentations(
        graph: TreeData,
        progressByQuestionID: [String: CGFloat]
    ) -> [QuestionResourceAttachmentPresentation] {
        graph.nodes
            .filter {
                $0.kind == .question
                    && $0.isActiveBranch
                    && !$0.boundResources.isEmpty
            }
            .flatMap { question in
                let deckProgress = clampedProgress(
                    progressByQuestionID[question.id] ?? 0
                )
                return question.boundResources.enumerated().map { index, binding in
                    QuestionResourceAttachmentPresentation(
                        questionID: question.id,
                        questionSummary: question.content,
                        questionStageOrder: question.stageOrder ?? 1,
                        questionBranchVersion: question.branchVersion,
                        binding: binding,
                        center: cardCenter(
                            questionCenter: question.position,
                            cardIndex: index,
                            cardCount: question.boundResources.count,
                            deckProgress: deckProgress
                        ),
                        deckProgress: deckProgress,
                        cardProgress: staggeredCardProgress(
                            deckProgress,
                            cardIndex: index,
                            cardCount: question.boundResources.count
                        )
                    )
                }
            }
    }

    static func canvasContentSize(
        graph: TreeData,
        progressByQuestionID: [String: CGFloat]
    ) -> CGSize {
        let presentations = presentations(
            graph: graph,
            progressByQuestionID: progressByQuestionID
        )
        let maximumAttachmentX = presentations
            .filter { $0.deckProgress > 0 }
            .map {
                $0.center.x
                    + QuestionResourceDeckMetrics.cardSize.width / 2
                    + QuestionResourceDeckMetrics.canvasTrailingPadding
            }
            .max()
            ?? 0

        return CGSize(
            width: max(graph.contentSize.width, maximumAttachmentX),
            height: graph.contentSize.height
        )
    }

    static func fullyExpandedProgressByQuestionID(
        graph: TreeData
    ) -> [String: CGFloat] {
        Dictionary(
            uniqueKeysWithValues: graph.nodes.compactMap { node in
                guard node.kind == .question,
                      node.isActiveBranch,
                      !node.boundResources.isEmpty else {
                    return nil
                }
                return (node.id, CGFloat(1))
            }
        )
    }

    static func annotationContentSize(graph: TreeData) -> CGSize {
        canvasContentSize(
            graph: graph,
            progressByQuestionID: fullyExpandedProgressByQuestionID(
                graph: graph
            )
        )
    }

    /// Resource annotations are projected against the fully expanded card
    /// positions. Dragging a deck therefore never changes an annotation's
    /// coordinates; visibility is handled independently with opacity.
    static func annotationFrames(
        graph: TreeData
    ) -> [MindTreeAnnotationAnchorFrame] {
        presentations(
            graph: graph,
            progressByQuestionID: fullyExpandedProgressByQuestionID(
                graph: graph
            )
        )
        .map { presentation in
            MindTreeAnnotationAnchorFrame(
                anchor: .moment(
                    id: presentation.binding.momentID,
                    branchVersion: presentation.questionBranchVersion,
                    stageOrder: presentation.questionStageOrder
                ),
                nodeID: "resource-attachment-\(presentation.binding.momentID)",
                x: presentation.center.x,
                y: presentation.center.y,
                width: QuestionResourceDeckMetrics.cardSize.width,
                height: QuestionResourceDeckMetrics.cardSize.height
            )
        }
    }

    /// Keeps annotations invisible until their card is close to its final
    /// expanded position, preventing a fixed annotation from being clipped by
    /// the still-growing resource deck canvas.
    static func annotationOpacity(cardProgress: CGFloat) -> Double {
        let fadeStart: CGFloat = 0.72
        let normalized = clampedProgress(
            (cardProgress - fadeStart) / (1 - fadeStart)
        )
        let eased = normalized * normalized * (3 - 2 * normalized)
        return Double(eased)
    }

    private static func staggeredCardProgress(
        _ deckProgress: CGFloat,
        cardIndex: Int,
        cardCount: Int
    ) -> CGFloat {
        guard cardCount > 1 else {
            return clampedProgress(deckProgress)
        }
        let delay = min(CGFloat(cardIndex) * 0.055, 0.28)
        let availableRange = max(1 - delay, 0.01)
        return clampedProgress((deckProgress - delay) / availableRange)
    }
}

struct QuestionResourceDeckLayer: View {
    let presentations: [QuestionResourceAttachmentPresentation]
    let contentSize: CGSize
    let activeDragQuestionID: String?
    let onSelect: (QuestionResourceAttachmentPresentation) -> Void
    let onCollapseDragChanged:
        (QuestionResourceAttachmentPresentation, CGSize) -> Void
    let onCollapseDragEnded:
        (QuestionResourceAttachmentPresentation, CGSize, CGSize) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(presentations) { presentation in
                attachmentView(for: presentation)
                .position(presentation.center)
                .zIndex(Double(-presentation.binding.card.type.sortOrder))
            }
        }
        .frame(
            width: contentSize.width,
            height: contentSize.height,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func attachmentView(
        for presentation: QuestionResourceAttachmentPresentation
    ) -> some View {
        let isInteractive = presentation.cardProgress > 0.96
            || activeDragQuestionID == presentation.questionID

        QuestionResourceAttachmentCard(
            resource: presentation.binding.card
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(presentation)
        }
        .simultaneousGesture(collapseGesture(for: presentation))
        .allowsHitTesting(isInteractive)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            "\(presentation.binding.card.type.displayName)：\(presentation.binding.card.title)"
        )
        .accessibilityHint("轻点打开；向左拖入问题节点可以收纳")
        .accessibilityHidden(!isInteractive)
        .accessibilityAction {
            onSelect(presentation)
        }
        .accessibilityAction(named: "收纳到问题节点") {
            onCollapseDragEnded(
                presentation,
                CGSize(
                    width: -QuestionResourceDeckMetrics.expansionDragDistance,
                    height: 0
                ),
                CGSize(
                    width: -QuestionResourceDeckMetrics.expansionDragDistance,
                    height: 0
                )
            )
        }
        .accessibilityIdentifier(
            "mindTree.resource.\(presentation.binding.momentID.uuidString)"
        )
    }

    private func collapseGesture(
        for presentation: QuestionResourceAttachmentPresentation
    ) -> some Gesture {
        DragGesture(
            minimumDistance: QuestionResourceDeckMetrics.dragMinimumDistance,
            coordinateSpace: .named(MindTreeAnnotationCoordinateSpace.graph)
        )
            .onChanged { value in
                onCollapseDragChanged(presentation, value.translation)
            }
            .onEnded { value in
                onCollapseDragEnded(
                    presentation,
                    value.translation,
                    value.predictedEndTranslation
                )
            }
    }
}

struct QuestionResourceAttachmentDetailSheet: View {
    let presentation: QuestionResourceAttachmentPresentation

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            "绑定于问题",
                            systemImage: "rectangle.stack.badge.person.crop"
                        )
                        .font(AppTheme.Typography.caption.weight(.bold))
                        .foregroundStyle(Color.primaryAccent)

                        Text(presentation.questionSummary)
                            .font(AppTheme.Typography.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.spacingMedium)
                    .background(
                        RoundedRectangle(
                            cornerRadius: AppTheme.cornerRadiusLarge,
                            style: .continuous
                        )
                        .fill(Color.primaryAccent.opacity(0.07))
                    )

                    ResourceCardView(resource: presentation.binding.card)
                }
                .padding(AppTheme.spacingLarge)
            }
            .background(Color.appBackground)
            .navigationTitle("问题资源卡")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

private struct QuestionResourceAttachmentCard: View {
    let resource: ResourceCard

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: resource.type.treeIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(resource.type.treeColor)
                    .frame(width: 23, height: 23)
                    .background(
                        Circle().fill(resource.type.treeColor.opacity(0.12))
                    )

                Text(resource.type.displayName)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(resource.type.treeColor)

                Spacer(minLength: 4)

                Text(resource.cardRole.displayName)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Text(resource.title)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(resource.userDisplayText)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(
            width: QuestionResourceDeckMetrics.cardSize.width,
            height: QuestionResourceDeckMetrics.cardSize.height,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cardBackground,
                            resource.type.treeColor.opacity(0.055),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(
                    resource.type.treeColor.opacity(0.48),
                    lineWidth: 1.2
                )
        )
        .shadow(
            color: resource.type.treeColor.opacity(0.10),
            radius: 8,
            y: 3
        )
    }
}

private extension ResourceType {
    var sortOrder: Int {
        switch self {
        case .paper: return 0
        case .method: return 1
        case .caseStudy: return 2
        case .designPrinciple: return 3
        case .courseFramework: return 4
        }
    }
}
