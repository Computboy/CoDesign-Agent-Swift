import Foundation

/// Deterministic business validation for extraction envelopes.
/// This keeps schema/rule failures local instead of trusting the model to self-police.
struct FieldValidationResult: Codable, Equatable {
    var fieldName: String
    var errors: [String]
    var warnings: [String]
    var userEvidenceFound: Bool
    var assistantOnlyEvidence: Bool
    var strongestUserEvidenceLength: Int

    init(
        fieldName: String,
        errors: [String] = [],
        warnings: [String] = [],
        userEvidenceFound: Bool = false,
        assistantOnlyEvidence: Bool = false,
        strongestUserEvidenceLength: Int = 0
    ) {
        self.fieldName = fieldName
        self.errors = errors
        self.warnings = warnings
        self.userEvidenceFound = userEvidenceFound
        self.assistantOnlyEvidence = assistantOnlyEvidence
        self.strongestUserEvidenceLength = strongestUserEvidenceLength
    }

    var hasBlockingErrors: Bool {
        !errors.isEmpty
    }
}

struct ExtractionValidationReport: Codable, Equatable {
    var errors: [String]
    var warnings: [String]
    var fieldResults: [String: FieldValidationResult]

    init(
        errors: [String] = [],
        warnings: [String] = [],
        fieldResults: [String: FieldValidationResult] = [:]
    ) {
        self.errors = errors
        self.warnings = warnings
        self.fieldResults = fieldResults
    }

    var hasErrors: Bool {
        !errors.isEmpty || fieldResults.values.contains { $0.hasBlockingErrors }
    }

    var invalidFieldNames: [String] {
        fieldResults.values
            .filter { $0.hasBlockingErrors }
            .map(\.fieldName)
            .sorted()
    }

    var allErrors: [String] {
        errors + fieldResults.values.flatMap { result in
            result.errors.map { "\(result.fieldName): \($0)" }
        }
    }
}

struct ExtractionSchemaValidator {
    func validate(
        envelope: ExtractionEnvelope,
        messages: [ChatPayloadMessage]
    ) -> ExtractionValidationReport {
        var report = ExtractionValidationReport()
        validateStringField("targetUser", envelope.targetUser, messages: messages, report: &report) { value, result in
            validateTargetUser(value, result: &result)
        }
        validateStringField("painPoint", envelope.painPoint, messages: messages, report: &report)
        validateStringField("useScenario", envelope.useScenario, messages: messages, report: &report)
        validateStringField("coreValue", envelope.coreValue, messages: messages, report: &report)
        validateStringField("differentiation", envelope.differentiation, messages: messages, report: &report)
        validateStringField("mvpFeatures", envelope.mvpFeatures, messages: messages, report: &report)
        validateStringField("technicalModules", envelope.technicalModules, messages: messages, report: &report)
        validateStringField("interactionFlow", envelope.interactionFlow, messages: messages, report: &report)
        validateStringField("operationLogic", envelope.operationLogic, messages: messages, report: &report)
        validateStringField("hardConstraints", envelope.hardConstraints, messages: messages, report: &report)
        validateStringField("milestones", envelope.milestones, messages: messages, report: &report)

        validateBoundaryItems(envelope.boundaryItems, messages: messages, report: &report)
        validateSuccessMetrics(envelope.successMetrics, messages: messages, report: &report)
        validateRisks(envelope.risks, messages: messages, report: &report)

        report.errors = report.fieldResults.values
            .flatMap { result in result.errors.map { "\(result.fieldName): \($0)" } }
            .sorted()
        report.warnings = report.fieldResults.values
            .flatMap { result in result.warnings.map { "\(result.fieldName): \($0)" } }
            .sorted()
        return report
    }

    // MARK: - Field validators

