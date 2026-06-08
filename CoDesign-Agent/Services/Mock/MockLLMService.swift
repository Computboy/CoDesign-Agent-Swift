import Foundation

final class MockLLMService: LLMServiceProtocol {
    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        mode: ClarificationMode,
        resourceCards: [ResourceCard]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // 1. 确定当前阶段
                let brief = briefSnapshot ?? DesignBriefSnapshot()
                let plan = DesignDialoguePlanner().plan(
                    brief: brief,
                    currentStage: currentStage
                )
                let response = Self.response(
                    mode: mode,
                    planResponse: plan.mockResponse,
                    brief: brief,
                    currentStage: currentStage,
                    resourceCards: resourceCards
                )

                // 2. 模拟流式输出（每个字符 25ms）
                for char in response {
                    try? await Task.sleep(for: .milliseconds(25))
                    continuation.yield(String(char))
                }

                continuation.finish()
            }
        }
    }

    private static func response(
        mode: ClarificationMode,
        planResponse: String,
        brief: DesignBriefSnapshot,
        currentStage: ProgressStageSnapshot?,
        resourceCards: [ResourceCard]
    ) -> String {
        switch mode {
        case .stuckScaffold:
            return scaffoldResponse(
                brief: brief,
                currentStage: currentStage,
                resourceCards: resourceCards
            )
        case .exampleRequested:
            return exampleResponse(brief: brief, currentStage: currentStage)
        default:
            return planResponse
        }
    }

    private static func scaffoldResponse(
        brief: DesignBriefSnapshot,
        currentStage: ProgressStageSnapshot?,
        resourceCards: [ResourceCard]
    ) -> String {
        let projectFocus = [
            brief.targetUser,
            brief.painPoint,
            brief.useScenario,
            brief.coreValue
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? "当前这个设计想法"

        let card = resourceCards.first
        let clueSeed = card?.promptCoreIdea ?? card?.promptAgentUse ?? "先把模糊想法放回一个真实任务片段里看"
        let question = card?.promptExampleQuestion ?? stageQuestion(currentStage?.order ?? 1)

        return """
        线索：
        \(projectFocus) 现在不需要立刻变成答案。
        可以先借用“\(clueSeed)”这个方法，
        看它在一个连续任务里哪里真正卡住。

        追问：
        \(singleQuestion(question, stageOrder: currentStage?.order ?? 1))
        """
    }

    private static func exampleResponse(
        brief: DesignBriefSnapshot,
        currentStage: ProgressStageSnapshot?
    ) -> String {
        let stageOrder = currentStage?.order ?? 1
        let focus = brief.targetUser ?? brief.useScenario ?? "你的目标用户"
        switch stageOrder {
        case 1:
            return """
            例子：
            新生报到当天找不到下一步办理地点。
            社团招新时新成员不知道该问谁。

            追问：
            你自己的项目里，哪一个真实任务片段最像这种“走到一半停住”的状态？
            """
        case 3:
            return """
            例子：
            第一版只做最核心任务闭环。
            暂时不做社交、排行榜或复杂推荐。

            追问：
            如果只保留能帮助 \(focus) 完成主任务的一小段流程，哪部分必须留下？
            """
        default:
            return """
            例子：
            可以从一个真实用户、一段连续任务、一个失败节点里切入。
            也可以从“如果不解决会怎样”来判断优先级。

            追问：
            这些例子里，哪一种最接近你现在项目的真实不确定点？
            """
        }
    }

    private static func singleQuestion(_ raw: String, stageOrder: Int) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return stageQuestion(stageOrder) }
        let separators = CharacterSet(charactersIn: "？?\n")
        let first = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return (first ?? stageQuestion(stageOrder)).trimmingCharacters(in: .whitespacesAndNewlines) + "？"
    }

    private static func stageQuestion(_ stageOrder: Int) -> String {
        switch stageOrder {
        case 1:
            return "你能回想一个用户完成任务的连续片段吗，在哪个节点他最容易停下来"
        case 2:
            return "和已有方案相比，你最希望用户记住哪一个不同的价值判断"
        case 3:
            return "如果第一版只能解决一段最小任务，哪部分应该先被保留下来"
        case 4:
            return "这个核心任务背后，哪一个功能模块最先决定方案能不能跑通"
        case 5:
            return "当用户操作到一半出错时，系统应该根据什么规则继续引导"
        case 6:
            return "现在最不能绕开的时间、设备或资源限制是什么"
        case 7:
            return "哪个可观察的变化能证明这个设计真的有效"
        case 8:
            return "这个项目最可能在哪一个假设上失败"
        case 9:
            return "第一个里程碑应该验证哪一个最关键的不确定性"
        default:
            return "你现在最需要澄清的那个设计判断是什么"
        }
    }

    // MARK: - Legacy 9 阶段苏格拉底式追问库

    /// Kept as a compatibility fallback for older tests and previews.
    /// Runtime mock chat now uses DesignDialoguePlanner so it can ask questions
    /// that point to an explicit design decision.
    static let stageResponses: [Int: [String]] = [
        // 阶段 1：痛点与场景锚定
        1: [
            """
            理解｜这个想法可以继续往真实用户身上落。
            线索｜现在最缺的是“谁最常遇到它”。

            追问｜这个问题最常发生在哪类人身上？
            """,
            """
            理解｜你已经有了目标用户的大致画像。
            线索｜下一步要把问题放进具体时刻。

            追问｜他们在什么地点、什么时刻最需要它？
            """,
            """
            理解｜场景已经出现了，但痛点还可以更尖。
            线索｜我们要看“不解决会怎样”。

            追问｜如果没有这个方案，用户会怎么凑合？
            """,
            """
            理解｜现在的信息够做一次压缩表达。
            线索｜一句话能检验问题是否清楚。

            追问｜你会怎样用一句话说明这个痛点？
            """,
        ],

        // 阶段 2：差异化价值提炼
        2: [
            """
            理解｜我们开始看它和已有方案的区别。
            线索｜先找参照物，差异才会清楚。

            追问｜目前有没有类似产品？它们做得好在哪？
            """,
            """
            理解｜你已经有了参照方案。
            线索｜现在要找它们没覆盖的空位。

            追问｜你的切入点和它们本质上差在哪？
            """,
            """
            理解｜差异化需要被压成一个记忆点。
            线索｜用户通常只会记住一个理由。

            追问｜你最希望用户记住哪个特点？
            """,
        ],

        // 阶段 3：项目边界划定
        3: [
            """
            理解｜功能开始变多了。
            线索｜边界要先保住最小可行版本。

            追问｜如果只留三个功能，哪三个必须留下？
            """,
            """
            理解｜“不做什么”会让项目更稳。
            线索｜V1 不应该背太多目标。

            追问｜有什么很想做、但第一版先不做？
            """,
            """
            理解｜你已经开始划边界了。
            线索｜排除原因也需要说清楚。

            追问｜排除项是技术原因，还是不够核心？
            """,
        ],

        // 阶段 4：功能与技术方案拆解
        4: [
            """
            理解｜核心功能已经浮出来了。
            线索｜现在要拆到可实现的模块。

            追问｜每个功能背后需要什么技术支撑？
            """,
            """
            理解｜技术方案里一定有不确定部分。
            线索｜先识别最脆弱的模块。

            追问｜哪个模块失败时，整个方案会卡住？
            """,
            """
            理解｜技术拆解要回到用户动作。
            线索｜流程能检查功能是否连贯。

            追问｜用户从打开产品到完成任务会走哪几步？
            """,
        ],

        // 阶段 5：运行逻辑与规则定义
        5: [
            """
            理解｜现在需要定义系统怎么运行。
            线索｜异常情况最能暴露规则缺口。

            追问｜用户操作到一半出错时，系统怎么办？
            """,
            """
            理解｜规则不是越多越好。
            线索｜先找绝对不能突破的底线。

            追问｜有没有隐私、安全或流程规则不能打破？
            """,
        ],

        // 阶段 6：硬性约束设计
        6: [
            """
            理解｜方案需要放进真实限制里。
            线索｜时间和预算会影响技术选型。

            追问｜你有多少时间和资源完成它？
            """,
            """
            理解｜硬件和平台会决定可行边界。
            线索｜先把不能绕开的限制列出来。

            追问｜有什么设备或平台限制必须面对？
            """,
        ],

        // 阶段 7：量化验收标准制定
        7: [
            """
            理解｜现在要把“做成了”变成可验证。
            线索｜成功标准最好能被量化。

            追问｜哪个数字能证明这个产品有效？
            """,
            """
            理解｜指标太多会分散判断。
            线索｜先选最能代表成功的两个。

            追问｜如果只用两个指标，你会选哪两个？
            """,
        ],

        // 阶段 8：风险识别与预案制定
        8: [
            """
            理解｜下一步是提前暴露失败点。
            线索｜风险可能来自技术、用户或时间。

            追问｜这个项目最可能失败在哪里？
            """,
            """
            理解｜风险不是为了吓退项目。
            线索｜Plan B 会让方案更可信。

            追问｜最大风险发生时，你的替代方案是什么？
            """,
        ],

        // 阶段 9：项目阶段拆分与排期
        9: [
            """
            理解｜现在可以把方案变成推进计划。
            线索｜里程碑要能验证关键假设。

            追问｜你会把项目拆成哪几个阶段？
            """,
            """
            理解｜第一个里程碑最重要。
            线索｜它应该验证最核心的不确定性。

            追问｜第一个里程碑验证什么，花多久？
            """,
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
