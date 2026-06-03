import Foundation

/// Field-level envelope returned by live/mock extraction before anything is written to SwiftData.
/// The LLM can propose values, but local validation/scoring decides the final level and commit flag.
enum FieldConfidenceLevel: String, Codable, Equatable {
    case confirmed
    case needsReview
    case rejected

    static func level(for score: Double) -> FieldConfidenceLevel {
        if score >= 0.75 { return .confirmed }
        if score >= 0.45 { return .needsReview }
        return .rejected
    }

    var displayName: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .needsReview: return "Needs Review"
        case .rejected: return "Rejected"
        }
    }
}

struct EvidenceSpan: Codable, Equatable {
    var role: String
    var quote: String
    var turnIndex: Int

    init(role: String, quote: String, turnIndex: Int) {
        self.role = role
        self.quote = quote
        self.turnIndex = turnIndex
    }
}

struct ExtractedFieldCandidate<Value: Codable>: Codable {
    var value: Value?
    var confidence: Double
    var level: FieldConfidenceLevel
    var evidence: [EvidenceSpan]
    var validationNotes: [String]
    var shouldAutoCommit: Bool

    init(
        value: Value? = nil,
        confidence: Double = 0,
        level: FieldConfidenceLevel = .rejected,
        evidence: [EvidenceSpan] = [],
        validationNotes: [String] = [],
        shouldAutoCommit: Bool = false
    ) {
        self.value = value
        self.confidence = confidence
        self.level = level
        self.evidence = evidence
        self.validationNotes = validationNotes
        self.shouldAutoCommit = shouldAutoCommit
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case confidence
        case level
        case evidence
        case validationNotes
        case shouldAutoCommit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(Value.self, forKey: .value)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        level = try container.decodeIfPresent(FieldConfidenceLevel.self, forKey: .level) ?? .rejected
        evidence = try container.decodeIfPresent([EvidenceSpan].self, forKey: .evidence) ?? []
        validationNotes = try container.decodeIfPresent([String].self, forKey: .validationNotes) ?? []
        shouldAutoCommit = try container.decodeIfPresent(Bool.self, forKey: .shouldAutoCommit) ?? false
    }
}

struct ExtractionEnvelope: Codable {
    var targetUser: ExtractedFieldCandidate<String>?
    var painPoint: ExtractedFieldCandidate<String>?
    var useScenario: ExtractedFieldCandidate<String>?
    var coreValue: ExtractedFieldCandidate<String>?
    var differentiation: ExtractedFieldCandidate<String>?
    var boundaryItems: ExtractedFieldCandidate<[BoundaryItemDTO]>?
    var mvpFeatures: ExtractedFieldCandidate<String>?
    var technicalModules: ExtractedFieldCandidate<String>?
    var interactionFlow: ExtractedFieldCandidate<String>?
    var operationLogic: ExtractedFieldCandidate<String>?
    var hardConstraints: ExtractedFieldCandidate<String>?
    var successMetrics: ExtractedFieldCandidate<[SuccessMetricDTO]>?
    var risks: ExtractedFieldCandidate<[RiskItemDTO]>?
    var milestones: ExtractedFieldCandidate<String>?

    init(
        targetUser: ExtractedFieldCandidate<String>? = nil,
        painPoint: ExtractedFieldCandidate<String>? = nil,
        useScenario: ExtractedFieldCandidate<String>? = nil,
        coreValue: ExtractedFieldCandidate<String>? = nil,
        differentiation: ExtractedFieldCandidate<String>? = nil,
        boundaryItems: ExtractedFieldCandidate<[BoundaryItemDTO]>? = nil,
        mvpFeatures: ExtractedFieldCandidate<String>? = nil,
        technicalModules: ExtractedFieldCandidate<String>? = nil,
        interactionFlow: ExtractedFieldCandidate<String>? = nil,
        operationLogic: ExtractedFieldCandidate<String>? = nil,
        hardConstraints: ExtractedFieldCandidate<String>? = nil,
        successMetrics: ExtractedFieldCandidate<[SuccessMetricDTO]>? = nil,
        risks: ExtractedFieldCandidate<[RiskItemDTO]>? = nil,
        milestones: ExtractedFieldCandidate<String>? = nil
    ) {
        self.targetUser = targetUser
        self.painPoint = painPoint
        self.useScenario = useScenario
        self.coreValue = coreValue
        self.differentiation = differentiation
        self.boundaryItems = boundaryItems
        self.mvpFeatures = mvpFeatures
        self.technicalModules = technicalModules
        self.interactionFlow = interactionFlow
        self.operationLogic = operationLogic
        self.hardConstraints = hardConstraints
        self.successMetrics = successMetrics
        self.risks = risks
        self.milestones = milestones
    }

