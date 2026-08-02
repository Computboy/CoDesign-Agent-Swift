import Foundation

enum ReportSemanticProvenance: Equatable {
    case direct(source: String)
    case derived(sources: [String], rule: String)
    case unavailable(reason: String)
}

struct ReportSemanticValue<Value: Equatable>: Equatable {
    var value: Value?
    var provenance: ReportSemanticProvenance

    static func direct(_ value: Value, source: String) -> Self {
        .init(value: value, provenance: .direct(source: source))
    }

    static func derived(_ value: Value, sources: [String], rule: String) -> Self {
        .init(value: value, provenance: .derived(sources: sources, rule: rule))
    }

    static func unavailable(_ reason: String) -> Self {
        .init(value: nil, provenance: .unavailable(reason: reason))
    }
}

enum ReportBehaviorGroupID: String, CaseIterable {
    case understand = "UNDERSTAND"
    case capability = "CAPABILITY"
    case boundary = "BOUNDARY"
}

enum ReportBehaviorFieldID: String, CaseIterable {
    case input
    case cognitiveTask
    case expectedOutput
    case timing
    case reasoningMode
    case outputModality
    case feedbackLoop
    case willDo
    case willNotDo
    case approval
    case responsibility
    case fallback

    var group: ReportBehaviorGroupID {
        switch self {
        case .input, .cognitiveTask, .expectedOutput, .timing:
            return .understand
        case .reasoningMode, .outputModality, .feedbackLoop:
            return .capability
        case .willDo, .willNotDo, .approval, .responsibility, .fallback:
            return .boundary
        }
    }

    var label: String {
        ReportCopy.behaviorFieldLabel(self)
    }
}

struct ReportBehaviorSemanticField: Equatable {
    var id: ReportBehaviorFieldID
    var semanticValue: ReportSemanticValue<String>
}

struct ReportBehaviorSemanticGroup: Equatable {
    var id: ReportBehaviorGroupID
    var fields: [ReportBehaviorSemanticField]
}

struct ReportSemanticMetric: Equatable {
    var metric: ReportSemanticValue<String>
    var category: ReportSemanticValue<String>
    var target: ReportSemanticValue<String>
    var measurement: ReportSemanticValue<String>
    var validationStatus: ReportSemanticValue<String>
}

struct ReportSemanticRisk: Equatable {
    var risk: ReportSemanticValue<String>
    var probability: ReportSemanticValue<Int>
    var impact: ReportSemanticValue<Int>
    var triggerOrFailure: ReportSemanticValue<String>
    var detection: ReportSemanticValue<String>
    var recovery: ReportSemanticValue<String>
    var userControl: ReportSemanticValue<String>
}

struct ReportSemanticMapping: Equatable {
    var behaviorGroups: [ReportBehaviorSemanticGroup]
    var metrics: [ReportSemanticMetric]
    var risks: [ReportSemanticRisk]

    func field(_ id: ReportBehaviorFieldID) -> ReportBehaviorSemanticField? {
        behaviorGroups
            .first { $0.id == id.group }?
            .fields
            .first { $0.id == id }
    }

    var availableBehaviorSpec: [String: [String: String]] {
        Dictionary(uniqueKeysWithValues: behaviorGroups.map { group in
            let values = group.fields.reduce(into: [String: String]()) { result, field in
                if let value = field.semanticValue.value {
                    result[field.id.label] = value
                }
            }
            return (group.id.rawValue, values)
        })
    }
}

/// The only layer allowed to translate Design Brief data into report semantics.
/// It performs exact mappings and narrow, deterministic derivations only; it never invokes an LLM.
struct ReportSemanticMapper {
    private static let unavailableReason = "当前数据模型没有语义对应字段"

    func map(brief: DesignBriefSnapshot) -> ReportSemanticMapping {
        let approval = explicitApproval(from: brief.interactionFlow)
        let willDo = explicitAIBoundaryItems(from: brief.boundaryItems, isIncluded: true)
        let willNotDo = explicitAIBoundaryItems(from: brief.boundaryItems, isIncluded: false)

        return ReportSemanticMapping(
            behaviorGroups: [
                group(.understand, fields: [
                    unavailable(.input),
                    unavailable(.cognitiveTask),
                    unavailable(.expectedOutput),
                    unavailable(.timing),
                ]),
                group(.capability, fields: [
                    unavailable(.reasoningMode),
                    unavailable(.outputModality),
                    unavailable(.feedbackLoop),
                ]),
                group(.boundary, fields: [
                    field(.willDo, value: willDo),
                    field(.willNotDo, value: willNotDo),
                    field(.approval, value: approval),
                    unavailable(.responsibility),
                    unavailable(.fallback),
                ]),
            ],
            metrics: semanticMetrics(from: brief.successMetrics),
            risks: semanticRisks(from: brief.risks)
        )
    }

