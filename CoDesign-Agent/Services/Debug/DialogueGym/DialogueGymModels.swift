import Foundation

// MARK: - SimulationScenario

struct SimulationScenario: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let initialIdea: String
    let userPersona: String
    let answerStyle: String
    let maxTurns: Int
    let targetStages: [Int]
    let focusChecks: [String]

    init(
        id: UUID = UUID(),
        title: String,
        initialIdea: String,
        userPersona: String,
        answerStyle: String,
        maxTurns: Int = 10,
        targetStages: [Int] = [1, 2, 3, 4],
        focusChecks: [String] = []
    ) {
        self.id = id
        self.title = title
        self.initialIdea = initialIdea
        self.userPersona = userPersona
        self.answerStyle = answerStyle
        self.maxTurns = maxTurns
        self.targetStages = targetStages
        self.focusChecks = focusChecks
    }
}

// MARK: - SimulatedTurn

struct SimulatedTurn: Identifiable, Codable, Equatable {
    let id: UUID
    let turnIndex: Int
    let stageTitle: String
    let agentQuestion: String
    let simulatedUserAnswer: String
    let changedBriefFields: [String]
    let notes: String?

    init(
        id: UUID = UUID(),
        turnIndex: Int,
        stageTitle: String,
        agentQuestion: String,
        simulatedUserAnswer: String,
        changedBriefFields: [String] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.turnIndex = turnIndex
        self.stageTitle = stageTitle
        self.agentQuestion = agentQuestion
        self.simulatedUserAnswer = simulatedUserAnswer
        self.changedBriefFields = changedBriefFields
        self.notes = notes
    }
}

// MARK: - EvaluationScores

struct EvaluationScores: Codable, Equatable {
    let questionNecessity: Int
    let stageAlignment: Int
    let cognitiveProgress: Int
    let userBurden: Int
    let informationCompression: Int
    let briefProgress: Int
    let convergenceQuality: Int
    let overall: Int

    init(
        questionNecessity: Int = 0,
        stageAlignment: Int = 0,
        cognitiveProgress: Int = 0,
        userBurden: Int = 0,
        informationCompression: Int = 0,
        briefProgress: Int = 0,
        convergenceQuality: Int = 0,
        overall: Int = 0
    ) {
        self.questionNecessity = questionNecessity
        self.stageAlignment = stageAlignment
        self.cognitiveProgress = cognitiveProgress
        self.userBurden = userBurden
        self.informationCompression = informationCompression
        self.briefProgress = briefProgress
        self.convergenceQuality = convergenceQuality
        self.overall = overall
    }
}

// MARK: - SimulationReport

struct SimulationReport: Identifiable, Codable, Equatable {
    let id: UUID
    let scenarioTitle: String
    let transcript: [SimulatedTurn]
    let finalBriefSummary: String
    let scores: EvaluationScores
    let detectedProblems: [String]
    let badQuestions: [String]
    let suggestedFixes: [String]
    let runTimestamp: Date

    init(
        id: UUID = UUID(),
        scenarioTitle: String,
        transcript: [SimulatedTurn],
        finalBriefSummary: String,
        scores: EvaluationScores = EvaluationScores(),
        detectedProblems: [String] = [],
        badQuestions: [String] = [],
        suggestedFixes: [String] = [],
        runTimestamp: Date = Date()
    ) {
        self.id = id
        self.scenarioTitle = scenarioTitle
        self.transcript = transcript
        self.finalBriefSummary = finalBriefSummary
        self.scores = scores
        self.detectedProblems = detectedProblems
        self.badQuestions = badQuestions
        self.suggestedFixes = suggestedFixes
        self.runTimestamp = runTimestamp
    }
}

// MARK: - DialogueAgentRunning Protocol

struct DialogueAgentTurnResult: Codable, Equatable {
    let assistantText: String
    let currentStageTitle: String
    let changedBriefFields: [String]
    let briefSummary: String

    init(
        assistantText: String,
        currentStageTitle: String,
        changedBriefFields: [String] = [],
        briefSummary: String = ""
    ) {
        self.assistantText = assistantText
        self.currentStageTitle = currentStageTitle
        self.changedBriefFields = changedBriefFields
        self.briefSummary = briefSummary
    }
}

protocol DialogueAgentRunning {
    func start(initialIdea: String, scenario: SimulationScenario) async throws -> DialogueAgentTurnResult
    func sendUserAnswer(_ answer: String) async throws -> DialogueAgentTurnResult
}

// MARK: - Evaluator JSON DTOs (for decoding LLM response)

struct EvaluatorJSONResponse: Codable {
    let scores: EvaluatorScoresJSON
    let detectedProblems: [String]
    let badQuestions: [String]
    let suggestedFixes: [String]

    struct EvaluatorScoresJSON: Codable {
        let questionNecessity: Int
        let stageAlignment: Int
        let cognitiveProgress: Int
        let userBurden: Int
        let informationCompression: Int
        let briefProgress: Int
        let convergenceQuality: Int
        let overall: Int
    }
}

// MARK: - DialogueGym Error

enum DialogueGymError: Error, LocalizedError {
    case missingAPIKey
    case agentCreationFailed(String)
    case agentStreamFailed(String)
    case simulatorFailed(String)
    case evaluatorFailed(String)
    case evaluatorJSONParseFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Dialogue Gym requires a configured Live LLM API key."
        case .agentCreationFailed(let msg):
            return "Failed to create agent session: \(msg)"
        case .agentStreamFailed(let msg):
            return "Agent stream failed: \(msg)"
        case .simulatorFailed(let msg):
            return "User simulator failed: \(msg)"
        case .evaluatorFailed(let msg):
            return "Evaluator failed: \(msg)"
        case .evaluatorJSONParseFailed(let msg):
            return "Evaluator JSON parse failed: \(msg)"
        }
    }
}
