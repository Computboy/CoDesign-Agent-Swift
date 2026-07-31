import Foundation

/// Produces the compact label displayed by the thinking tree while preserving
/// the complete AI question in `ThinkingMoment.content`.
enum QuestionTreeSummary {
    static let preferredCharacterLimit = 34

    static func make(from question: String, limit: Int = preferredCharacterLimit) -> String {
        let flattened = question
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !flattened.isEmpty else { return "待澄清的问题" }

        let stripped = strippingConversationalPrefix(from: flattened)
        guard stripped.count > limit else { return stripped }

        let clauses = stripped
            .split(whereSeparator: { "，。；：".contains($0) })
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let questionClause = clauses.last(where: { $0.hasSuffix("？") || $0.hasSuffix("?") }),
           questionClause.count <= limit {
            return questionClause
        }

        let suffix = (stripped.hasSuffix("？") || stripped.hasSuffix("?")) ? "？" : "…"
        let available = max(limit - suffix.count, 1)
        return String(stripped.prefix(available)).trimmingCharacters(in: .whitespacesAndNewlines) + suffix
    }

    static func inferredField(from question: String, stageOrder: Int) -> BriefField? {
        let normalized = question.lowercased()
        let keywordMappings: [(BriefField, [String])] = [
            (.painPoint, ["痛点", "担心", "焦虑", "困扰", "问题"]),
            (.targetUser, ["谁", "用户", "人群", "对象"]),
            (.useScenario, ["场景", "什么时候", "在哪里", "情境"]),
            (.coreValue, ["价值", "帮助", "改变", "收益"]),
            (.differentiation, ["不同", "差异", "替代", "优势"]),
            (.boundaryItems, ["边界", "不做", "排除", "范围"]),
            (.mvpFeatures, ["功能", "mvp", "第一版"]),
            (.technicalModules, ["技术", "模块", "架构"]),
            (.interactionFlow, ["流程", "交互", "步骤"]),
            (.hardConstraints, ["约束", "限制", "必须"]),
            (.successMetrics, ["指标", "成功", "衡量", "验证"]),
            (.risks, ["风险", "失败", "不确定"]),
            (.milestones, ["里程碑", "计划", "节点"]),
        ]

        if let match = keywordMappings.first(where: { mapping in
            mapping.1.contains(where: normalized.contains)
        }) {
            return match.0
        }

        return StageDefinition.all
            .first(where: { $0.order == stageOrder })?
            .briefFields
            .first
    }

    private static func strippingConversationalPrefix(from value: String) -> String {
        let prefixes = [
            "所以这轮我只想先确认：",
            "所以这轮我只想先确认",
            "这轮我只想先确认：",
            "这轮我只想先确认",
            "追问：",
            "问题：",
        ]

        for prefix in prefixes where value.hasPrefix(prefix) {
            return String(value.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }
}
