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
        limit: Int = 3,
        mode: ClarificationMode = .normal
    ) -> [ResourceCard] {
        let context = keywordContext(brief: brief, recentMessage: recentMessage)
        let missingFields = missingBriefFields(for: currentStageOrder, brief: brief)
        var problemTypes = detectedProblemTypes(
            context: context,
            brief: brief,
            missingFields: missingFields
        )
        if mode == .stuckScaffold {
            problemTypes.insert("user_stuck")
        }

        return rankedRecommendations(
            currentStageOrder: currentStageOrder,
            context: context,
            missingFields: missingFields,
            problemTypes: problemTypes,
            limit: limit,
            mode: mode
        )
    }

    func recommend(
        currentStageOrder: Int,
        briefSnapshot: DesignBriefSnapshot?,
        recentMessage: String?,
        limit: Int = 3,
        mode: ClarificationMode = .normal
    ) -> [ResourceCard] {
        let snapshot = briefSnapshot ?? DesignBriefSnapshot()
        let context = keywordContext(snapshot: snapshot, recentMessage: recentMessage)
        let missingFields = missingBriefFields(for: currentStageOrder, snapshot: snapshot)
        var problemTypes = detectedProblemTypes(
            context: context,
            snapshot: snapshot,
            missingFields: missingFields
        )
        if mode == .stuckScaffold {
            problemTypes.insert("user_stuck")
        }

        return rankedRecommendations(
            currentStageOrder: currentStageOrder,
            context: context,
            missingFields: missingFields,
            problemTypes: problemTypes,
            limit: limit,
            mode: mode
        )
    }

    private func rankedRecommendations(
        currentStageOrder: Int,
        context: String,
        missingFields: [BriefField],
        problemTypes: Set<String>,
        limit: Int,
        mode: ClarificationMode
    ) -> [ResourceCard] {
        let normalizedLimit = max(1, limit)
        let scored = resources.map { resource -> (resource: ResourceCard, score: Int) in
            (
                resource: resource,
                score: score(
                    resource,
                    stageOrder: currentStageOrder,
                    context: context,
                    missingFields: missingFields,
                    problemTypes: problemTypes,
                    mode: mode
                )
            )
        }
        .filter { $0.1 > 0 }
        .sorted(by: compareScoredResources)

        let selected = diverseSelection(
            from: scored,
            currentStageOrder: currentStageOrder,
            limit: normalizedLimit,
            mode: mode
        )
        if !selected.isEmpty {
            return selected
        }

        return fallbackRecommendations(
            currentStageOrder: currentStageOrder,
            limit: normalizedLimit,
            mode: mode
        )
    }

    private func diverseSelection(
        from scored: [(resource: ResourceCard, score: Int)],
        currentStageOrder: Int,
        limit: Int,
        mode: ClarificationMode
    ) -> [ResourceCard] {
        var selected: [ResourceCard] = []

        func appendFirst(_ predicate: (ResourceCard) -> Bool) {
            guard selected.count < limit else { return }
            guard let candidate = scored.map(\.resource).first(where: { resource in
                !selected.contains(resource) &&
                isAllowedForMode(resource, mode: mode, stageOrder: currentStageOrder) &&
                predicate(resource)
            }) else {
                return
            }
            selected.append(candidate)
        }

        if mode == .stuckScaffold {
            appendFirst { isStrategyCard($0) }
            appendFirst { $0.type == .paper && hasCluePotential($0) }
            appendFirst { $0.cardRole == .content && hasCluePotential($0) }
        } else {
            appendFirst { $0.cardRole == .content && $0.type != .paper }
            appendFirst { $0.type == .paper }
            appendFirst { isStrategyCard($0) }
        }

        for resource in scored.map(\.resource) where selected.count < limit {
            guard !selected.contains(resource) else { continue }
            guard isAllowedForMode(resource, mode: mode, stageOrder: currentStageOrder) else { continue }
            selected.append(resource)
        }

        return selected
    }

    private func fallbackRecommendations(
        currentStageOrder: Int,
        limit: Int,
        mode: ClarificationMode
    ) -> [ResourceCard] {
        let stageFallback = resources
            .filter { resource in
                resource.relatedStages.contains(currentStageOrder) &&
                isAllowedForMode(resource, mode: mode, stageOrder: currentStageOrder)
            }
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.title < rhs.title
                }
                return lhs.priority > rhs.priority
            }

        if !stageFallback.isEmpty {
            return Array(stageFallback.prefix(limit))
        }

        return Array(
            resources
                .filter { $0.relatedStages.contains(currentStageOrder) }
                .sorted { $0.priority > $1.priority }
                .prefix(limit)
        )
    }

    private func score(
        _ resource: ResourceCard,
        stageOrder: Int,
        context: String,
        missingFields: [BriefField],
        problemTypes: Set<String>,
        mode: ClarificationMode
    ) -> Int {
        var result = resource.relatedStages.contains(stageOrder) ? 30 : 0
        let recommendedIDs = StageDefinition.all
            .first { $0.order == stageOrder }?
            .recommendedCardIDs ?? []

        if recommendedIDs.contains(resource.id) {
            result += 34
        }

        result += typeWeight(for: resource)

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
                result += 22
            }
            result += aiProjectBoost(for: resource)
        } else if resource.requiredContext.contains("project_uses_ai") {
            result -= 18
        }

        result += stageSpecificBoost(for: resource, stageOrder: stageOrder)
        result += roleWeight(for: resource, problemTypes: problemTypes)

        if mode == .stuckScaffold {
            if isScaffoldResource(resource, stageOrder: stageOrder) {
                result += 36
            } else {
                result -= 24
            }

            if hasCluePotential(resource) {
                result += 10
            }

            if resource.cardRole == .content && resource.relatedStages.contains(stageOrder) {
                result += 8
            }
        }

        result += min(max(resource.priority, 0), 100) / 10
        return result
    }

    private func compareScoredResources(
        _ lhs: (resource: ResourceCard, score: Int),
        _ rhs: (resource: ResourceCard, score: Int)
    ) -> Bool {
        if lhs.score == rhs.score {
            if lhs.resource.priority == rhs.resource.priority {
                return lhs.resource.title < rhs.resource.title
            }
            return lhs.resource.priority > rhs.resource.priority
        }
        return lhs.score > rhs.score
    }

    private func typeWeight(for resource: ResourceCard) -> Int {
        switch resource.type {
        case .method:
            return 10
        case .paper:
            return 9
        case .designPrinciple:
            return 6
        case .courseFramework:
            return 4
        case .caseStudy:
            return 3
        }
    }

    private func roleWeight(for resource: ResourceCard, problemTypes: Set<String>) -> Int {
        switch resource.cardRole {
        case .content:
            return 8
        case .questionStrategy, .cognitiveDepth, .scaffoldingStrategy:
            let needsSupport = ["answer_too_shallow", "user_stuck", "claim_without_evidence", "binary_judgment"]
                .contains { problemTypes.contains($0) }
            return needsSupport ? 12 : 4
        case .loadControl:
            return problemTypes.contains("user_stuck") ? 9 : 2
        case .feedbackStrategy, .reflectionDetector, .stageReflection, .selfRegulation:
            return problemTypes.contains("user_stuck") ? 5 : 1
        case .onboarding, .correctionFeedback, .errorRecovery:
            return -6
        }
    }

    private func aiProjectBoost(for resource: ResourceCard) -> Int {
        let aiTags = [
            "ai",
            "人工智能",
            "human-ai",
            "透明",
            "explainability",
            "控制",
            "human-centered ai",
            "automation bias",
            "uncertainty"
        ]
        return containsAny(resource.tags.joined(separator: " ").lowercased(), aiTags) ? 18 : 0
    }

    private func stageSpecificBoost(for resource: ResourceCard, stageOrder: Int) -> Int {
        switch stageOrder {
        case 3:
            return containsAny(resourceSearchText(resource), [
                "边界",
                "scope",
                "mvp",
                "控制",
                "human control",
                "human-centered",
                "mixed initiative"
            ]) ? 16 : 0
        case 7:
            return containsAny(resourceSearchText(resource), [
                "评价",
                "指标",
                "metrics",
                "success",
                "goodhart",
                "验收",
                "evaluation"
            ]) ? 18 : 0
        case 8:
            return containsAny(resourceSearchText(resource), [
                "风险",
                "失败",
                "error",
                "bias",
                "uncertainty",
                "recovery",
                "自动化"
            ]) ? 14 : 0
        default:
            return 0
        }
    }

    private func resourceSearchText(_ resource: ResourceCard) -> String {
        [
            resource.title,
            resource.tags.joined(separator: " "),
            resource.summary,
            resource.whyRelevant,
            resource.promptCoreIdea,
            resource.promptAgentUse,
            resource.processActionText
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private func isAllowedForMode(
        _ resource: ResourceCard,
        mode: ClarificationMode,
        stageOrder: Int
    ) -> Bool {
        mode != .stuckScaffold || isScaffoldResource(resource, stageOrder: stageOrder)
    }

    private func isScaffoldResource(_ resource: ResourceCard, stageOrder: Int) -> Bool {
        isStrategyCard(resource) ||
            (resource.relatedStages.contains(stageOrder) && hasCluePotential(resource)) ||
            (resource.type == .paper && hasCluePotential(resource))
    }

    private func isStrategyCard(_ resource: ResourceCard) -> Bool {
        switch resource.cardRole {
        case .scaffoldingStrategy, .questionStrategy, .cognitiveDepth, .loadControl, .selfRegulation:
            return true
        default:
            return false
        }
    }

    private func hasCluePotential(_ resource: ResourceCard) -> Bool {
        !resource.promptCoreIdea.isEmpty ||
            !resource.promptDesignImplication.isEmpty ||
            !resource.promptRAGUse.isEmpty ||
            !resource.userDisplayText.isEmpty
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
