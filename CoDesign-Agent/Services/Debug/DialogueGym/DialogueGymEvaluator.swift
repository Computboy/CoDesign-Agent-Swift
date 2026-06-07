import Foundation

/// LLM-based evaluator that assesses the quality of a simulated dialogue.
/// Calls the real LLM API to produce structured evaluation scores.
struct LLMDialogueEvaluator {
    private let apiClient: LLMAPIClient

    init(apiClient: LLMAPIClient = LLMAPIClient()) {
        self.apiClient = apiClient
    }

    /// Evaluate a completed dialogue transcript.
    func evaluate(
        scenario: SimulationScenario,
        transcript: [SimulatedTurn],
        finalBriefSummary: String
    ) async throws -> SimulationReport {
        guard !transcript.isEmpty else {
            return SimulationReport(
                scenarioTitle: scenario.title,
                transcript: transcript,
                finalBriefSummary: finalBriefSummary,
                scores: EvaluationScores(),
                detectedProblems: ["Empty transcript — no turns to evaluate."],
                badQuestions: [],
                suggestedFixes: []
            )
        }

        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(
            scenario: scenario,
            transcript: transcript,
            finalBriefSummary: finalBriefSummary
        )

        let messages: [ChatCompletionMessage] = [
            ChatCompletionMessage(role: "system", content: systemPrompt),
            ChatCompletionMessage(role: "user", content: userPrompt),
        ]

        let rawJSON: String
        do {
            rawJSON = try await apiClient.completeJSON(messages: messages)
        } catch {
            print("[DialogueGymEvaluator] LLM call failed: \(error)")
            throw DialogueGymError.evaluatorFailed("LLM API call failed: \(error.localizedDescription)")
        }

        // Parse the JSON response
        let cleaned = cleanJSON(rawJSON)
        guard let data = cleaned.data(using: .utf8) else {
            print("[DialogueGymEvaluator] Failed to convert response to data. Raw:\n\(rawJSON)")
            return errorReport(
                scenario: scenario,
                transcript: transcript,
                finalBriefSummary: finalBriefSummary,
                error: "Response is not valid UTF-8 data."
            )
        }

        do {
            let decoded = try JSONDecoder().decode(EvaluatorJSONResponse.self, from: data)
            return SimulationReport(
                scenarioTitle: scenario.title,
                transcript: transcript,
                finalBriefSummary: finalBriefSummary,
                scores: EvaluationScores(
                    questionNecessity: clamp(decoded.scores.questionNecessity),
                    stageAlignment: clamp(decoded.scores.stageAlignment),
                    cognitiveProgress: clamp(decoded.scores.cognitiveProgress),
                    userBurden: clamp(decoded.scores.userBurden),
                    informationCompression: clamp(decoded.scores.informationCompression),
                    briefProgress: clamp(decoded.scores.briefProgress),
                    convergenceQuality: clamp(decoded.scores.convergenceQuality),
                    overall: clamp(decoded.scores.overall)
                ),
                detectedProblems: decoded.detectedProblems,
                badQuestions: decoded.badQuestions,
                suggestedFixes: decoded.suggestedFixes
            )
        } catch {
            print("[DialogueGymEvaluator] JSON parse failed: \(error). Raw response:\n\(rawJSON)")
            return errorReport(
                scenario: scenario,
                transcript: transcript,
                finalBriefSummary: finalBriefSummary,
                error: "JSON parse error: \(error.localizedDescription). Raw: \(rawJSON.prefix(500))"
            )
        }
    }

    // MARK: - Private

