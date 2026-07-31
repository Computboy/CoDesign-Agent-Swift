import SwiftUI
import Observation

enum TreeNodeKind {
    case root
    case stage
    case branchStage
    case question
    case field
    case process
    case revision
}

enum StageTreeState: Equatable {
    case inProgress
    case completedExpanded
    case completedCollapsed

    var isCompleted: Bool { self != .inProgress }
    var isExpanded: Bool { self != .completedCollapsed }
}

enum QuestionNodeCategory: String, CaseIterable {
    case painPoint
    case targetUser
    case useScenario
    case value
    case boundary
    case general

    var title: String {
        switch self {
        case .painPoint: return "核心痛点"
        case .targetUser: return "目标用户"
        case .useScenario: return "使用场景"
        case .value: return "核心价值"
        case .boundary: return "项目边界"
        case .general: return "设计判断"
        }
    }

    var color: Color {
        switch self {
        case .painPoint:
            return Color(red: 1.00, green: 0.35, blue: 0.42)
        case .targetUser:
            return Color(red: 0.25, green: 0.51, blue: 0.96)
        case .useScenario:
            return Color(red: 1.00, green: 0.53, blue: 0.16)
        case .value:
            return Color(red: 0.12, green: 0.68, blue: 0.58)
        case .boundary:
            return Color(red: 0.52, green: 0.38, blue: 0.94)
        case .general:
            return Color.primaryAccent
        }
    }
}

struct QuestionResourceBinding: Identifiable, Hashable {
    let momentID: UUID
    let card: ResourceCard

    var id: String { "\(momentID)-\(card.id)" }
}

struct TreeNode: Identifiable {
    let id: String
    let kind: TreeNodeKind
    let content: String
    let subContent: String?
    let stageOrder: Int?
    let field: BriefField?
    let momentID: UUID?
    var position: CGPoint
    let nodeColor: Color
    let isActiveBranch: Bool
    let branchVersion: Int
    let richness: CGFloat
    let isGhost: Bool
    let processLabel: String?
    let processIcon: String?
    let statusText: String?
    let timestamp: Date?
    let branchAnchorID: String?
    var questionNumber: Int? = nil
    var questionCategory: QuestionNodeCategory? = nil
    var isAnswered: Bool = false
    var boundResources: [QuestionResourceBinding] = []
    var branchDepth: Int = 0
    var layoutRank: Int = 0
    var stageTreeState: StageTreeState? = nil

    var iconSystemName: String? {
        switch kind {
        case .root:
            return "lightbulb.fill"
        case .stage, .branchStage:
            guard let order = stageOrder else { return nil }
            return StageDefinition.all.first {
                $0.order == order
            }?.iconName
        case .question:
            return "questionmark.circle"
        case .field:
            return processIcon ?? "checkmark.seal"
        case .process:
            return processIcon ?? "bubble.left"
        case .revision:
            return "arrow.uturn.backward"
        }
    }

    var isArchived: Bool { !isActiveBranch }
    var isEditable: Bool { momentID != nil && !isGhost }
    var hasCollapsedResources: Bool {
        kind == .question && isActiveBranch && !boundResources.isEmpty
    }
}

enum TreeEdgeStyle {
    case active
    case archived
    case transition
    case ghost
}

struct TreeEdge: Identifiable {
    let id: String
    let fromID: String
    let toID: String
    let style: TreeEdgeStyle
    let togglesTransitionOrder: Int?

    init(
        id: String,
        fromID: String,
        toID: String,
        style: TreeEdgeStyle,
        togglesTransitionOrder: Int? = nil
    ) {
        self.id = id
        self.fromID = fromID
        self.toID = toID
        self.style = style
        self.togglesTransitionOrder = togglesTransitionOrder
    }
}

struct TreeData {
    let nodes: [TreeNode]
    let edges: [TreeEdge]
    let contentSize: CGSize
    private let nodesByID: [String: TreeNode]

