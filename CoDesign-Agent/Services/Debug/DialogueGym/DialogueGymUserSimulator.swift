import Foundation

/// LLM-based user simulator that plays the role of a student user.
/// Calls the real LLM API to generate authentic student responses.
struct LLMDialogueUserSimulator {
    private let apiClient: LLMAPIClient

    init(apiClient: LLMAPIClient = LLMAPIClient()) {
        self.apiClient = apiClient
    }

    /// Generate a simulated user answer by calling the real LLM.
    func answer(
        scenario: SimulationScenario,
        turnIndex: Int,
        agentQuestion: String,
        currentStageTitle: String,
        previousTurns: [SimulatedTurn]
    ) async throws -> String {
        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(
            scenario: scenario,
            turnIndex: turnIndex,
            agentQuestion: agentQuestion,
            currentStageTitle: currentStageTitle,
            previousTurns: previousTurns
        )

        let messages: [ChatCompletionMessage] = [
            ChatCompletionMessage(role: "system", content: systemPrompt),
            ChatCompletionMessage(role: "user", content: userPrompt),
        ]

        // Use streaming API and collect all tokens
        let stream = apiClient.streamChat(messages: messages)
        var response = ""
        do {
            for try await token in stream {
                response += token
            }
        } catch {
            throw DialogueGymError.simulatorFailed("Stream failed: \(error.localizedDescription)")
        }

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DialogueGymError.simulatorFailed("Empty response from LLM")
        }

        return trimmed
    }

    // MARK: - Private

    private func buildSystemPrompt() -> String {
        """
        你正在扮演一个真实的学生用户，正在和一个设计思维训练 Agent 对话。

        你不是产品经理，也不是专家。你不会主动给完整 PRD。
        你要根据给定 persona 和 answer style 回答。

        回答要求：
        1. 简短，通常 1–3 句话；
        2. 口语化；
        3. 不主动补全所有设计细节；
        4. 可以说"不太确定""我还没想好"；
        5. 如果 Agent 问得太细、重复或没有必要，可以自然地表达困惑；
        6. 不要故意破坏对话；
        7. 不要替 Agent 评价自己；
        8. 不要输出 JSON，只输出学生用户会说的话。
        """
    }

    private func buildUserPrompt(
        scenario: SimulationScenario,
        turnIndex: Int,
        agentQuestion: String,
        currentStageTitle: String,
        previousTurns: [SimulatedTurn]
    ) -> String {
        var lines: [String] = []

        lines.append("Scenario title:")
        lines.append(scenario.title)
        lines.append("")
        lines.append("Initial idea:")
        lines.append(scenario.initialIdea)
        lines.append("")
        lines.append("Persona:")
        lines.append(scenario.userPersona)
        lines.append("")
        lines.append("Answer style:")
        lines.append(scenario.answerStyle)
        lines.append("")
        lines.append("Current stage:")
        lines.append(currentStageTitle)
        lines.append("")
        lines.append("Agent question:")
        lines.append(agentQuestion)
        lines.append("")

        if !previousTurns.isEmpty {
            lines.append("Previous turns:")
            for turn in previousTurns.suffix(4) {
                lines.append("- Agent: \(turn.agentQuestion)")
                lines.append("- You: \(turn.simulatedUserAnswer)")
            }
            lines.append("")
        }

        lines.append("请扮演该学生，直接回答 Agent 的问题。")

        return lines.joined(separator: "\n")
    }
}