    private func buildSystemPrompt() -> String {
        """
        你是一个严格的 AI 产品对话质量评估器，专门评估设计思维训练 Agent 的苏格拉底式提问质量。

        你要判断 Agent 是否真正推动用户完成设计判断，而不是机械追问。

        评价重点：
        1. 每个问题是否有必要；
        2. 问题是否匹配当前阶段；
        3. 是否触发澄清、区分、反设、取舍、降级等认知动作；
        4. 是否降低而不是增加用户负担；
        5. 是否总结已知信息并推进；
        6. 是否推动 DesignBrief 进展；
        7. 是否形成清楚的 MVP 方向。

        请只输出 JSON，不要输出 Markdown，不要解释 JSON 外的内容。

        JSON 格式：
        {
          "scores": {
            "questionNecessity": 1,
            "stageAlignment": 1,
            "cognitiveProgress": 1,
            "userBurden": 1,
            "informationCompression": 1,
            "briefProgress": 1,
            "convergenceQuality": 1,
            "overall": 1
          },
          "detectedProblems": [],
          "badQuestions": [],
          "suggestedFixes": []
        }

        所有分数使用 1–5 分制（整数）。

        评分标准：

        questionNecessity（问题是否改变设计决策）：
        - 5：每个问题都推动了一个设计决策
        - 3：有些问题有价值，但也有一些只是确认或重复
        - 1：大量问题只问情绪，不改变设计；或只是「能再具体说说」；或反复追问已明确内容

        stageAlignment（问题是否匹配当前阶段）：
        - 5：每个问题都精准匹配当前阶段目标
        - 3：基本匹配，但部分问题跨越到其他阶段
        - 1：Stage 4 仍在问 Stage 1 的痛点/情绪问题，严重阶段错位

        cognitiveProgress（是否触发认知动作）：
        - 5：多次触发澄清、区分、反设、取舍、降级等高价值认知动作
        - 3：触发了 1-2 种认知动作
        - 1：所有问题都是信息收集，没有推动认知升级

        userBurden（用户负担）：
        - 5：问题刚好在用户能回答的范围内，轻松自然
        - 3：有些问题过细或过难，但总体上用户能跟上
        - 1：大量问题过细、过难、过抽象，用户明显跟不上

        informationCompression（是否总结已知信息并推进）：
        - 5：Agent 经常总结已明确的信息，然后推进到下一个判断
        - 3：偶尔总结，但多数时候只是继续追问
        - 1：从不总结，只是一轮一轮地问下去

        briefProgress（是否推动 DesignBrief 字段更新）：
        - 5：每轮对话都有明确的 brief 字段更新
        - 3：部分轮次推动了 brief 更新，但不是全部
        - 1：对话几乎没有推动 brief 变化

        convergenceQuality（是否形成清楚 MVP 方向）：
        - 5：对话结束时形成了明确的 MVP 方向、功能边界和下一步
        - 3：对话有了大致方向，但细节和边界不够清晰
        - 1：对话结束时仍然很模糊，没有形成可执行的方案

        overall：综合以上维度的总体评分，1–5 分。

        detectedProblems：列出检测到的具体问题，每个问题用中文描述。如果没有问题，返回空数组。
        badQuestions：列出质量低的具体问题文本（从 transcript 中摘录）。如果没有，返回空数组。
        suggestedFixes：给出改进建议，每条用中文描述。如果没有，返回空数组。
        """
    }

    private func buildUserPrompt(
        scenario: SimulationScenario,
        transcript: [SimulatedTurn],
        finalBriefSummary: String
    ) -> String {
        var lines: [String] = []

        lines.append("## 场景信息")
        lines.append("- 标题：\(scenario.title)")
        lines.append("- 初始想法：\(scenario.initialIdea)")
        lines.append("- 用户 Persona：\(scenario.userPersona)")
        lines.append("- 目标阶段：\(scenario.targetStages.map(String.init).joined(separator: ", "))")
        lines.append("")
        lines.append("## 关注检查项")
        for check in scenario.focusChecks {
            lines.append("- \(check)")
        }
        lines.append("")
        lines.append("## 对话 Transcript")
        for turn in transcript {
            lines.append("")
            lines.append("--- Turn \(turn.turnIndex + 1) [阶段: \(turn.stageTitle)] ---")
            lines.append("Agent: \(turn.agentQuestion)")
            lines.append("User: \(turn.simulatedUserAnswer)")
            if let notes = turn.notes {
                lines.append("Notes: \(notes)")
            }
        }
        lines.append("")
        lines.append("## 最终 DesignBrief 摘要")
        lines.append(finalBriefSummary)

        lines.append("")
        lines.append("请基于以上 transcript 和 final brief 进行评分。只输出 JSON。")

        return lines.joined(separator: "\n")
    }

    private func cleanJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") {
            s = String(s.dropFirst(7))
        } else if s.hasPrefix("```") {
            s = String(s.dropFirst(3))
        }
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clamp(_ value: Int) -> Int {
        max(1, min(5, value))
    }

    private func errorReport(
        scenario: SimulationScenario,
        transcript: [SimulatedTurn],
        finalBriefSummary: String,
        error: String
    ) -> SimulationReport {
        SimulationReport(
            scenarioTitle: scenario.title,
            transcript: transcript,
            finalBriefSummary: finalBriefSummary,
            scores: EvaluationScores(),
            detectedProblems: ["Evaluation failed: \(error)"],
            badQuestions: [],
            suggestedFixes: ["Re-run the evaluation with a valid API configuration."]
        )
    }
}
