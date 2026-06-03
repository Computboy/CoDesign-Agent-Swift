import Foundation

/// Recomputes confidence from evidence, specificity, validation consistency, and model self-confidence.
/// Blocking validation errors force a rejected field even when the model reports high confidence.
struct ExtractionConfidenceScorer {
    func score(
        envelope: ExtractionEnvelope,
        validationReport: ExtractionValidationReport
    ) -> ExtractionEnvelope {
        var scored = envelope
        scored.targetUser = scoreStringCandidate("targetUser", envelope.targetUser, validationReport: validationReport)
        scored.painPoint = scoreStringCandidate("painPoint", envelope.painPoint, validationReport: validationReport)
        scored.useScenario = scoreStringCandidate("useScenario", envelope.useScenario, validationReport: validationReport)
        scored.coreValue = scoreStringCandidate("coreValue", envelope.coreValue, validationReport: validationReport)
        scored.differentiation = scoreStringCandidate("differentiation", envelope.differentiation, validationReport: validationReport)
        scored.mvpFeatures = scoreStringCandidate("mvpFeatures", envelope.mvpFeatures, validationReport: validationReport)
        scored.technicalModules = scoreStringCandidate("technicalModules", envelope.technicalModules, validationReport: validationReport)
        scored.interactionFlow = scoreStringCandidate("interactionFlow", envelope.interactionFlow, validationReport: validationReport)
        scored.operationLogic = scoreStringCandidate("operationLogic", envelope.operationLogic, validationReport: validationReport)
        scored.hardConstraints = scoreStringCandidate("hardConstraints", envelope.hardConstraints, validationReport: validationReport)
        scored.milestones = scoreStringCandidate("milestones", envelope.milestones, validationReport: validationReport)
        scored.boundaryItems = scoreBoundaryItems(envelope.boundaryItems, validationReport: validationReport)
        scored.successMetrics = scoreSuccessMetrics(envelope.successMetrics, validationReport: validationReport)
        scored.risks = scoreRisks(envelope.risks, validationReport: validationReport)
        return scored
    }

    // MARK: - Candidate scoring

    private func scoreStringCandidate(
        _ fieldName: String,
        _ candidate: ExtractedFieldCandidate<String>?,
        validationReport: ExtractionValidationReport
    ) -> ExtractedFieldCandidate<String>? {
        guard var candidate, let value = candidate.value else { return candidate }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate.value = trimmed

        let specificity: Double
        if fieldName == "targetUser" && ["用户", "学生", "同学", "人群", "大家"].contains(trimmed) {
            specificity = 0.1
        } else if trimmed.count >= 24 {
            specificity = 1
        } else if trimmed.count >= 12 {
            specificity = 0.75
        } else if trimmed.count >= 5 {
            specificity = 0.45
        } else {
            specificity = 0.1
        }

        return finalize(
            fieldName: fieldName,
            candidate: candidate,
            specificityScore: specificity,
            validationReport: validationReport
        )
    }

    private func scoreBoundaryItems(
        _ candidate: ExtractedFieldCandidate<[BoundaryItemDTO]>?,
        validationReport: ExtractionValidationReport
    ) -> ExtractedFieldCandidate<[BoundaryItemDTO]>? {
        guard let candidate, let items = candidate.value else { return candidate }
        let nonEmptyItems = items.filter {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let averageSpecificity = average(
            nonEmptyItems.map { item in
                item.content.count >= 12 ? 1 : (item.content.count >= 5 ? 0.65 : 0.25)
            }
        )
        return finalize(
            fieldName: "boundaryItems",
            candidate: candidate,
            specificityScore: averageSpecificity,
            validationReport: validationReport
        )
    }

    private func scoreSuccessMetrics(
        _ candidate: ExtractedFieldCandidate<[SuccessMetricDTO]>?,
        validationReport: ExtractionValidationReport
    ) -> ExtractedFieldCandidate<[SuccessMetricDTO]>? {
        guard let candidate, let items = candidate.value else { return candidate }
        let scores = items.map { metric -> Double in
            let hasMetric = !metric.metric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasTarget = !metric.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasMetric && hasTarget && metric.measurement?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return 1
            }
            if hasMetric && hasTarget {
                return 0.8
            }
            return 0.2
        }
        return finalize(
            fieldName: "successMetrics",
            candidate: candidate,
            specificityScore: average(scores),
            validationReport: validationReport
        )
    }

    private func scoreRisks(
        _ candidate: ExtractedFieldCandidate<[RiskItemDTO]>?,
        validationReport: ExtractionValidationReport
    ) -> ExtractedFieldCandidate<[RiskItemDTO]>? {
        guard let candidate, let items = candidate.value else { return candidate }
        let scores = items.map { risk -> Double in
            let hasDescription = !risk.desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasValidScale = (1...5).contains(risk.probability) && (1...5).contains(risk.impact)
            if hasDescription && hasValidScale && risk.mitigation?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return 1
            }
            if hasDescription && hasValidScale {
                return 0.8
            }
            return 0.2
        }
        return finalize(
            fieldName: "risks",
            candidate: candidate,
            specificityScore: average(scores),
            validationReport: validationReport
        )
    }

    private func finalize<Value: Codable>(
        fieldName: String,
        candidate: ExtractedFieldCandidate<Value>,
        specificityScore: Double,
        validationReport: ExtractionValidationReport
    ) -> ExtractedFieldCandidate<Value> {
        var updated = candidate
        let fieldResult = validationReport.fieldResults[fieldName]
        let evidenceScore = fieldResult?.userEvidenceFound == true ? 1.0 : 0.0
        let consistencyScore: Double
        if fieldResult?.hasBlockingErrors == true {
            consistencyScore = 0
        } else if fieldResult?.warnings.isEmpty == false {
            consistencyScore = 0.65
        } else {
            consistencyScore = 1
        }
        let modelSelfConfidence = clamp(candidate.confidence)
        var score = 0.45 * evidenceScore
            + 0.25 * clamp(specificityScore)
            + 0.20 * consistencyScore
            + 0.10 * modelSelfConfidence

        if fieldResult?.hasBlockingErrors == true {
            score = min(score, 0.44)
        }

        updated.confidence = clamp(score)
        updated.level = FieldConfidenceLevel.level(for: updated.confidence)
        updated.validationNotes = uniqueNotes(
            updated.validationNotes
                + (fieldResult?.errors ?? [])
                + (fieldResult?.warnings ?? [])
        )
        updated.shouldAutoCommit = updated.level == .confirmed
            && fieldResult?.hasBlockingErrors != true
            && fieldResult?.userEvidenceFound == true
            && fieldResult?.assistantOnlyEvidence != true
        return updated
    }

    // MARK: - Helpers

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func uniqueNotes(_ notes: [String]) -> [String] {
        var seen: Set<String> = []
        return notes.filter { note in
            guard !seen.contains(note) else { return false }
            seen.insert(note)
            return true
        }
    }
}
