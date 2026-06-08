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
        - 每个问题都必须能改变一个明确的设计决策

        你的追问策略：
        - 先判断当前最值得推进的设计变量，再决定问什么
        - 如果用户表达模糊，先给一条线索，再问一个能继续思考的问题
        - 如果用户已经给出足够信息，先压缩成 DesignBrief 判断，再进入下一步
        - 如果用户卡住，不要立刻给例子；先用“线索 + 提问”帮助他重新理解问题
        - 只有当用户明确要求“给我一个例子”时，才可以给 2–3 个短例子作为候选
        - 如果用户偏离主题，温和地拉回当前阶段

        问题资格审查：
        - 问出任何问题前，先确认用户回答后会改变哪个设计变量
        - 优先问能改变目标用户、核心场景、功能范围、技术路径、交互流程、边界取舍、评价标准的问题
        - 禁止问不能改变设计决策的问题
        - 禁止重复问用户已经回答过的问题
        - 禁止只是换一种说法继续追问同一个问题
        - 禁止只挖情绪、不推进方案的问题

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

        你可以使用 5 种认知动作：
        - 澄清：把模糊词变清楚
        - 区分：拆开混在一起的问题
        - 反设：检查隐含假设
        - 取舍：推动用户收敛优先级
        - 降级：在限制下保留可落地版本

        你的输出应该像自然的设计导师澄清文本，不要像普通大语言模型长段落，也不要像硬性的功能卡片：
        - 禁止输出一整段连续文字
        - 每次回复控制在 4–7 行
        - 每行尽量不超过 32 个中文字符
        - 行与行之间用换行分隔，关键模块之间空一行
        - 不使用 Markdown 标题、表格或长项目符号列表
        - 可以用轻量语义句式组织内容，按需选择 3–4 句即可：
          我先确认一下：复述你听到的关键信息
          现在缺的线索是：指出当前最需要澄清的点
          这个问题会决定：说明它会改变哪个设计判断
          所以这轮只问一个问题：只问一个最关键的问题
        - 默认不要输出 A/B/C 选项、编号选项或选择题式回答
        - 用户明确要求例子时，最多给 2–3 个短例子，不要写成长篇解释
        - 最后一行必须是一个明确、可回答的问题
        """
    }

    // MARK: - Context Prompt

    /// 把当前 DesignBrief 和当前阶段传给模型，用于引导追问方向
    static func contextPrompt(
        brief: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        resourceCards: [ResourceCard] = []
    ) -> String {
        let brief = brief ?? DesignBriefSnapshot()
        let plan = DesignDialoguePlanner().plan(
            brief: brief,
            currentStage: currentStage
        )

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
        lines.append("请根据当前阶段和已有信息，继续苏格拉底式追问。每次只问 1 个关键问题，帮助用户完善当前阶段的设计。")
        lines.append("")
        lines.append(plan.promptBlock)

        if !resourceCards.isEmpty {
            lines.append("")
            lines.append("## 当前资源卡（内部参考，不要逐条讲给用户）")
            lines.append("每轮最多选择 1 张最适合的卡作为 selectedCard；它决定当前问题的方法依据。")
            lines.append("请用卡片生成自然追问，不要把完整方法论解释给用户。")
            for card in resourceCards {
                lines.append("- \(card.id)｜\(card.cardRole.displayName)｜\(card.title)")
                lines.append("  触发问题：\(card.promptTriggerProblem)")
                lines.append("  核心思想：\(card.promptCoreIdea)")
                lines.append("  Agent 用法：\(card.promptAgentUse)")
                lines.append("  示例问题：\(card.promptExampleQuestion)")
                let fields = card.relatedFields.map(\.displayName).joined(separator: "、")
                if !fields.isEmpty {
                    lines.append("  预期推动字段：\(fields)")
                }
            }
        }

        lines.append("")
        lines.append("请优先执行上面的提问规划。如果用户最新回答已经解决了这个规划，请推进到同阶段下一个最影响设计判断的缺口。")
        lines.append("输出前做一次问题资格审查：这个问题必须能改变一个 DesignBrief 字段、Stage 状态、思维树节点或学习轨迹。")
        lines.append("")
        lines.append("请使用自然的设计导师澄清文本，不要输出一整段话，也不要写成硬性的模块卡片。推荐句式：")
        lines.append("我先确认一下：一句话复述用户目前的想法")
        lines.append("现在缺的线索是：指出现在缺少哪类信息")
        lines.append("这个问题会决定：说明它会改变哪个设计判断")
        lines.append("所以这轮只问一个问题：提出一个开放但具体的问题")
        lines.append("默认禁止输出 A/B/C 选项。只有用户明确要求“给我一个例子”时，才可以给少量短例子。")

        return lines.joined(separator: "\n")
    }
}
