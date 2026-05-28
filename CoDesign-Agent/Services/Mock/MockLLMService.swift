import Foundation

final class MockLLMService: LLMServiceProtocol {
    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // 1. 确定当前阶段
                let stageOrder = currentStage?.order ?? 1

                // 2. 只统计 user 消息数（排除 system / assistant）
                let userMessageCount = messages.filter { $0.role == "user" }.count

                // 3. 选择回复
                let response = Self.pickResponse(
                    stageOrder: stageOrder,
                    userTurnCount: userMessageCount
                )

                // 4. 模拟流式输出（每个字符 25ms）
                for char in response {
                    try? await Task.sleep(for: .milliseconds(25))
                    continuation.yield(String(char))
                }

                continuation.finish()
            }
        }
    }

    // MARK: - 9 阶段苏格拉底式追问库

    static let stageResponses: [Int: [String]] = [
        // 阶段 1：痛点与场景锚定
        1: [
            "这个想法很有意思！先别急着展开——能告诉我，你说的这个问题，最常发生在哪类人身上吗？",
            "好的，你已经有了目标用户的大致画像。现在请闭上眼睛想象：这个人在什么时刻、什么地点，第一次意识到「我需要解决这个问题」？",
            "你描述了场景，但我还想知道：如果不解决这个痛点，最坏的结果是什么？用户会用什么笨办法凑合过去？",
            "到目前为止，你对痛点的描述还比较笼统。如果让你用一句话——只有一句话——向一个完全不了解背景的人解释这个问题，你会怎么说？",
        ],

        // 阶段 2：差异化价值提炼
        2: [
            "在你想到的领域里，目前有没有类似的产品或方案？它们做得好的地方是什么？",
            "那些方案没有解决的部分是什么？你的切入点和它们有什么本质区别？",
            "如果用户只能记住你这个项目的一个特点——一个——你希望是什么？",
        ],

        // 阶段 3：项目边界划定
        3: [
            "你列了不少功能。但如果只保留三个，其他全砍掉，哪三个必须留下？",
            "现在想想：有什么是你很想做、但 V1 阶段不应该做的？明确说「不做什么」和说「做什么」一样重要。",
            "你划定了一个边界。我想追问：排除的那些功能，是因为技术上做不到，还是因为它们不是核心痛点的直接解法？",
        ],

        // 阶段 4：功能与技术方案拆解
        4: [
            "你提到了几个核心功能。能拆开说说，每个功能背后需要什么技术支撑吗？",
            "这些技术模块里，哪个是你最没把握的？如果那个模块失败了，整个方案还能跑吗？",
            "想象一个用户从打开你的产品到完成任务，他会经历哪些步骤？",
        ],

        // 阶段 5：运行逻辑与规则定义
        5: [
            "如果用户操作到一半出了错，你的系统应该怎么应对？直接报错？还是静默恢复？",
            "有没有一些规则是绝对不能打破的？比如数据隐私、安全限制？",
        ],

        // 阶段 6：硬性约束设计
        6: [
            "你有多少时间完成这个项目？预算呢？这些约束会如何影响你的技术选型？",
            "有没有什么硬件或平台限制是你必须面对的？",
        ],

        // 阶段 7：量化验收标准制定
        7: [
            "你怎么知道这个产品「做成了」？能不能给我一个可以量化的数字？",
            "如果只能用两个指标来衡量成功，你会选哪两个？",
        ],

        // 阶段 8：风险识别与预案制定
        8: [
            "你觉得这个项目最可能失败的地方在哪里？是技术风险、用户不买账、还是时间不够？",
            "针对你提到的最大风险，如果它真的发生了，你的 Plan B 是什么？",
        ],

        // 阶段 9：项目阶段拆分与排期
        9: [
            "如果把这个项目拆成几个阶段，你会怎么划分里程碑？",
            "第一个里程碑应该验证什么？你打算花多少时间？",
        ],
    ]

    /// 根据阶段和用户轮次选择回复
    /// - Parameters:
    ///   - stageOrder: 当前活跃阶段序号 (1~9)
    ///   - userTurnCount: 用户已发送的消息数（仅 role == "user"）
    /// - Returns: 选中的苏格拉底式追问文本
    static func pickResponse(stageOrder: Int, userTurnCount: Int) -> String {
        let responses = stageResponses[stageOrder] ?? stageResponses[1]!
        // 第一条用户消息 → 第一条回复，超出后停在最后一条
        let index = min(max(userTurnCount - 1, 0), responses.count - 1)
        return responses[index]
    }
}
