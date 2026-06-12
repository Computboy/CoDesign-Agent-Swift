import Foundation

enum ExtractionPromptTemplates {

    // MARK: - System Prompt

    static func systemPrompt() -> String {
        """
        你是一个设计项目结构化信息提取器。

        你的任务是从用户和 AI 的对话中提取设计项目信息，并为每个候选字段提供用户原话证据。

        严格要求：
        - 只输出 JSON
        - 不要输出 Markdown
        - 不要输出解释
        - 不要用 ```json 包裹
        - 你的最终输出必须是一个可被 JSONDecoder 直接解析的 JSON object
        - 不要补充用户没有表达过的信息
        - evidence.quote 必须逐字来自用户原话，不允许改写
        - 不允许使用 AI 自己的回复作为 evidence
        - 如果某个字段没有明确用户证据，value 必须为 null，evidence 必须为空数组
        - 不要编造用户没有说过的信息
        - confidence 是你对字段提取的自评，范围 0...1；本地系统会重新校验
        - shouldAutoCommit 固定输出 false，由本地可靠性层决定是否自动写入

        JSON schema（每个字段都是 ExtractedFieldCandidate envelope）：
        {
          "targetUser": { "value": "string | null", "confidence": 0.0, "evidence": [{ "role": "user", "quote": "用户原话", "turnIndex": 0 }], "validationNotes": [], "shouldAutoCommit": false },
          "painPoint": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "useScenario": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "coreValue": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "differentiation": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "boundaryItems": { "value": [{ "content": "string", "isIncluded": true }], "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "mvpFeatures": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "technicalModules": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "interactionFlow": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "operationLogic": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "hardConstraints": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "successMetrics": { "value": [{ "metric": "string", "target": "string", "measurement": "string | null" }], "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "risks": { "value": [{ "desc": "string", "probability": 1, "impact": 1, "mitigation": "string | null" }], "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false },
          "milestones": { "value": "string | null", "confidence": 0.0, "evidence": [], "validationNotes": [], "shouldAutoCommit": false }
        }

        字段说明：
        - targetUser: 目标用户群体描述
        - painPoint: 用户核心痛点
        - useScenario: 使用场景
        - coreValue: 核心价值主张
        - differentiation: 与已有方案的差异
        - boundaryItems: 项目边界（isIncluded=true 表示第一版明确要做，false 表示明确不做/暂不做）。不要把单独的时间、排期、截止日期、预算或资源限制提取为 boundaryItems；这类内容应放入 hardConstraints 或 milestones。
        - mvpFeatures: MVP 核心功能描述
        - technicalModules: 技术模块描述
        - interactionFlow: 交互流程描述
        - operationLogic: 运行逻辑与规则
        - hardConstraints: 硬性约束（预算、时间、硬件等）
        - successMetrics: 可量化验收指标（metric=指标名，target=目标值，measurement=测量方式）
        - risks: 风险项（desc=描述，probability=1~5 概率，impact=1~5 影响，mitigation=缓解方案）
        - milestones: 里程碑与排期描述
        """
    }

    // MARK: - User Prompt

    /// 从最近对话中提取设计字段，结合已有 brief 上下文
    static func userPrompt(
        messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) -> String {
        let recentMessages = messages.suffix(12)

        var lines: [String] = []

        // 已有 brief 上下文
        if let existing {
            lines.append("## 已有设计简报")
            lines.append("")
            if let v = existing.targetUser { lines.append("- 目标用户：\(v)") }
            if let v = existing.painPoint { lines.append("- 核心痛点：\(v)") }
            if let v = existing.useScenario { lines.append("- 使用场景：\(v)") }
            if let v = existing.coreValue { lines.append("- 核心价值：\(v)") }
            if let v = existing.differentiation { lines.append("- 差异化：\(v)") }
            if !existing.boundaryItems.isEmpty {
                lines.append("- 项目边界：")
                for item in existing.boundaryItems {
                    let tag = item.isIncluded ? "做" : "不做"
                    lines.append("  - [\(tag)] \(item.content)")
                }
            }
            if let v = existing.mvpFeatures { lines.append("- MVP 功能：\(v)") }
            if let v = existing.technicalModules { lines.append("- 技术模块：\(v)") }
            if let v = existing.interactionFlow { lines.append("- 交互流程：\(v)") }
            if let v = existing.operationLogic { lines.append("- 运行逻辑：\(v)") }
            if let v = existing.hardConstraints { lines.append("- 硬性约束：\(v)") }
            if !existing.successMetrics.isEmpty {
                lines.append("- 验收标准：")
                for m in existing.successMetrics {
                    lines.append("  - \(m.metric)：目标 \(m.target)")
                }
            }
            if !existing.risks.isEmpty {
                lines.append("- 风险：")
                for r in existing.risks {
                    lines.append("  - \(r.desc)（概率 \(r.probability)/5，影响 \(r.impact)/5）")
                }
            }
            if let v = existing.milestones { lines.append("- 里程碑与排期：\(v)") }
            lines.append("")
        }

        // 最近对话
        lines.append("## 最近对话")
        lines.append("")
        for (offset, msg) in recentMessages.enumerated() {
            let roleLabel: String
            switch msg.role {
            case "user": roleLabel = "用户"
            case "assistant": roleLabel = "AI"
            default: roleLabel = msg.role
            }
            lines.append("[turnIndex=\(offset) role=\(msg.role) \(roleLabel)] \(msg.content)")
        }

        lines.append("")
        lines.append("请只基于以上最近对话提取新的字段信息。evidence.quote 必须从 role=user 的消息中逐字截取；不能引用 AI 消息。只返回 JSON，不要任何额外内容。")

        return lines.joined(separator: "\n")
    }

    static func repairPrompt(rawJSON: String, errorDescription: String) -> String {
        """
        修复下面的 JSON，使它符合 ExtractionEnvelope schema。
        只修 JSON 语法和字段结构，不要新增没有用户证据的信息。
        如果字段没有可靠用户证据，保留该字段 object，但把 value 设为 null、evidence 设为空数组。
        只返回修复后的 JSON object。

        解码错误：
        \(errorDescription)

        原始输出：
        \(rawJSON)
        """
    }

    static func validationRepairPrompt(
        messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?,
        invalidFieldNames: [String],
        validationErrors: [String],
        previousEnvelopeJSON: String
    ) -> String {
        """
        上一次 ExtractionEnvelope JSON 未通过本地校验。
        只修复这些 invalid fields：\(invalidFieldNames.joined(separator: ", "))
        不要修改其他字段。
        evidence.quote 必须逐字来自 role=user 的消息；不能使用 AI 回复作为证据。
        如果某个 invalid field 没有可靠用户证据，把它的 value 设为 null、evidence 设为空数组。
        只返回完整的修复后 JSON object。

        校验错误：
        \(validationErrors.joined(separator: "\n"))

        对话上下文：
        \(userPrompt(messages: messages, existing: existing))

        上一次 JSON：
        \(previousEnvelopeJSON)
        """
    }
}
