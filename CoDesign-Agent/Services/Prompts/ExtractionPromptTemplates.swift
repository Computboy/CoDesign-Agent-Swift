import Foundation

enum ExtractionPromptTemplates {

    // MARK: - System Prompt

    static func systemPrompt() -> String {
        """
        你是一个设计项目结构化信息提取器。

        你的任务是从用户和 AI 的对话中提取设计项目信息。

        严格要求：
        - 只输出 JSON
        - 不要输出 Markdown
        - 不要输出解释
        - 不要用 ```json 包裹
        - 你的最终输出必须是一个可被 JSONDecoder 直接解析的 JSON object
        - 不要补充用户没有表达过的信息
        - 没有提取到的字段请使用 null
        - 如果某个字段没有从对话中明确出现，请填 null，不要推测或编造
        - 数组字段如果没有提取到，请填 null，不要填空数组

        JSON schema（字段与 ExtractedFields 对齐）：
        {
          "targetUser": "string | null",
          "painPoint": "string | null",
          "useScenario": "string | null",
          "coreValue": "string | null",
          "differentiation": "string | null",
          "boundaryItems": [
            {
              "content": "string",
              "isIncluded": "boolean"
            }
          ],
          "mvpFeatures": "string | null",
          "technicalModules": "string | null",
          "interactionFlow": "string | null",
          "operationLogic": "string | null",
          "hardConstraints": "string | null",
          "successMetrics": [
            {
              "metric": "string",
              "target": "string",
              "measurement": "string | null"
            }
          ],
          "risks": [
            {
              "desc": "string",
              "probability": "number",
              "impact": "number",
              "mitigation": "string | null"
            }
          ],
          "milestones": "string | null"
        }

        字段说明：
        - targetUser: 目标用户群体描述
        - painPoint: 用户核心痛点
        - useScenario: 使用场景
        - coreValue: 核心价值主张
        - differentiation: 与已有方案的差异
        - boundaryItems: 项目边界（isIncluded=true 表示做，false 表示不做）
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
        for msg in recentMessages {
            let roleLabel: String
            switch msg.role {
            case "user": roleLabel = "用户"
            case "assistant": roleLabel = "AI"
            default: roleLabel = msg.role
            }
            lines.append("[\(roleLabel)] \(msg.content)")
        }

        lines.append("")
        lines.append("请只基于以上最近对话提取新的字段信息。只返回 JSON，不要任何额外内容。")

        return lines.joined(separator: "\n")
    }
}
