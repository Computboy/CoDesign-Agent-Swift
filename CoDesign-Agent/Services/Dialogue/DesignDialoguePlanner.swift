import Foundation

/// Turns "Socratic questioning" into an explicit design-decision move.
/// The planner is intentionally deterministic: it gives the LLM a concrete
/// decision target before wording the next question.
struct DesignDialoguePlanner {
    enum CognitiveMove: String {
        case clarify = "澄清"
        case differentiate = "区分"
        case challenge = "反设"
        case prioritize = "取舍"
        case bound = "降级"

        var description: String {
            switch self {
            case .clarify:
                return "把模糊词变成可写入 DesignBrief 的清楚判断"
            case .differentiate:
                return "拆开混在一起的问题，让用户看见不同产品方向"
            case .challenge:
                return "检查隐含假设，避免方案和现有解法重复"
            case .prioritize:
                return "推动用户在多个可行方向中收敛"
            case .bound:
                return "面对资源或技术限制，保留一个可落地版本"
            }
        }
    }

    struct Plan {
        let stageOrder: Int
        let stageName: String
        let move: CognitiveMove
        let targetField: BriefField
        let designDecision: String
        let decisionImpact: String
        let question: String
        let options: [String]
        let avoid: [String]

        var mockResponse: String {
            var lines = [
                "我先确认一下：当前最值得推进的不是继续挖细节，而是做一个设计判断。",
                "现在缺的线索是：\(designDecision)",
                "这个问题会决定：\(decisionImpact)"
            ]

            lines.append("所以这轮只问一个问题：\(question)")
            return lines.joined(separator: "\n")
        }

        var promptBlock: String {
            var lines = [
                "## 下一轮提问规划",
                "- 认知动作：\(move.rawValue)（\(move.description)）",
                "- 设计变量：\(targetField.displayName)",
                "- 问题资格：用户回答后必须能改变「\(designDecision)」",
                "- 设计影响：\(decisionImpact)",
                "- 推荐问题：\(question)"
            ]

            lines.append("- 提问方式：先给一条线索，再提出一个开放问题；不要直接给 A/B/C 选项。")

            lines.append("- 不要问：")
            for item in avoid {
                lines.append("  - \(item)")
            }
            return lines.joined(separator: "\n")
        }
    }

    func plan(
        brief: DesignBriefSnapshot,
        currentStage: ProgressStageSnapshot?
    ) -> Plan {
        let definition = preferredStageDefinition(brief: brief, currentStage: currentStage)
        let targetField = definition.briefFields.first { !$0.isFilled(in: brief) }
            ?? definition.briefFields.first
            ?? .useScenario

        return plan(for: targetField, stage: definition, brief: brief)
    }

    private func preferredStageDefinition(
        brief: DesignBriefSnapshot,
        currentStage: ProgressStageSnapshot?
    ) -> StageDefinition {
        if let currentStage,
           let definition = StageDefinition.all.first(where: { $0.order == currentStage.order }),
           definition.completionRatio(from: brief) < 1 {
            return definition
        }

        return StageDefinition.all.first { $0.completionRatio(from: brief) < 1 }
            ?? StageDefinition.all.last!
    }

    private func plan(
        for field: BriefField,
        stage: StageDefinition,
        brief: DesignBriefSnapshot
    ) -> Plan {
        let theme = projectTheme(from: brief)

        switch field {
        case .targetUser:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .clarify,
                targetField: field,
                designDecision: "这个产品优先服务谁",
                decisionImpact: "后续场景、功能范围和评价标准都会随目标用户改变",
                question: "请描述一个第一版最值得优先服务的具体用户，他正在面对什么任务？",
                options: ["A. 新手/新生", "B. 高频使用者", "C. 管理者或服务提供者"],
                avoid: lowValueQuestions
            )

        case .painPoint:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .differentiate,
                targetField: field,
                designDecision: "用户真正需要被解决的是哪一种痛点",
                decisionImpact: "它会决定产品是做信息提示、流程辅助、决策推荐还是自动化执行",
                question: "这个用户在真实场景里卡住的那一刻，最具体的困难是什么？",
                options: ["A. 信息不清楚", "B. 选择难判断", "C. 执行成本高"],
                avoid: lowValueQuestions
            )