    private func validateStringField(
        _ fieldName: String,
        _ candidate: ExtractedFieldCandidate<String>?,
        messages: [ChatPayloadMessage],
        report: inout ExtractionValidationReport,
        additionalValidation: ((String, inout FieldValidationResult) -> Void)? = nil
    ) {
        guard let candidate, let value = candidate.value else { return }
        var result = validateEvidence(fieldName: fieldName, candidate: candidate, messages: messages)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            result.errors.append("String value is empty after trimming.")
        }
        additionalValidation?(trimmed, &result)
        report.fieldResults[fieldName] = result
    }

    private func validateBoundaryItems(
        _ candidate: ExtractedFieldCandidate<[BoundaryItemDTO]>?,
        messages: [ChatPayloadMessage],
        report: inout ExtractionValidationReport
    ) {
        guard let candidate, let items = candidate.value else { return }
        var result = validateEvidence(fieldName: "boundaryItems", candidate: candidate, messages: messages)
        var seen: Set<String> = []
        for item in items {
            let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty {
                result.errors.append("Boundary item content cannot be empty.")
            }
            let key = "\(content.lowercased())|\(item.isIncluded)"
            if !content.isEmpty && seen.contains(key) {
                result.errors.append("Boundary items cannot contain duplicates: \(content).")
            }
            seen.insert(key)
        }
        report.fieldResults["boundaryItems"] = result
    }

    private func validateSuccessMetrics(
        _ candidate: ExtractedFieldCandidate<[SuccessMetricDTO]>?,
        messages: [ChatPayloadMessage],
        report: inout ExtractionValidationReport
    ) {
        guard let candidate, let items = candidate.value else { return }
        var result = validateEvidence(fieldName: "successMetrics", candidate: candidate, messages: messages)
        for metric in items {
            if metric.metric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.errors.append("Success metric must include metric.")
            }
            if metric.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.errors.append("Success metric must include target.")
            }
        }
        report.fieldResults["successMetrics"] = result
    }

    private func validateRisks(
        _ candidate: ExtractedFieldCandidate<[RiskItemDTO]>?,
        messages: [ChatPayloadMessage],
        report: inout ExtractionValidationReport
    ) {
        guard let candidate, let items = candidate.value else { return }
        var result = validateEvidence(fieldName: "risks", candidate: candidate, messages: messages)
        for risk in items {
            if risk.desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.errors.append("Risk description cannot be empty.")
            }
            if !(1...5).contains(risk.probability) {
                result.errors.append("Risk probability must be between 1 and 5.")
            }
            if !(1...5).contains(risk.impact) {
                result.errors.append("Risk impact must be between 1 and 5.")
            }
        }
        report.fieldResults["risks"] = result
    }

    private func validateTargetUser(
        _ value: String,
        result: inout FieldValidationResult
    ) {
        let genericTerms: Set<String> = ["用户", "学生", "同学", "人群", "大家"]
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard genericTerms.contains(normalized) else { return }

        if result.strongestUserEvidenceLength >= 18 {
            result.warnings.append("Target user is generic; strong evidence keeps it reviewable instead of rejecting it.")
        } else {
            result.errors.append("Target user is too generic without strong user evidence.")
        }
    }

    // MARK: - Evidence validation

    private func validateEvidence<Value: Codable>(
        fieldName: String,
        candidate: ExtractedFieldCandidate<Value>,
        messages: [ChatPayloadMessage]
    ) -> FieldValidationResult {
        var result = FieldValidationResult(fieldName: fieldName)
        guard !candidate.evidence.isEmpty else {
            result.errors.append("Missing evidence from user messages.")
            return result
        }

        var foundUserEvidence = false
        var sawAssistantEvidence = false
        for evidence in candidate.evidence {
            let role = evidence.role.lowercased()
            let quote = evidence.quote.trimmingCharacters(in: .whitespacesAndNewlines)
            if quote.isEmpty {
                result.errors.append("Evidence quote cannot be empty.")
                continue
            }

            if role != "user" {
                sawAssistantEvidence = true
                result.warnings.append("Assistant-only evidence cannot auto commit.")
                continue
            }

            if quoteExistsInUserMessages(quote, messages: messages) {
                foundUserEvidence = true
                result.strongestUserEvidenceLength = max(result.strongestUserEvidenceLength, quote.count)
            } else {
                result.errors.append("Evidence quote was not found in original user messages: \(quote).")
            }
        }

        result.userEvidenceFound = foundUserEvidence
        result.assistantOnlyEvidence = sawAssistantEvidence && !foundUserEvidence
        if !foundUserEvidence {
            result.errors.append("No evidence quote matched an original user message.")
        }
        return result
    }

    private func quoteExistsInUserMessages(
        _ quote: String,
        messages: [ChatPayloadMessage]
    ) -> Bool {
        let normalizedQuote = normalizeForSearch(quote)
        guard !normalizedQuote.isEmpty else { return false }
        return messages
            .filter { $0.role.lowercased() == "user" }
            .contains { normalizeForSearch($0.content).contains(normalizedQuote) }
    }

    private func normalizeForSearch(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .lowercased()
    }

}
