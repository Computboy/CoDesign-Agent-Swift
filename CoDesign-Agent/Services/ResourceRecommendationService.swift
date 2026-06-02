import Foundation

struct ResourceRecommendationService {
    private let resources: [ResourceCard]

    init(resources: [ResourceCard] = ResourceLibrary.all) {
        self.resources = resources
    }

    func recommend(
        currentStageOrder: Int,
        brief: DesignBrief?,
        recentMessage: String?,
        limit: Int = 3
    ) -> [ResourceCard] {
        let normalizedLimit = max(1, limit)
        let context = keywordContext(brief: brief, recentMessage: recentMessage)
        let stageMatches = resources.filter { $0.relatedStages.contains(currentStageOrder) }

        let scored = stageMatches.map { resource in
            (resource, score(resource, stageOrder: currentStageOrder, context: context))
        }
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.title < rhs.0.title
            }
            return lhs.1 > rhs.1
        }

        let recommended = scored.map(\.0).prefix(normalizedLimit)
        if !recommended.isEmpty {
            return Array(recommended)
        }

        return Array(resources.filter { $0.relatedStages.contains(currentStageOrder) }.prefix(normalizedLimit))
    }

    private func score(_ resource: ResourceCard, stageOrder: Int, context: String) -> Int {
        var result = resource.relatedStages.contains(stageOrder) ? 10 : 0
        for tag in resource.tags {
            if context.contains(tag.lowercased()) {
                result += 3
            }
        }
        if context.contains(resource.title.lowercased()) {
            result += 2
        }
        return result
    }

    private func keywordContext(brief: DesignBrief?, recentMessage: String?) -> String {
        var parts: [String] = []
        if let brief {
            parts.append(contentsOf: [
                brief.targetUser,
                brief.painPoint,
                brief.useScenario,
                brief.coreValue,
                brief.differentiation,
                brief.mvpFeatures,
                brief.technicalModules,
                brief.interactionFlow,
                brief.operationLogic,
                brief.hardConstraints,
                brief.milestones
            ].compactMap { $0 })
            parts.append(contentsOf: brief.boundaryItems.map(\.content))
            parts.append(contentsOf: brief.successMetrics.flatMap { [$0.metric, $0.target, $0.measurement].compactMap { $0 } })
            parts.append(contentsOf: brief.risks.flatMap { [$0.desc, $0.mitigation].compactMap { $0 } })
        }
        if let recentMessage {
            parts.append(recentMessage)
        }
        return parts.joined(separator: " ").lowercased()
    }
}

extension Project {
    var currentStageOrder: Int {
        let sorted = stages.sorted { $0.order < $1.order }
        if let active = sorted.first(where: { $0.stageStatusValue == .active }) {
            return active.order
        }
        if let next = sorted.first(where: { $0.stageStatusValue == .notStarted || $0.stageStatusValue == .needsReview }) {
            return next.order
        }
        return sorted.last?.order ?? 1
    }

    var latestConversationText: String? {
        messages.sorted { $0.timestamp < $1.timestamp }.last?.content
    }
}