        case .useScenario:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .prioritize,
                targetField: field,
                designDecision: "第一版要锚定哪个高频且可验证的使用场景",
                decisionImpact: "场景一旦确定，MVP 功能和交互流程才能收敛",
                question: "第一版最应该锚定哪个真实发生、容易验证的使用场景？",
                options: scenarioOptions(for: theme),
                avoid: lowValueQuestions
            )

        case .coreValue:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .challenge,
                targetField: field,
                designDecision: "用户为什么需要这个方案，而不是继续用现有办法",
                decisionImpact: "它会决定核心价值主张是不是成立",
                question: "用户为什么会放下现有办法，转而需要你的方案？",
                options: ["A. 更少出错", "B. 更省时间", "C. 更安心或更有掌控感"],
                avoid: lowValueQuestions
            )

        case .differentiation:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .differentiate,
                targetField: field,
                designDecision: "你的方案和已有方案的本质差异",
                decisionImpact: "它会决定项目是否只是换壳，还是有清楚的设计价值",
                question: "和已有工具相比，你的方案准备在哪个关键体验上形成差异？",
                options: ["A. 服务对象更窄", "B. 场景更具体", "C. 交互方式更适合当下任务"],
                avoid: lowValueQuestions
            )

        case .boundaryItems:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .prioritize,
                targetField: field,
                designDecision: "第一版明确做什么和不做什么",
                decisionImpact: "边界会直接控制项目范围、技术成本和展示重点",
                question: "为了验证核心价值，第一版必须保留什么，又应该暂时放下什么？",
                options: ["A. 保留最能验证价值的能力", "B. 排除技术成本最高的能力", "C. 排除不影响核心场景的能力"],
                avoid: lowValueQuestions
            )

        case .mvpFeatures:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .prioritize,
                targetField: field,
                designDecision: "MVP 只保留哪些最小功能",
                decisionImpact: "它会决定原型、开发任务和验收演示的主线",
                question: "为了验证核心价值，第一版最少需要哪些功能支撑主线？",
                options: ["A. 输入/识别需求", "B. 给出关键建议或路径", "C. 反馈结果是否有效"],
                avoid: lowValueQuestions
            )

        case .technicalModules:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .bound,
                targetField: field,
                designDecision: "功能背后的最低可行技术路径",
                decisionImpact: "它会决定第一版能不能在时间和资源内做出来",
                question: "如果最高成本的技术暂时做不了，第一版还能怎样低成本地成立？",
                options: ["A. 人工配置数据", "B. 规则/模板替代智能判断", "C. 静态指引替代实时能力"],
                avoid: lowValueQuestions
            )

        case .interactionFlow:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .clarify,
                targetField: field,
                designDecision: "用户从打开产品到完成任务的关键步骤",
                decisionImpact: "它会暴露功能缺口、输入成本和异常节点",
                question: "用户从打开产品到完成任务，中间最关键的步骤会怎样发生？",
                options: ["A. 先选择目标", "B. 系统先推荐", "C. 先确认上下文再给方案"],
                avoid: lowValueQuestions
            )

        case .operationLogic:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .challenge,
                targetField: field,
                designDecision: "系统在异常或不确定情况下如何运行",
                decisionImpact: "规则会决定体验是否可信、可解释、可恢复",
                question: "当系统判断不准或用户走错一步时，什么反馈能帮助他继续推进？",
                options: ["A. 让用户重新选择", "B. 给出纠错提示", "C. 提供人工/备用路径"],
                avoid: lowValueQuestions
            )

        case .hardConstraints:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .bound,
                targetField: field,
                designDecision: "第一版必须承认哪些时间、预算、设备或数据限制",
                decisionImpact: "约束会决定功能降级方式和原型可信度",
                question: "现在最不能突破的限制是什么，它会怎样影响第一版设计？",
                options: ["A. 时间不足", "B. 数据/设备拿不到", "C. 技术实现风险太高"],
                avoid: lowValueQuestions
            )

        case .successMetrics:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .differentiate,
                targetField: field,
                designDecision: "怎样才算这个设计真的有效",
                decisionImpact: "指标会决定测试方法、展示证据和迭代优先级",
                question: "什么可观察的数据或行为，能证明这个设计真的带来了改善？",
                options: ["A. 完成时间下降", "B. 错误次数减少", "C. 主观信心或满意度提升"],
                avoid: lowValueQuestions
            )

        case .risks:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .challenge,
                targetField: field,
                designDecision: "项目最可能在哪里失败，以及 Plan B 是什么",
                decisionImpact: "风险判断会决定技术路线和演示策略是否可信",
                question: "如果这个方案失败，最可能从哪一个关键环节开始失效？",
                options: ["A. 用户没有持续需求", "B. 技术或数据不可行", "C. 场景太窄无法验证"],
                avoid: lowValueQuestions
            )

        case .milestones:
            return Plan(
                stageOrder: stage.order,
                stageName: stage.name,
                move: .prioritize,
                targetField: field,
                designDecision: "先验证哪个关键假设，再推进完整方案",
                decisionImpact: "里程碑会决定接下来每周具体做什么",
                question: "第一个里程碑应该优先验证哪个最不确定但最关键的假设？",
                options: ["A. 用户是否需要", "B. 核心功能是否可做", "C. 指标是否能被测量"],
                avoid: lowValueQuestions
            )
        }
    }

    private var lowValueQuestions: [String] {
        [
            "你能再具体说说吗",
            "还有什么困难",
            "为什么会这样",
            "这个问题重要吗",
            "只追问情绪但不改变功能、边界、技术或指标的问题"
        ]
    }

    private func projectTheme(from brief: DesignBriefSnapshot) -> String {
        [
            brief.targetUser,
            brief.painPoint,
            brief.useScenario,
            brief.coreValue,
            brief.differentiation
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private func scenarioOptions(for theme: String) -> [String] {
        if theme.contains("校园") || theme.contains("新生") || theme.contains("导航") || theme.contains("教室") {
            return [
                "A. 室外路线：从宿舍到教学楼、食堂、图书馆",
                "B. 楼内指引：到了楼下但找不到楼层和教室",
                "C. 入学流程：报到、体检、领卡等任务不知道去哪"
            ]
        }

        return [
            "A. 最高频发生的日常场景",
            "B. 最痛但低频的关键场景",
            "C. 最容易做出原型验证的场景"
        ]
    }
}
