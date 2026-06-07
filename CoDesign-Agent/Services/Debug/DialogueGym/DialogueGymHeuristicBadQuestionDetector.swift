import Foundation

struct DialogueGymHeuristicFindings {
    let detectedProblems: [String]
    let badQuestions: [String]

    var isEmpty: Bool {
        detectedProblems.isEmpty && badQuestions.isEmpty
    }
}

/// Local rule-based checks that run before the LLM evaluator.
/// They catch known low-value question patterns even when the evaluator misses them.
struct DialogueGymHeuristicBadQuestionDetector {
    private let requiredStageOneFields = ["目标用户", "核心痛点", "使用场景"]
    private let overGranularPatterns = [
        "最不开心的是什么",
        "这段距离让你感觉如何",
        "能不能再具体说说找不到路",
        "再具体说说找不到路",
        "找不到路时最不开心",
        "找不到路的时候最不开心",
        "感觉如何",
        "不开心",
    ]

    func detect(
        transcript: [SimulatedTurn],
        finalBriefSummary: String
    ) -> DialogueGymHeuristicFindings {
        var knownFields: Set<String> = []
        var detectedProblems: [String] = []
        var badQuestions: [String] = []
        let finalBriefHasStageOne = finalBriefSummaryContainsStageOne(finalBriefSummary)

        for turn in transcript {
            let hasStageOneFields = requiredStageOneFields.allSatisfy { knownFields.contains($0) }
                || finalBriefHasStageOne

            if hasStageOneFields, isOverGranularQuestion(turn.agentQuestion) {
                detectedProblems.append(
                    "possibleOverGranularQuestion: 目标用户/痛点/场景已有信息后，Agent 仍在追问低必要性的情绪或过细细节。"
                )
                badQuestions.append(turn.agentQuestion)
            }

            knownFields.formUnion(turn.changedBriefFields)
        }

        return DialogueGymHeuristicFindings(
            detectedProblems: unique(detectedProblems),
            badQuestions: unique(badQuestions)
        )
    }

    private func isOverGranularQuestion(_ question: String) -> Bool {
        let normalized = question
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        return overGranularPatterns.contains { pattern in
            normalized.contains(pattern.lowercased())
        }
    }

    private func finalBriefSummaryContainsStageOne(_ summary: String) -> Bool {
        summary.contains("目标用户：")
            && summary.contains("痛点：")
            && summary.contains("场景：")
    }

    private func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}
