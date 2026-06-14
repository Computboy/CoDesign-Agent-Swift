#if DEBUG
import Foundation

final class PresentationLLMService: LLMServiceProtocol {
    func streamChat(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        mode: ClarificationMode,
        resourceCards: [ResourceCard]
    ) -> AsyncThrowingStream<String, Error> {
        let response = response(
            messages: messages,
            briefSnapshot: briefSnapshot,
            currentStage: currentStage,
            mode: mode,
            resourceCards: resourceCards
        )

        return AsyncThrowingStream { continuation in
            Task {
                try? await Task.sleep(for: .milliseconds(520))
                let chunks = Self.chunks(from: response)
                for chunk in chunks {
                    try? await Task.sleep(for: .milliseconds(42))
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }

    private func response(
        messages: [ChatPayloadMessage],
        briefSnapshot: DesignBriefSnapshot?,
        currentStage: ProgressStageSnapshot?,
        mode: ClarificationMode,
        resourceCards: [ResourceCard]
    ) -> String {
        if mode == .stuckScaffold {
            return """
            我们先不急着扩展功能。这里可以借用「问题框定」的线索：先确认哪一个真实观看场景最能代表你的项目价值。

            追问：如果第一版只能服务一种课堂展示情境，你最想让哪类同学在看完后产生什么变化？
            """
        }

        let lastUserText = messages.last(where: { $0.role == "user" })?.content ?? ""

        if lastUserText.contains("18") || lastUserText.contains("短视频") || lastUserText.contains("记不住") {
            return """
            我把你的回答先沉淀成三个判断：目标用户是 18-24 岁大学生；核心痛点不是“不了解传统文化”，而是短视频场景里内容容易说教、缺少记忆点；使用场景是课程展示或校园文化活动前的快速创作。

            本轮我参考了「Wicked Problem Framing」和「Reflective Practice」：先框定一个可行动的问题，再追问它背后的判断。下一步请确认：第一版必须保留哪些能力，哪些能力虽然诱人但应该先排除？
            """
        }

        if lastUserText.contains("80") || lastUserText.contains("错误率") || lastUserText.contains("三周") {
            return """
            现在这个项目已经可以收束为一份完整 Design Brief。成功标准可以包括脚本可继续修改成作品的比例、文化事实错误率，以及从输入主题到导出简报的完成时间。

            我建议最后把风险也写清楚：AI 可能生成未经核验的文化事实，或把短视频写成课堂讲稿。对应预案是保留依据卡片、人工确认节点，以及“不自动发布”的边界。这样你的方案既展示了 AI 能力，也保留了设计判断。
            """
        }

        if lastUserText.contains("脚本") || lastUserText.contains("分镜") || lastUserText.contains("不做真实视频") {
            return """
            很好，边界开始变清楚了。第一版可以聚焦在“主题输入 → 受众和情绪目标 → 脚本/分镜草稿 → 文化依据卡片 → 用户确认导出”这条最小闭环。

            这里的关键不是让 AI 一步生成最终作品，而是让用户看到依据、能修改、能决定是否采纳。下一步请补充：你准备用哪些量化指标判断这个原型在课堂展示中算成功？
            """
        }

        let card = resourceCards.first
        let cardTitle = card?.title ?? "设计问题框定"
        return """
        我会先基于「\(cardTitle)」帮你把回答转成一个可判断的设计变量。

        追问：在这个项目里，哪一个用户场景最能验证你的核心价值？
        """
    }

    private static func chunks(from text: String) -> [String] {
        var chunks: [String] = []
        var current = ""

        for character in text {
            current.append(character)
            if current.count >= 5 || character == "\n" {
                chunks.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks
    }
}
#endif
