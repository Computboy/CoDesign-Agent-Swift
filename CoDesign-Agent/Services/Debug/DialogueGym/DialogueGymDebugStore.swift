import Foundation
import Observation

/// Observable store that holds Dialogue Gym run results for the Debug UI.
/// Also provides console-printing support for headless runs.
@MainActor
@Observable
final class DialogueGymDebugStore {
    var reports: [SimulationReport] = []
    var isRunning: Bool = false
    var currentScenarioName: String = ""
    var progressText: String = ""
    var errorMessage: String?

    private let runner = DialogueGymRunner()

    // MARK: - Run All

    func runAllScenarios() async {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        reports.removeAll()

        progressText = "Starting Dialogue Gym..."
        print("[DialogueGymDebugStore] 🏃 Running all built-in scenarios...")

        reports = await runner.runAllBuiltIn()

        isRunning = false
        progressText = "Complete: \(reports.count) scenarios run."

        // Print summary to console
        printReportsToConsole()
        print("[DialogueGymDebugStore] 🏁 Done. \(reports.count) reports.")
    }

    // MARK: - Console Output

    /// Print all reports to console, useful for headless debugging
    /// when the Debug UI is not available.
    func printReportsToConsole() {
        print("")
        print("═══════════════════════════════════════════════════")
        print("  Dialogue Gym — Simulation Reports")
        print("═══════════════════════════════════════════════════")

        for (i, report) in reports.enumerated() {
            print("")
            print("── Report \(i + 1)/\(reports.count): \(report.scenarioTitle) ──")
            print("  Overall Score: \(report.scores.overall)/5")
            print("  Scores:")
            print("    questionNecessity:       \(report.scores.questionNecessity)/5")
            print("    stageAlignment:          \(report.scores.stageAlignment)/5")
            print("    cognitiveProgress:       \(report.scores.cognitiveProgress)/5")
            print("    userBurden:              \(report.scores.userBurden)/5")
            print("    informationCompression:  \(report.scores.informationCompression)/5")
            print("    briefProgress:           \(report.scores.briefProgress)/5")
            print("    convergenceQuality:      \(report.scores.convergenceQuality)/5")

            if !report.detectedProblems.isEmpty {
                print("  Detected Problems (\(report.detectedProblems.count)):")
                for problem in report.detectedProblems {
                    print("    ⚠️  \(problem)")
                }
            }

            if !report.badQuestions.isEmpty {
                print("  Bad Questions (\(report.badQuestions.count)):")
                for question in report.badQuestions {
                    print("    ❌ \(question)")
                }
            }

            if !report.suggestedFixes.isEmpty {
                print("  Suggested Fixes (\(report.suggestedFixes.count)):")
                for fix in report.suggestedFixes {
                    print("    💡 \(fix)")
                }
            }

            print("  Transcript: \(report.transcript.count) turns")
            for turn in report.transcript {
                print("    T\(turn.turnIndex + 1) [\(turn.stageTitle)]")
                print("      Q: \(turn.agentQuestion.prefix(100))...")
                print("      A: \(turn.simulatedUserAnswer.prefix(100))...")
                if !turn.changedBriefFields.isEmpty {
                    print("      Fields: \(turn.changedBriefFields.joined(separator: ", "))")
                }
            }
        }

        print("")
        print("═══════════════════════════════════════════════════")
        print("  End of Reports")
        print("═══════════════════════════════════════════════════")
        print("")
    }
}