    init(nodes: [TreeNode], edges: [TreeEdge], contentSize: CGSize) {
        self.nodes = nodes
        self.edges = edges
        self.contentSize = contentSize
        self.nodesByID = Dictionary(
            nodes.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func node(for id: String) -> TreeNode? {
        nodesByID[id]
    }
}

@MainActor
@Observable
final class MindTreePresentationState {
    var expandedTransitionOrders: Set<Int> = []
    var expandedArchivedStageOrders: Set<Int> = []
    var expandedResourceQuestionIDs: Set<String> = []
    private(set) var hasRestoredPersistedExpansion = false
    private var knownCompletedStageOrders: Set<Int> = []

    func restorePersistedExpansionIfNeeded(
        from annotations: [MindTreeAnnotation],
        completedStageOrders: Set<Int> = []
    ) {
        guard !hasRestoredPersistedExpansion else { return }
        hasRestoredPersistedExpansion = true
        knownCompletedStageOrders = completedStageOrders

        let annotation = annotations
            .filter {
                !$0.isArchived
                    && ($0.annotationDocumentVersion ?? 0)
                        >= MindTreeAnnotationDocument.currentVersion
            }
            .max { $0.updatedAt < $1.updatedAt }

        if let annotation {
            expandedTransitionOrders = MindTreeAnnotationExpansionCodec.decode(
                annotation.expandedTransitionOrders
            ).intersection(completedStageOrders)
            expandedArchivedStageOrders = MindTreeAnnotationExpansionCodec.decode(
                annotation.expandedArchivedStageOrders
            )
        } else {
            expandedTransitionOrders = completedStageOrders
        }
    }

    func synchronizeCompletedStages(_ completedStageOrders: Set<Int>) {
        let newlyCompleted = completedStageOrders.subtracting(
            knownCompletedStageOrders
        )
        expandedTransitionOrders.formUnion(newlyCompleted)
        expandedTransitionOrders.formIntersection(completedStageOrders)
        knownCompletedStageOrders = completedStageOrders
    }
}

/// Answers, method calls, extraction decisions, and learning traces remain in
/// SwiftData for audit/detail/export, while the canvas projects core questions.
struct ThinkingTreeMomentProjector {
    static func visibleMoments(
        _ moments: [ThinkingMoment]
    ) -> [ThinkingMoment] {
        moments
            .sorted { $0.timestamp < $1.timestamp }
            .filter { isVisibleInTree($0) }
    }

    static func isVisibleInTree(_ moment: ThinkingMoment) -> Bool {
        switch moment.momType {
        case "answer", "method", "scaffold":
            return false
        case "question":
            return !isScaffoldQuestion(moment.content)
        default:
            return true
        }
    }

    static func pairedAnswer(
        for question: ThinkingMoment,
        in moments: [ThinkingMoment]
    ) -> ThinkingMoment? {
        if let direct = moments
            .filter({
                $0.parentMomentID == question.id
                    && $0.momType == "answer"
                    && $0.isActiveBranch
            })
            .sorted(by: { $0.timestamp < $1.timestamp })
            .last {
            return direct
        }

        var latestAnswer: ThinkingMoment?
        let laterMoments = moments
            .filter {
                $0.stageOrder == question.stageOrder
                    && $0.timestamp > question.timestamp
            }
            .sorted { $0.timestamp < $1.timestamp }

        for moment in laterMoments {
            if question.isActiveBranch && !moment.isActiveBranch {
                continue
            }
            switch moment.momType {
            case "answer":
                guard !isStuckAnswer(moment.content) else { continue }
                latestAnswer = moment
            case "question":
                if isScaffoldQuestion(moment.content) {
                    continue
                }
                return latestAnswer
            default:
                continue
            }
        }
        return latestAnswer
    }

    static func archivedAnswers(
        for question: ThinkingMoment,
        in moments: [ThinkingMoment]
    ) -> [ThinkingMoment] {
        let direct = moments.filter {
            $0.parentMomentID == question.id
                && $0.momType == "answer"
                && !$0.isActiveBranch
        }
        let inferred = moments.filter {
            $0.parentMomentID == nil
                && $0.stageOrder == question.stageOrder
                && $0.momType == "answer"
                && !$0.isActiveBranch
                && $0.timestamp > question.timestamp
        }
        var seen = Set<UUID>()
        return (direct + inferred)
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.timestamp < $1.timestamp }
    }

    static func displayQuestionText(
        for node: TreeNode,
        in messages: [ChatMessage]
    ) -> String {
        reconstructedContent(
            stored: node.content,
            role: "assistant",
            in: messages
        )
    }

    static func displayAnswerText(
        for answer: ThinkingMoment,
        in messages: [ChatMessage]
    ) -> String {
        reconstructedContent(
            stored: answer.content,
            role: "user",
            in: messages
        )
    }

    static func isStuckAnswer(_ content: String) -> Bool {
        if ClarificationMode.detect(from: content) == .stuckScaffold {
            return true
        }
        let normalized = content
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return [
            "我还不确定",
            "我还不太确定",
            "不确定",
            "我不知道",
            "不知道",
            "想不出来",
            "没想好",
            "卡住了",
            "不会答",
            "没有思路",
            "没思路",
            "请进入线索+提问模式",
            "线索+提问模式",
        ].contains { normalized.contains($0) }
    }

    static func isScaffoldQuestion(_ content: String) -> Bool {
        let normalized = content
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return [
            "线索追问",
            "引导追问",
            "线索：",
            "追问：",
            "先回想",
            "先想一个",
            "任务片段",
            "方法线索",
            "从一个具体例子开始",
        ].contains { marker in
            normalized.contains(
                marker
                    .replacingOccurrences(of: " ", with: "")
                    .lowercased()
            )
        }
    }

    private static func reconstructedContent(
        stored: String,
        role: String,
        in messages: [ChatMessage]
    ) -> String {
        let trimmed = stored.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard trimmed.hasSuffix("...") else { return stored }

        let prefix = String(trimmed.dropLast(3))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return stored }

        return messages
            .filter { $0.role == role && $0.content.contains(prefix) }
            .sorted { $0.timestamp > $1.timestamp }
            .first?
            .content
            ?? stored
    }
}

extension ResourceType {
    var treeColor: Color {
        switch self {
        case .paper:
            return Color(red: 1.00, green: 0.42, blue: 0.48)
        case .method:
            return Color(red: 0.30, green: 0.45, blue: 0.96)
        case .caseStudy:
            return Color(red: 1.00, green: 0.73, blue: 0.22)
        case .designPrinciple:
            return Color(red: 0.55, green: 0.36, blue: 0.96)
        case .courseFramework:
            return Color(red: 0.48, green: 0.54, blue: 0.64)
        }
    }

    var treeIcon: String {
        switch self {
        case .paper: return "doc.text"
        case .method: return "lightbulb"
        case .caseStudy: return "star"
        case .designPrinciple: return "hexagon"
        case .courseFramework: return "shield"
        }
    }
}
