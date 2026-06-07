import Foundation

/// Built-in test scenarios for the Dialogue Gym.
enum DialogueGymScenarios {
    static let builtIn: [SimulationScenario] = [
        scenario1, scenario2, scenario3, scenario4, scenario5,
    ]

    // MARK: - Scenario 1: 新生校园导航助手

    static let scenario1: SimulationScenario = SimulationScenario(
        title: "新生校园导航助手",
        initialIdea: "我想做一个新生入学的智能导航助手，帮助他们解决找不到路的问题。",
        userPersona: "大一新生，表达比较口语化，知道痛点但不懂产品设计。回答简短，不主动补充太多。",
        answerStyle: "简短、直接、口语化。不会主动给完整 PRD。遇到太细的问题会表示「这个好像不用再问了」。",
        maxTurns: 8,
        targetStages: [1, 2, 3, 4],
        focusChecks: [
            "目标用户、痛点、场景明确后，Agent 是否停止追问痛点细节。",
            "Stage 4 是否转向 MVP 功能、技术模块、交互流程。",
            "是否避免继续问「找不到路时最不开心的是什么」这类低价值问题。",
        ]
    )

    // MARK: - Scenario 2: 宠物安抚智能硬件

    static let scenario2: SimulationScenario = SimulationScenario(
        title: "宠物安抚智能硬件",
        initialIdea: "我想设计一个可以辅助安抚宠物的智能硬件，通过呼吸灯帮助宠物平静下来。",
        userPersona: "智能硬件方向学生，想法有趣但证据不足，对动物行为机制了解不深。",
        answerStyle: "会主动提到自己的想法来源，但对因果链不太确定。遇到需要证据的问题会说「我还没查过」。",
        maxTurns: 8,
        targetStages: [1, 2, 3, 4, 6],
        focusChecks: [
            "Agent 是否检查因果假设。",
            "Agent 是否要求证据或降级方案。",
            "Agent 是否区分硬件可行性、动物行为机制和用户价值。",
        ]
    )

    // MARK: - Scenario 3: 老年人用药提醒 App

    static let scenario3: SimulationScenario = SimulationScenario(
        title: "老年人用药提醒 App",
        initialIdea: "我想做一个给老年人用的智能用药提醒助手。",
        userPersona: "关心家中老人，希望做一个实用 App，但对医疗风险和责任边界考虑不足。",
        answerStyle: "从家人体验出发，比较关注简单易用，但不太考虑法律和医疗风险。会自然提到「我奶奶就是...」。",
        maxTurns: 8,
        targetStages: [1, 2, 3, 4, 8],
        focusChecks: [
            "Agent 是否有风险和边界意识。",
            "Agent 是否追问责任、错误提醒、家属确认。",
            "Agent 是否避免让 AI 越权做医疗判断。",
        ]
    )

    // MARK: - Scenario 4: 原创四格漫画创作工具

    static let scenario4: SimulationScenario = SimulationScenario(
        title: "原创四格漫画创作工具",
        initialIdea: "我想做一个帮助学生创作原创四格漫画的 AI 工具。",
        userPersona: "喜欢漫画和创作，希望 AI 帮助发散灵感，但不想被 AI 完全替代创作。",
        answerStyle: "对创作流程有感觉，会说「我想要的是...但不是...」。强调人的主导权。",
        maxTurns: 8,
        targetStages: [1, 2, 3, 4],
        focusChecks: [
            "Agent 是否能处理创意类任务。",
            "Agent 是否避免过度收敛。",
            "Agent 是否区分灵感发散、角色设定、分镜生成、风格边界。",
        ]
    )

    // MARK: - Scenario 5: 校园二手交易 Agent

    static let scenario5: SimulationScenario = SimulationScenario(
        title: "校园二手交易 Agent",
        initialIdea: "我想做一个校园二手交易智能助手，帮学生发布和筛选商品。",
        userPersona: "想做校园生活服务类产品，比较关注方便发布和快速匹配，但对审核与欺诈风险考虑不足。",
        answerStyle: "从方便发布和快速成交出发思考，对交易纠纷和安全问题想得比较简单。会说「应该不会有人骗人吧」。",
        maxTurns: 8,
        targetStages: [1, 2, 3, 4, 5, 8],
        focusChecks: [
            "Agent 是否追问交易流程。",
            "Agent 是否考虑审核、欺诈、责任边界。",
            "Agent 是否能拆出 MVP 功能。",
        ]
    )
}
