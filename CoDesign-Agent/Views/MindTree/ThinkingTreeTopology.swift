import Foundation

/// Topology helpers for the active question branch.
///
/// New projects persist explicit question-to-question parent links. Older
/// projects did not, so the resolver falls back to stable generation order
/// only when a structural parent is unavailable.
struct ThinkingTreeTopology {
    static func activeQuestions(
        for stageOrder: Int,
        in moments: [ThinkingMoment]
    ) -> [ThinkingMoment] {
        let questions = moments.filter {
            $0.stageOrder == stageOrder
                && $0.momType == "question"
                && $0.isActiveBranch
                && ThinkingTreeMomentProjector.isVisibleInTree($0)
        }
        guard !questions.isEmpty else { return [] }

        let byID = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        var depthCache: [UUID: Int] = [:]

        func depth(of question: ThinkingMoment, visiting: Set<UUID> = []) -> Int {
            if let cached = depthCache[question.id] {
                return cached
            }
            guard !visiting.contains(question.id),
                  let parentID = question.parentMomentID,
                  let parent = byID[parentID]
            else {
                depthCache[question.id] = 0
                return 0
            }

            var nextVisiting = visiting
            nextVisiting.insert(question.id)
            let value = depth(of: parent, visiting: nextVisiting) + 1
            depthCache[question.id] = value
            return value
        }

        return questions.sorted { lhs, rhs in
            let lhsDepth = depth(of: lhs)
            let rhsDepth = depth(of: rhs)
            if lhsDepth != rhsDepth {
                return lhsDepth < rhsDepth
            }
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp < rhs.timestamp
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func activeLeafNode(
        for stageOrder: Int,
        in moments: [ThinkingMoment]
    ) -> ThinkingMoment? {
        let questions = activeQuestions(for: stageOrder, in: moments)
        guard !questions.isEmpty else { return nil }

        let questionIDs = Set(questions.map(\.id))
        let parentIDs = Set(
            questions.compactMap { question -> UUID? in
                guard let parentID = question.parentMomentID,
                      questionIDs.contains(parentID)
                else {
                    return nil
                }
                return parentID
            }
        )
        let explicitLeaves = questions.filter { !parentIDs.contains($0.id) }

        // The topological ordering wins for explicit trees. Legacy roots all
        // have depth zero, so stable generation order selects the newest one.
        return (explicitLeaves.isEmpty ? questions : explicitLeaves).last
    }

    static func effectiveQuestionParents(
        for stageOrder: Int,
        in moments: [ThinkingMoment]
    ) -> [UUID: UUID] {
        let questions = activeQuestions(for: stageOrder, in: moments)
        let questionIDs = Set(questions.map(\.id))
        var result: [UUID: UUID] = [:]
        var previous: ThinkingMoment?

        for question in questions {
            if let explicitParent = question.parentMomentID,
               questionIDs.contains(explicitParent) {
                result[question.id] = explicitParent
            } else if let previous {
                result[question.id] = previous.id
            }
            previous = question
        }
        return result
    }
}
