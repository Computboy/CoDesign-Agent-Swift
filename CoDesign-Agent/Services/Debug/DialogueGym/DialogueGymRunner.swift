import Foundation

/// Main orchestrator that runs a scenario through the real CoDesign Agent
/// pipeline, simulates user answers, and evaluates the result.
///
/// Flow:
///   Built-in scenario
///   → RealCoDesignDialogueAgentRunner generates real questions
///   → LLMDialogueUserSimulator plays student role
///   → Repeat for maxTurns
///   → LLMDialogueEvaluator scores the transcript
///   → SimulationReport
@MainActor
final class DialogueGymRunner {
    private let simulator: LLMDialogueUserSimulator
    private let evaluator: LLMDialogueEvaluator

    init(
        simulator: LLMDialogueUserSimulator = LLMDialogueUserSimulator(),
        evaluator: LLMDialogueEvaluator = LLMDialogueEvaluator()
    ) {
        self.simulator = simulator
        self.evaluator = evaluator
    }

    // MARK: - Run Single Scenario

    /// Run a single scenario end-to-end.
    func run(scenario: SimulationScenario) async -> SimulationReport {
        print("[DialogueGym] Starting scenario: \(scenario.title)")
        print("[DialogueGym] Initial idea: \(scenario.initialIdea)")

        // ① Check API key
        let config = LLMAPIConfig.loadFromEnvironment()
        guard config.isValid else {
            print("[DialogueGym] ❌ \(DialogueGymError.missingAPIKey.errorDescription!)")
            return SimulationReport(
                scenarioTitle: scenario.title,
                transcript: [],
                finalBriefSummary: "",
                scores: EvaluationScores(),
                detectedProblems: [DialogueGymError.missingAPIKey.errorDescription!],
                badQuestions: [],
                suggestedFixes: [
                    "请在 Settings → API 设置中配置 Live LLM API Key。",
                    "或设置环境变量 LLM_API_KEY。",
                ]
            )
        }

        // ② Create real agent session
        let agentRunner: RealCoDesignDialogueAgentRunner
        do {
            agentRunner = try RealCoDesignDialogueAgentRunner()
        } catch {
            print("[DialogueGym] ❌ Agent creation failed: \(error)")
            return SimulationReport(
                scenarioTitle: scenario.title,
                transcript: [],
                finalBriefSummary: "",
                scores: EvaluationScores(),
                detectedProblems: ["Agent session creation failed: \(error.localizedDescription)"],
                badQuestions: [],
                suggestedFixes: ["Check that SwiftData models are correctly configured."]
            )
        }

        var transcript: [SimulatedTurn] = []
        var turnIndex = 0

        // ③ Start conversation with initial idea
        let firstResult: DialogueAgentTurnResult
        do {
            print("[DialogueGym] Turn \(turnIndex): Sending initial idea to agent...")
            firstResult = try await agentRunner.start(
                initialIdea: scenario.initialIdea,
                scenario: scenario
            )
            print("[DialogueGym] Agent question: \(firstResult.assistantText.prefix(120))...")
        } catch {
            print("[DialogueGym] ❌ Agent start failed: \(error)")
            return SimulationReport(
                scenarioTitle: scenario.title,
                transcript: transcript,
                finalBriefSummary: "",
                scores: EvaluationScores(),
                detectedProblems: ["Agent start failed: \(error.localizedDescription)"],
                badQuestions: [],
                suggestedFixes: ["Check API configuration and network connectivity."]
            )
        }

        // ④ Main loop
        var lastResult = firstResult
        while turnIndex < scenario.maxTurns {
            // Simulate user answer
            let userAnswer: String
            do {
                print("[DialogueGym] Turn \(turnIndex): Simulating user answer...")
                userAnswer = try await simulator.answer(
                    scenario: scenario,
                    turnIndex: turnIndex,
                    agentQuestion: lastResult.assistantText,
                    currentStageTitle: lastResult.currentStageTitle,
                    previousTurns: transcript
                )
                print("[DialogueGym] User answer: \(userAnswer.prefix(120))...")
            } catch {
                print("[DialogueGym] ⚠️ Simulator failed at turn \(turnIndex): \(error)")
                // Stop the simulation if user simulator fails
                break
            }

            // Record turn
            let turn = SimulatedTurn(
                turnIndex: turnIndex,
                stageTitle: lastResult.currentStageTitle,
                agentQuestion: lastResult.assistantText,
                simulatedUserAnswer: userAnswer,
                changedBriefFields: lastResult.changedBriefFields,
                notes: lastResult.changedBriefFields.isEmpty
                    ? "Brief fields could not be determined for this turn; showing empty."
                    : nil
            )
            transcript.append(turn)

            turnIndex += 1

            // Check if we've reached target stages or max turns
            if turnIndex >= scenario.maxTurns {
                print("[DialogueGym] Reached max turns (\(scenario.maxTurns)).")
                break
            }

            // Send user answer to agent
            do {
                print("[DialogueGym] Turn \(turnIndex): Sending user answer to agent...")
                lastResult = try await agentRunner.sendUserAnswer(userAnswer)
                print("[DialogueGym] Agent question: \(lastResult.assistantText.prefix(120))...")
            } catch {
                print("[DialogueGym] ❌ Agent response failed at turn \(turnIndex): \(error)")
                break
            }
        }

        // Also record the last turn (where agent responded but we may not have
        // gotten a simulated user answer yet — record what we have)
        if let lastTurn = transcript.last {
            // If the last recorded turn doesn't match the last agent result,
            // add a final entry
            if lastTurn.agentQuestion != lastResult.assistantText {
                let finalTurn = SimulatedTurn(
                    turnIndex: turnIndex,
                    stageTitle: lastResult.currentStageTitle,
                    agentQuestion: lastResult.assistantText,
                    simulatedUserAnswer: "(simulation ended)",
                    changedBriefFields: lastResult.changedBriefFields,
                    notes: "Final turn — no simulated user response."
                )
                transcript.append(finalTurn)
            }
        }

        print("[DialogueGym] Transcript has \(transcript.count) turns.")
        print("[DialogueGym] Final brief summary:\n\(lastResult.briefSummary)")

        // ⑤ Evaluate
        print("[DialogueGym] Running evaluator...")
        let report: SimulationReport
        do {
            report = try await evaluator.evaluate(
                scenario: scenario,
                transcript: transcript,
                finalBriefSummary: lastResult.briefSummary
            )
        } catch {
            print("[DialogueGym] ❌ Evaluator failed: \(error)")
            report = SimulationReport(
                scenarioTitle: scenario.title,
                transcript: transcript,
                finalBriefSummary: lastResult.briefSummary,
                scores: EvaluationScores(),
                detectedProblems: ["Evaluator failed: \(error.localizedDescription)"],
                badQuestions: [],
                suggestedFixes: ["Check API configuration."]
            )
        }

        print("[DialogueGym] ✅ Scenario '\(scenario.title)' complete.")
        print("[DialogueGym] Overall score: \(report.scores.overall)/5")
        print("[DialogueGym] Problems: \(report.detectedProblems.count), Bad questions: \(report.badQuestions.count)")

        return report
    }

    // MARK: - Run All Built-in Scenarios

    /// Run all 5 built-in scenarios sequentially.
    /// A single scenario failure does not stop the others.
    func runAllBuiltIn() async -> [SimulationReport] {
        var reports: [SimulationReport] = []
        let scenarios = DialogueGymScenarios.builtIn

        print("[DialogueGym] 🏃 Running all \(scenarios.count) built-in scenarios...")

        for (index, scenario) in scenarios.enumerated() {
            print("[DialogueGym] 📋 Scenario \(index + 1)/\(scenarios.count): \(scenario.title)")
            let report = await run(scenario: scenario)
            reports.append(report)
            print("[DialogueGym] 📊 Report \(index + 1) overall score: \(report.scores.overall)/5")
        }

        print("[DialogueGym] 🏁 All scenarios complete. \(reports.count) reports generated.")
        return reports
    }
}