    private func semanticMetrics(from metrics: [SuccessMetricDTO]) -> [ReportSemanticMetric] {
        metrics.compactMap { metric in
            guard let name = clean(metric.metric), let target = clean(metric.target) else { return nil }
            return ReportSemanticMetric(
                metric: .direct(name, source: "brief.successMetrics.metric"),
                category: .unavailable("当前数据模型没有指标分类字段"),
                target: .direct(target, source: "brief.successMetrics.target"),
                measurement: directText(metric.measurement, source: "brief.successMetrics.measurement"),
                validationStatus: .derived(
                    "待验证",
                    sources: [],
                    rule: "当前数据模型没有 current value 或实测结果时，不推断测试结果"
                )
            )
        }
    }

    private func semanticRisks(from risks: [RiskItemDTO]) -> [ReportSemanticRisk] {
        risks.compactMap { risk in
            guard let description = clean(risk.desc) else { return nil }
            return ReportSemanticRisk(
                risk: .direct(description, source: "brief.risks.desc"),
                probability: .direct(risk.probability, source: "brief.risks.probability"),
                impact: .direct(risk.impact, source: "brief.risks.impact"),
                triggerOrFailure: .unavailable("当前数据模型没有逐风险 Trigger / Failure 字段"),
                detection: .unavailable("当前数据模型没有风险检测字段"),
                recovery: directText(risk.mitigation, source: "brief.risks.mitigation"),
                userControl: .unavailable("当前数据模型没有逐风险 User Control 字段")
            )
        }
    }

    private func explicitAIBoundaryItems(
        from items: [BoundaryItemDTO],
        isIncluded: Bool
    ) -> ReportSemanticValue<String> {
        let values = items
            .filter { $0.isIncluded == isIncluded }
            .compactMap { explicitContent($0.content, prefixes: ["AI:", "AI："]) }

        guard !values.isEmpty else {
            return .unavailable("产品范围边界不等同于 AI 行为边界；需要显式 AI 标记")
        }
        return .derived(
            values.joined(separator: "；"),
            sources: ["brief.boundaryItems.content", "brief.boundaryItems.isIncluded"],
            rule: "仅接收以 AI: 或 AI：显式标记的边界项"
        )
    }

    private func explicitApproval(from interactionFlow: String?) -> ReportSemanticValue<String> {
        guard let interactionFlow = clean(interactionFlow) else {
            return .unavailable(Self.unavailableReason)
        }
        let normalized = interactionFlow
            .replacingOccurrences(of: "->", with: "→")
            .replacingOccurrences(of: "=>", with: "→")
            .replacingOccurrences(of: "➡️", with: "→")
        let approvals = normalized
            .components(separatedBy: CharacterSet(charactersIn: "→\n"))
            .compactMap { step in
                explicitContent(
                    step,
                    prefixes: ["HITL:", "HITL：", "人工确认:", "人工确认：", "人工审批:", "人工审批："]
                )
            }

        guard !approvals.isEmpty else {
            return .unavailable("interactionFlow 只有显式 HITL / 人工确认步骤才能确定性映射为 Approval")
        }
        return .derived(
            approvals.joined(separator: "；"),
            sources: ["brief.interactionFlow"],
            rule: "仅提取带 HITL / 人工确认 / 人工审批前缀的流程步骤"
        )
    }

    private func unavailable(_ id: ReportBehaviorFieldID) -> ReportBehaviorSemanticField {
        field(id, value: .unavailable(Self.unavailableReason))
    }

    private func field(
        _ id: ReportBehaviorFieldID,
        value: ReportSemanticValue<String>
    ) -> ReportBehaviorSemanticField {
        ReportBehaviorSemanticField(id: id, semanticValue: value)
    }

    private func group(
        _ id: ReportBehaviorGroupID,
        fields: [ReportBehaviorSemanticField]
    ) -> ReportBehaviorSemanticGroup {
        ReportBehaviorSemanticGroup(id: id, fields: fields)
    }

    private func directText(_ value: String?, source: String) -> ReportSemanticValue<String> {
        guard let value = clean(value) else {
            return .unavailable("\(source) 没有已确认内容")
        }
        return .direct(value, source: source)
    }

    private func explicitContent(_ rawValue: String, prefixes: [String]) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prefix = prefixes.first(where: { value.hasPrefix($0) }) else { return nil }
        return clean(String(value.dropFirst(prefix.count)))
    }

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let placeholders = [ReportSnapshotValue.missing, "需要补充", "待进一步定义", "______"]
        guard !placeholders.contains(where: { trimmed.contains($0) }) else { return nil }
        return trimmed
    }
}
