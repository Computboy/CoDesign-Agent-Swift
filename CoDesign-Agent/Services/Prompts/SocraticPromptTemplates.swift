import Foundation

enum SocraticPromptTemplates {

    // MARK: - System Prompt

    static func systemPrompt() -> String {
        """
        你是 CoDesign，一个面向大学生设计项目的苏格拉底式设计思维训练 Agent。

        你的核心任务：
        - 通过追问帮助用户澄清设计问题，而不是替用户直接生成完整方案
        - 每次只问 1–2 个关键问题
        - 不要一次性输出完整开题报告
        - 不要替用户过早做决定

        你的追问策略：
        - 如果用户表达模糊，用具体场景引导（例如："你能举一个具体的使用例子吗？"）
        - 如果用户已经给出足够信息，先简短总结，再进入下一步追问
        - 如果用户卡住，给出 2–3 个方向供选择，但最终让用户自己决定
        - 如果用户偏离主题，温和地拉回当前阶段

        你需要覆盖的 9 个设计阶段：
        1. 痛点与场景锚定（目标用户、核心痛点、使用场景）
        2. 差异化价值提炼（核心价值、差异化）
        3. 项目边界划定（做什么、不做什么）
        4. 功能与技术方案拆解（MVP 功能、技术模块、交互流程）
        5. 运行逻辑与规则定义
        6. 硬性约束设计（预算、时间、硬件等）
        7. 量化验收标准制定
        8. 风险识别与预案制定
        9. 项目阶段拆分与排期

        你的语气：
        - 自然、支持性、像耐心的设计导师
        - 使用中文回复
        - 不要用过于学术或官方的语言
        - 可以适当使用轻松的表达
        """
    }

    // MARK: - Context Prompt

    /// 把当前 DesignBrief 和当前阶段传给模型，用于引导追问方向
    static func contextPrompt(
        brief: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?
    ) -> String {
        let brief = brief ?? DesignBriefSnapshot()

        var lines: [String] = []
        lines.append("## 当前设计简报状态")
        lines.append("")
        lines.append("- 目标用户：\(brief.targetUser ?? "未填写")")
        lines.append("- 核心痛点：\(brief.painPoint ?? "未填写")")
        lines.append("- 使用场景：\(brief.useScenario ?? "未填写")")
        lines.append("- 核心价值：\(brief.coreValue ?? "未填写")")
        lines.append("- 差异化：\(brief.differentiation ?? "未填写")")

        if brief.boundaryItems.isEmpty {
            lines.append("- 项目边界：未填写")
        } else {
            lines.append("- 项目边界：")
            for item in brief.boundaryItems {
                let tag = item.isIncluded ? "做" : "不做"
                lines.append("  - [\(tag)] \(item.content)")
            }
        }

        lines.append("- MVP 功能：\(brief.mvpFeatures ?? "未填写")")
        lines.append("- 技术模块：\(brief.technicalModules ?? "未填写")")
        lines.append("- 交互流程：\(brief.interactionFlow ?? "未填写")")
        lines.append("- 运行逻辑：\(brief.operationLogic ?? "未填写")")
        lines.append("- 硬性约束：\(brief.hardConstraints ?? "未填写")")

        if brief.successMetrics.isEmpty {
            lines.append("- 验收标准：未填写")
        } else {
            lines.append("- 验收标准：")
            for m in brief.successMetrics {
                lines.append("  - \(m.metric)：目标 \(m.target)")
            }
        }

        if brief.risks.isEmpty {
            lines.append("- 风险：未填写")
        } else {
            lines.append("- 风险：")
            for r in brief.risks {
                lines.append("  - \(r.desc)（概率 \(r.probability)/5，影响 \(r.impact)/5）")
            }
        }

        lines.append("- 里程碑与排期：\(brief.milestones ?? "未填写")")

        lines.append("")
        lines.append("## 当前阶段")

        if let stage = currentStage {
            lines.append("阶段 \(stage.order)：\(stage.name)（完成度 \(Int(stage.completionRatio * 100))%）")
        } else {
            lines.append("尚未进入任何阶段")
        }

        lines.append("")
        lines.append("请根据当前阶段和已有信息，继续苏格拉底式追问。每次只问 1–2 个关键问题，帮助用户完善当前阶段的设计。")

        return lines.joined(separator: "\n")
    }
}
