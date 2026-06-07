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
        let context = keywordContext(brief: brief, recentMessage: recentMessage)
        let missingFields = missingBriefFields(for: currentStageOrder, brief: brief)
        let problemTypes = detectedProblemTypes(
            context: context,
            brief: brief,
            missingFields: missingFields
        )

        return rankedRecommendations(
            currentStageOrder: currentStageOrder,
            context: context,
            missingFields: missingFields,
            problemTypes: problemTypes,
            limit: limit
        )
    }

    func recommend(
        currentStageOrder: Int,
        briefSnapshot: DesignBriefSnapshot?,
        recentMessage: String?,
        limit: Int = 3
    ) -> [ResourceCard] {
        let snapshot = briefSnapshot ?? DesignBriefSnapshot()
        let context = keywordContext(snapshot: snapshot, recentMessage: recentMessage)
        let missingFields = missingBriefFields(for: currentStageOrder, snapshot: snapshot)
        let problemTypes = detectedProblemTypes(
            context: context,
            snapshot: snapshot,
            missingFields: missingFields
        )

        return rankedRecommendations(
            currentStageOrder: currentStageOrder,
            context: context,
            missingFields: missingFields,
            problemTypes: problemTypes,
            limit: limit
        )
    }

    private func rankedRecommendations(
        currentStageOrder: Int,
        context: String,
        missingFields: [BriefField],
        problemTypes: Set<String>,
        limit: Int
    ) -> [ResourceCard] {
        let normalizedLimit = max(1, limit)
        let scored = resources.map { resource in
            (
                resource,
                score(
                    resource,
                    stageOrder: currentStageOrder,
                    context: context,
                    missingFields: missingFields,
                    problemTypes: problemTypes
                )
            )
        }
        .filter { $0.1 > 0 }
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                if lhs.0.priority == rhs.0.priority {
                    return lhs.0.title < rhs.0.title
                }
                return lhs.0.priority > rhs.0.priority
            }
            return lhs.1 > rhs.1
        }

        let primaryContent = scored.map(\.0).first { $0.cardRole == .content }
        var selected: [ResourceCard] = []
        if let primaryContent {
            selected.append(primaryContent)
        }

        for resource in scored.map(\.0) where selected.count < normalizedLimit {
            guard !selected.contains(resource) else { continue }
            if selected.contains(where: { $0.cardRole == .content }) && resource.cardRole == .content {
                continue
            }
            selected.append(resource)
        }

        if !selected.isEmpty {
            return selected
        }

        return Array(
            resources
                .filter { $0.relatedStages.contains(currentStageOrder) }
                .sorted { $0.priority > $1.priority }
                .prefix(normalizedLimit)
        )
    }

    private func score(
        _ resource: ResourceCard,
        stageOrder: Int,
        context: String,
        missingFields: [BriefField],
        problemTypes: Set<String>
    ) -> Int {
        var result = resource.relatedStages.contains(stageOrder) ? 30 : 0

        for field in resource.relatedFields where missingFields.contains(field) {
            result += 12
        }

        for problemType in resource.problemTypes where problemTypes.contains(problemType) {
            result += 16
        }

        for tag in resource.tags {
            if context.contains(tag.lowercased()) {
                result += 4
            }
        }

        if context.contains(resource.title.lowercased()) {
            result += 2
        }

        if context.contains("ai") || context.contains("人工智能") || context.contains("智能") {
            if resource.requiredContext.contains("project_uses_ai") {
                result += 10
            }
        } else if resource.requiredContext.contains("project_uses_ai") {
            result -= 18
        }

        switch resource.cardRole {
        case .content:
            result += 8
        case .questionStrategy, .cognitiveDepth, .scaffoldingStrategy:
            let needsSupport = ["answer_too_shallow", "user_stuck", "claim_without_evidence"]
                .contains { problemTypes.contains($0) }
            result += needsSupport ? 6 : 0
        case .loadControl:
            result += 2
        case .feedbackStrategy, .reflectionDetector, .stageReflection, .selfRegulation:
            result += 1
        case .onboarding, .correctionFeedback, .errorRecovery:
            result -= 6
        }

        result += min(max(resource.priority, 0), 100) / 10
        return result
    }

    private func missingBriefFields(for stageOrder: Int, brief: DesignBrief?) -> [BriefField] {
        let snapshot = brief?.toSnapshot() ?? DesignBriefSnapshot()
        return missingBriefFields(for: stageOrder, snapshot: snapshot)
    }

    private func missingBriefFields(for stageOrder: Int, snapshot: DesignBriefSnapshot) -> [BriefField] {
        guard let definition = StageDefinition.all.first(where: { $0.order == stageOrder }) else {
            return []
        }
        return definition.briefFields.filter { !$0.isFilled(in: snapshot) }
    }

    private func detectedProblemTypes(
        context: String,
        brief: DesignBrief?,
        missingFields: [BriefField]
    ) -> Set<String> {
        var result = Set<String>()

        if missingFields.contains(.targetUser) {
            result.insert("user_too_broad")
        }
        if missingFields.contains(.useScenario) {
            result.insert("scenario_missing")
        }
        if missingFields.contains(.painPoint) {
            result.insert("pain_point_missing")
        }
        if missingFields.contains(.coreValue) {
            result.insert("value_too_abstract")
        }
        if missingFields.contains(.successMetrics) {
            result.insert("evaluation_dimensions_missing")
            result.insert("metric_not_linked_to_change")
        }
        if missingFields.contains(.boundaryItems) {
            result.insert("scope_expansion")
        }
        if missingFields.contains(.technicalModules) || missingFields.contains(.interactionFlow) {
            result.insert("feature_not_decomposed")
        }
        if missingFields.contains(.operationLogic) {
            result.insert("feedback_missing")
            result.insert("error_flow_missing")
        }
        if missingFields.contains(.hardConstraints) {
            result.insert("time_resource_limit")
        }
        if missingFields.contains(.risks) {
            result.insert("risk_missing")
            result.insert("assumption_unchecked")
        }
        if missingFields.contains(.milestones) {
            result.insert("next_step_unclear")
        }

        if containsAny(context, ["app", "小程序", "平台", "系统", "功能", "工具"]) &&
            (brief?.targetUser?.isEmpty ?? true || brief?.painPoint?.isEmpty ?? true) {
            result.insert("solution_first")
            result.insert("solution_without_problem")
        }

        if containsAny(context, ["大学生", "学生", "用户", "年轻人", "老人", "老师"]) &&
            (brief?.targetUser?.count ?? 0) < 8 {
            result.insert("user_too_broad")
        }

        if containsAny(context, ["很多功能", "都做", "全部", "一站式", "完整"]) {
            result.insert("feature_overload")
            result.insert("scope_expansion")
        }

        if containsAny(context, ["不知道", "不确定", "没想好", "卡住", "不会"]) {
            result.insert("user_stuck")
        }

        if containsAny(context, ["例子", "示例", "怎么回答"]) {
            result.insert("asks_for_example")
        }

        if containsAny(context, ["对不对", "正确", "标准答案", "好不好"]) {
            result.insert("asks_if_solution_is_correct")
            result.insert("binary_judgment")
        }

        if containsAny(context, ["ai", "人工智能", "大模型", "智能"]) {
            result.insert("ai_value_unclear")
            if brief?.coreValue?.isEmpty ?? true {
                result.insert("ai_as_selling_point")
            }
            if brief?.operationLogic?.isEmpty ?? true {
                result.insert("confidence_not_shown")
                result.insert("user_control_missing")
            }
        }

        if containsAny(context, ["失败", "风险", "出错", "异常", "兜底", "撤销"]) {
            result.insert("error_flow_missing")
            result.insert("mistake_recovery_missing")
        }

        return result
    }

    private func detectedProblemTypes(
        context: String,
        snapshot: DesignBriefSnapshot,
        missingFields: [BriefField]
    ) -> Set<String> {
        var result = Set<String>()

        if missingFields.contains(.targetUser) {
            result.insert("user_too_broad")
        }
        if missingFields.contains(.useScenario) {
            result.insert("scenario_missing")
        }
        if missingFields.contains(.painPoint) {
            result.insert("pain_point_missing")
        }
        if missingFields.contains(.coreValue) {
            result.insert("value_too_abstract")
        }
        if missingFields.contains(.successMetrics) {
            result.insert("evaluation_dimensions_missing")
            result.insert("metric_not_linked_to_change")
        }
        if missingFields.contains(.boundaryItems) {
            result.insert("scope_expansion")
        }
        if missingFields.contains(.technicalModules) || missingFields.contains(.interactionFlow) {
            result.insert("feature_not_decomposed")
        }
        if missingFields.contains(.operationLogic) {
            result.insert("feedback_missing")
            result.insert("error_flow_missing")
        }
        if missingFields.contains(.hardConstraints) {
            result.insert("time_resource_limit")
        }
        if missingFields.contains(.risks) {
            result.insert("risk_missing")
            result.insert("assumption_unchecked")
        }
        if missingFields.contains(.milestones) {
            result.insert("next_step_unclear")
        }

        if containsAny(context, ["app", "小程序", "平台", "系统", "功能", "工具"]) &&
            ((snapshot.targetUser?.isEmpty ?? true) || (snapshot.painPoint?.isEmpty ?? true)) {
            result.insert("solution_first")
            result.insert("solution_without_problem")
        }

        if containsAny(context, ["大学生", "学生", "用户", "年轻人", "老人", "老师"]) &&
            (snapshot.targetUser?.count ?? 0) < 8 {
            result.insert("user_too_broad")
        }

        if containsAny(context, ["很多功能", "都做", "全部", "一站式", "完整"]) {
            result.insert("feature_overload")
            result.insert("scope_expansion")
        }

        if containsAny(context, ["不知道", "不确定", "没想好", "卡住", "不会"]) {
            result.insert("user_stuck")
        }

        if containsAny(context, ["例子", "示例", "怎么回答"]) {
            result.insert("asks_for_example")
        }

        if containsAny(context, ["对不对", "正确", "标准答案", "好不好"]) {
            result.insert("asks_if_solution_is_correct")
            result.insert("binary_judgment")
        }

        if containsAny(context, ["ai", "人工智能", "大模型", "智能"]) {
            result.insert("ai_value_unclear")
            if snapshot.coreValue?.isEmpty ?? true {
                result.insert("ai_as_selling_point")
            }
            if snapshot.operationLogic?.isEmpty ?? true {
                result.insert("confidence_not_shown")
                result.insert("user_control_missing")
            }
        }

        if containsAny(context, ["失败", "风险", "出错", "异常", "兜底", "撤销"]) {
            result.insert("error_flow_missing")
            result.insert("mistake_recovery_missing")
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

    private func keywordContext(snapshot: DesignBriefSnapshot, recentMessage: String?) -> String {
        var parts: [String] = [
            snapshot.targetUser,
            snapshot.painPoint,
            snapshot.useScenario,
            snapshot.coreValue,
            snapshot.differentiation,
            snapshot.mvpFeatures,
            snapshot.technicalModules,
            snapshot.interactionFlow,
            snapshot.operationLogic,
            snapshot.hardConstraints,
            snapshot.milestones
        ].compactMap { $0 }
        parts.append(contentsOf: snapshot.boundaryItems.map(\.content))
        parts.append(contentsOf: snapshot.successMetrics.flatMap { [$0.metric, $0.target, $0.measurement].compactMap { $0 } })
        parts.append(contentsOf: snapshot.risks.flatMap { [$0.desc, $0.mitigation].compactMap { $0 } })
        if let recentMessage {
            parts.append(recentMessage)
        }
        return parts.joined(separator: " ").lowercased()
    }

    private func containsAny(_ context: String, _ candidates: [String]) -> Bool {
        candidates.contains { context.contains($0.lowercased()) }
    }
}

extension Project {
    var currentStageOrder: Int {
        let sorted = stages.sorted { $0.order < $1.order }
        if let review = sorted.first(where: { $0.stageStatusValue == .needsReview }) {
            return review.order
        }
        if let active = sorted.first(where: { $0.stageStatusValue == .active }) {
            return active.order
        }
        if let next = sorted.first(where: { $0.stageStatusValue == .notStarted }) {
            return next.order
        }
        return sorted.last?.order ?? 1
    }

    var latestConversationText: String? {
        messages.sorted { $0.timestamp < $1.timestamp }.last?.content
    }
}