    var hasCandidateValue: Bool {
        stringCandidates.contains { $0.value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            || boundaryItems?.value?.isEmpty == false
            || successMetrics?.value?.isEmpty == false
            || risks?.value?.isEmpty == false
    }

    var hasReliableCandidate: Bool {
        allCandidateSummaries.contains { $0.level == .confirmed || $0.level == .needsReview }
    }

    var allCandidateSummaries: [FieldCandidateSummary] {
        var summaries: [FieldCandidateSummary] = []
        appendSummary(&summaries, fieldName: "targetUser", candidate: targetUser)
        appendSummary(&summaries, fieldName: "painPoint", candidate: painPoint)
        appendSummary(&summaries, fieldName: "useScenario", candidate: useScenario)
        appendSummary(&summaries, fieldName: "coreValue", candidate: coreValue)
        appendSummary(&summaries, fieldName: "differentiation", candidate: differentiation)
        appendSummary(&summaries, fieldName: "boundaryItems", candidate: boundaryItems)
        appendSummary(&summaries, fieldName: "mvpFeatures", candidate: mvpFeatures)
        appendSummary(&summaries, fieldName: "technicalModules", candidate: technicalModules)
        appendSummary(&summaries, fieldName: "interactionFlow", candidate: interactionFlow)
        appendSummary(&summaries, fieldName: "operationLogic", candidate: operationLogic)
        appendSummary(&summaries, fieldName: "hardConstraints", candidate: hardConstraints)
        appendSummary(&summaries, fieldName: "successMetrics", candidate: successMetrics)
        appendSummary(&summaries, fieldName: "risks", candidate: risks)
        appendSummary(&summaries, fieldName: "milestones", candidate: milestones)
        return summaries
    }

    private var stringCandidates: [ExtractedFieldCandidate<String>] {
        [
            targetUser,
            painPoint,
            useScenario,
            coreValue,
            differentiation,
            mvpFeatures,
            technicalModules,
            interactionFlow,
            operationLogic,
            hardConstraints,
            milestones,
        ].compactMap { $0 }
    }

    private func appendSummary<Value: Codable>(
        _ summaries: inout [FieldCandidateSummary],
        fieldName: String,
        candidate: ExtractedFieldCandidate<Value>?
    ) {
        guard let candidate else { return }
        summaries.append(
            FieldCandidateSummary(
                fieldName: fieldName,
                confidence: candidate.confidence,
                level: candidate.level,
                evidenceQuote: candidate.evidence.first?.quote,
                validationNotes: candidate.validationNotes,
                shouldAutoCommit: candidate.shouldAutoCommit
            )
        )
    }
}

struct FieldCandidateSummary: Equatable {
    var fieldName: String
    var confidence: Double
    var level: FieldConfidenceLevel
    var evidenceQuote: String?
    var validationNotes: [String]
    var shouldAutoCommit: Bool
}

enum ExtractionOutcomeSource: String, Codable {
    case live
    case mock
}

enum ExtractionOutcomeStatus: String, Codable {
    case succeeded
    case failed
}

struct ExtractionOutcome: Codable {
    var id: UUID
    var timestamp: Date
    var source: ExtractionOutcomeSource
    var status: ExtractionOutcomeStatus
    var envelope: ExtractionEnvelope?
    var validationReport: ExtractionValidationReport?
    var failureMessage: String?
    var attemptCount: Int

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: ExtractionOutcomeSource,
        status: ExtractionOutcomeStatus,
        envelope: ExtractionEnvelope? = nil,
        validationReport: ExtractionValidationReport? = nil,
        failureMessage: String? = nil,
        attemptCount: Int = 1
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.status = status
        self.envelope = envelope
        self.validationReport = validationReport
        self.failureMessage = failureMessage
        self.attemptCount = attemptCount
    }

    var isFailed: Bool {
        status == .failed
    }

    static func failed(
        source: ExtractionOutcomeSource,
        message: String,
        envelope: ExtractionEnvelope? = nil,
        validationReport: ExtractionValidationReport? = nil,
        attemptCount: Int
    ) -> ExtractionOutcome {
        ExtractionOutcome(
            source: source,
            status: .failed,
            envelope: envelope,
            validationReport: validationReport,
            failureMessage: message,
            attemptCount: attemptCount
        )
    }
}
