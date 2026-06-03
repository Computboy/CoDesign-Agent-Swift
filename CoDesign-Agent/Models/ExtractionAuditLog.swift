import Foundation
import SwiftData

/// Persistent trace of every extraction decision that affected, queued, or rejected a DesignBrief field.
enum ExtractionAuditDecision: String, Codable {
    case autoCommitted
    case needsReview
    case rejected
    case userAccepted
    case userEdited
    case userIgnored
}

@Model
final class ExtractionAuditLog {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var fieldName: String
    var oldValue: String?
    var candidateValue: String?
    var confidence: Double
    var level: String
    var evidenceQuote: String?
    var decision: String
    var validationNotes: String

    var brief: DesignBrief?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        fieldName: String,
        oldValue: String? = nil,
        candidateValue: String? = nil,
        confidence: Double = 0,
        level: FieldConfidenceLevel = .rejected,
        evidenceQuote: String? = nil,
        decision: ExtractionAuditDecision,
        validationNotes: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.fieldName = fieldName
        self.oldValue = oldValue
        self.candidateValue = candidateValue
        self.confidence = confidence
        self.level = level.rawValue
        self.evidenceQuote = evidenceQuote
        self.decision = decision.rawValue
        self.validationNotes = validationNotes.joined(separator: "\n")
    }

    var levelValue: FieldConfidenceLevel {
        FieldConfidenceLevel(rawValue: level) ?? .rejected
    }

    var decisionValue: ExtractionAuditDecision {
        ExtractionAuditDecision(rawValue: decision) ?? .rejected
    }

    var validationNoteList: [String] {
        validationNotes
            .split(separator: "\n")
            .map { String($0) }
    }
}
