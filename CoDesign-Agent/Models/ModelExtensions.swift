import Foundation
import SwiftData

// MARK: - ChatMessage → ChatPayloadMessage

extension ChatMessage {
    func toPayload() -> ChatPayloadMessage {
        ChatPayloadMessage(role: role, content: content)
    }
}

// MARK: - DesignBrief → DesignBriefSnapshot

extension DesignBrief {
    func toSnapshot() -> DesignBriefSnapshot {
        DesignBriefSnapshot(
            targetUser: targetUser,
            painPoint: painPoint,
            useScenario: useScenario,
            coreValue: coreValue,
            differentiation: differentiation,
            boundaryItems: boundaryItems.map { $0.toDTO() },
            mvpFeatures: mvpFeatures,
            technicalModules: technicalModules,
            interactionFlow: interactionFlow,
            operationLogic: operationLogic,
            hardConstraints: hardConstraints,
            successMetrics: successMetrics.map { $0.toDTO() },
            risks: risks.map { $0.toDTO() },
            milestones: milestones
        )
    }
}

// MARK: - ProgressStage → ProgressStageSnapshot

extension ProgressStage {
    func toSnapshot() -> ProgressStageSnapshot {
        ProgressStageSnapshot(
            order: order,
            name: name,
            status: stageStatusValue,
            completionRatio: completionRatio
        )
    }
}

// MARK: - BoundaryItem → BoundaryItemDTO

extension BoundaryItem {
    func toDTO() -> BoundaryItemDTO {
        BoundaryItemDTO(id: id, content: content, isIncluded: isIncluded)
    }
}

// MARK: - RiskItem → RiskItemDTO

extension RiskItem {
    func toDTO() -> RiskItemDTO {
        RiskItemDTO(
            id: id,
            desc: desc,
            probability: probability,
            impact: impact,
            mitigation: mitigation
        )
    }
}

// MARK: - SuccessMetric → SuccessMetricDTO

extension SuccessMetric {
    func toDTO() -> SuccessMetricDTO {
        SuccessMetricDTO(
            id: id,
            metric: metric,
            target: target,
            measurement: measurement
        )
    }
}

// MARK: - LearningTrace → LearningTraceDTO

extension LearningTrace {
    func toDTO() -> LearningTraceDTO {
        LearningTraceDTO(
            id: id,
            stageOrder: stageOrder,
            actionType: actionType,
            title: title,
            detail: detail,
            timestamp: timestamp
        )
    }
}

// MARK: - Extraction outcome → DesignBrief（可靠性分流写回）

extension DesignBrief {
    /// Legacy entry point kept for older call sites. It no longer directly overwrites fields.
    func applyExtracted(_ fields: ExtractedFields, context: ModelContext) {
        let outcome = ExtractionOutcome(
            source: .mock,
            status: .succeeded,
            envelope: ExtractionEnvelope(
                targetUser: legacyCandidate(fields.targetUser),
                painPoint: legacyCandidate(fields.painPoint),
                useScenario: legacyCandidate(fields.useScenario),
                coreValue: legacyCandidate(fields.coreValue),
                differentiation: legacyCandidate(fields.differentiation),
                boundaryItems: legacyCandidate(fields.boundaryItems),
                mvpFeatures: legacyCandidate(fields.mvpFeatures),
                technicalModules: legacyCandidate(fields.technicalModules),
                interactionFlow: legacyCandidate(fields.interactionFlow),
                operationLogic: legacyCandidate(fields.operationLogic),
                hardConstraints: legacyCandidate(fields.hardConstraints),
                successMetrics: legacyCandidate(fields.successMetrics),
                risks: legacyCandidate(fields.risks),
                milestones: legacyCandidate(fields.milestones)
            )
        )
        applyValidatedExtraction(outcome: outcome, context: context)
    }

    func applyValidatedExtraction(
        outcome: ExtractionOutcome,
        context: ModelContext,
        currentStageOrder: Int? = nil
    ) {
        guard !outcome.isFailed, let envelope = outcome.envelope else {
            recordAudit(
                fieldName: "extraction",
                oldValue: nil,
                candidateValue: outcome.failureMessage ?? "Extraction failed.",
                confidence: 0,
                level: .rejected,
            evidenceQuote: nil,
            decision: .rejected,
            validationNotes: outcome.validationReport?.allErrors ?? [],
            context: context
        )
            lastExtractedAt = Date()
            return
        }

        processCandidate("targetUser", envelope.targetUser, oldValue: targetUser, currentStageOrder: currentStageOrder, context: context) { targetUser = $0 }
        processCandidate("painPoint", envelope.painPoint, oldValue: painPoint, currentStageOrder: currentStageOrder, context: context) { painPoint = $0 }
        processCandidate("useScenario", envelope.useScenario, oldValue: useScenario, currentStageOrder: currentStageOrder, context: context) { useScenario = $0 }
        processCandidate("coreValue", envelope.coreValue, oldValue: coreValue, currentStageOrder: currentStageOrder, context: context) { coreValue = $0 }
        processCandidate("differentiation", envelope.differentiation, oldValue: differentiation, currentStageOrder: currentStageOrder, context: context) { differentiation = $0 }
        processCandidate("mvpFeatures", envelope.mvpFeatures, oldValue: mvpFeatures, currentStageOrder: currentStageOrder, context: context) { mvpFeatures = $0 }
        processCandidate("technicalModules", envelope.technicalModules, oldValue: technicalModules, currentStageOrder: currentStageOrder, context: context) { technicalModules = $0 }
        processCandidate("interactionFlow", envelope.interactionFlow, oldValue: interactionFlow, currentStageOrder: currentStageOrder, context: context) { interactionFlow = $0 }
        processCandidate("operationLogic", envelope.operationLogic, oldValue: operationLogic, currentStageOrder: currentStageOrder, context: context) { operationLogic = $0 }
        processCandidate("hardConstraints", envelope.hardConstraints, oldValue: hardConstraints, currentStageOrder: currentStageOrder, context: context) { hardConstraints = $0 }
        processCandidate("milestones", envelope.milestones, oldValue: milestones, currentStageOrder: currentStageOrder, context: context) { milestones = $0 }

        processCandidate(
            "boundaryItems",
            envelope.boundaryItems,
            oldValue: boundaryItemsText,
            candidateValueFormatter: formatBoundaryItems,
            currentStageOrder: currentStageOrder,
            context: context
        ) { mergeBoundaryItems($0, context: context) }

        processCandidate(
            "successMetrics",
            envelope.successMetrics,
            oldValue: successMetricsText,
            candidateValueFormatter: formatSuccessMetrics,
            currentStageOrder: currentStageOrder,
            context: context
        ) { mergeSuccessMetrics($0, context: context) }

        processCandidate(
            "risks",
            envelope.risks,
            oldValue: risksText,
            candidateValueFormatter: formatRisks,
            currentStageOrder: currentStageOrder,
            context: context
        ) { mergeRisks($0, context: context) }

        lastExtractedAt = Date()
    }

    func pendingExtractionReviewLogs() -> [ExtractionAuditLog] {
        extractionAuditLogs
            .filter { $0.decisionValue == .needsReview }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func deferredExtractionLogs(forStageOrder stageOrder: Int) -> [ExtractionAuditLog] {
        latestStageExtractionLogs(
            forStageOrder: stageOrder,
            decisions: [.deferredUntilStage]
        )
    }

    func awaitingConfirmationLogs(forStageOrder stageOrder: Int) -> [ExtractionAuditLog] {
        latestStageExtractionLogs(
            forStageOrder: stageOrder,
            decisions: [.awaitingConfirmation]
        )
    }

    func beginConfirmation(for logs: [ExtractionAuditLog]) {
        let now = Date()
        let selectedIDs = Set(logs.map(\.id))
        let selectedFields = Set(logs.map(\.fieldName))

        for log in extractionAuditLogs where
            log.decisionValue == .deferredUntilStage
                && selectedFields.contains(log.fieldName)
                && !selectedIDs.contains(log.id) {
            log.decision = ExtractionAuditDecision.superseded.rawValue
            log.timestamp = now
        }

        for log in logs {
            log.decision = ExtractionAuditDecision.awaitingConfirmation.rawValue
            log.timestamp = now
        }
    }

    func supersedeConfirmationLogs(_ logs: [ExtractionAuditLog]) {
        let now = Date()
        for log in logs {
            log.decision = ExtractionAuditDecision.superseded.rawValue
            log.timestamp = now
        }
    }

    func supersedeConfirmedAwaitingLogs(
        forStageOrder stageOrder: Int,
        snapshot: DesignBriefSnapshot
    ) {
        let confirmedFields = Set(
            StageDefinition.all
                .first(where: { $0.order == stageOrder })?
                .briefFields
                .filter { $0.isFilled(in: snapshot) }
                .map(\.rawValue) ?? []
        )
        guard !confirmedFields.isEmpty else { return }

        let matchingLogs = awaitingConfirmationLogs(forStageOrder: stageOrder)
            .filter { confirmedFields.contains($0.fieldName) }
        supersedeConfirmationLogs(matchingLogs)
    }

    func latestReliabilityLog(for field: BriefField) -> ExtractionAuditLog? {
        extractionAuditLogs
            .filter {
                $0.fieldName == field.rawValue
                    && [.autoCommitted, .userAccepted, .userEdited].contains($0.decisionValue)
            }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }

    func latestExtractionFailureLog() -> ExtractionAuditLog? {
        let latestFailure = extractionAuditLogs
            .filter { $0.fieldName == "extraction" && $0.decisionValue == .rejected }
            .sorted { $0.timestamp > $1.timestamp }
            .first
        let latestFieldDecision = extractionAuditLogs
            .filter { $0.fieldName != "extraction" }
            .sorted { $0.timestamp > $1.timestamp }
            .first
        guard let latestFailure else { return nil }
        if let latestFieldDecision, latestFieldDecision.timestamp > latestFailure.timestamp {
            return nil
        }
        return latestFailure
    }

    func acceptPendingExtraction(_ log: ExtractionAuditLog, context: ModelContext) {
        commitReviewValue(log.candidateValue ?? "", fieldName: log.fieldName, context: context)
        log.decision = ExtractionAuditDecision.userAccepted.rawValue
        log.timestamp = Date()
        lastExtractedAt = Date()
    }

    func editPendingExtraction(_ log: ExtractionAuditLog, editedValue: String, context: ModelContext) {
        let trimmed = editedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        commitReviewValue(trimmed, fieldName: log.fieldName, context: context)
        log.candidateValue = trimmed
        log.decision = ExtractionAuditDecision.userEdited.rawValue
        log.timestamp = Date()
        lastExtractedAt = Date()
    }

    func ignorePendingExtraction(_ log: ExtractionAuditLog) {
        log.decision = ExtractionAuditDecision.userIgnored.rawValue
        log.timestamp = Date()
    }

    // MARK: - Candidate routing

    private func processCandidate<Value: Codable>(
        _ fieldName: String,
        _ candidate: ExtractedFieldCandidate<Value>?,
        oldValue: String?,
        candidateValueFormatter: (Value) -> String,
        currentStageOrder: Int?,
        context: ModelContext,
        commit: (Value) -> Void
    ) {
        guard let candidate, let value = candidate.value else { return }
        let candidateValue = candidateValueFormatter(value)
        let decision: ExtractionAuditDecision
        let candidateStageOrder = BriefField(rawValue: fieldName)?.stageOrder
        let belongsToFutureStage = currentStageOrder.map { currentStageOrder in
            guard let candidateStageOrder else { return false }
            return candidateStageOrder > currentStageOrder
        } ?? false
        let requiresDeferredConfirmation = currentStageOrder.map { currentStageOrder in
            guard candidateStageOrder == currentStageOrder else { return false }
            return extractionAuditLogs.contains {
                $0.fieldName == fieldName
                    && [
                        ExtractionAuditDecision.deferredUntilStage,
                        .awaitingConfirmation,
                    ].contains($0.decisionValue)
            }
        } ?? false

        if (belongsToFutureStage || requiresDeferredConfirmation)
            && candidate.level != .rejected {
            decision = .deferredUntilStage
        } else if candidate.level == .confirmed && candidate.shouldAutoCommit {
            commit(value)
            decision = .autoCommitted
        } else if candidate.level == .needsReview || candidate.level == .confirmed {
            decision = .needsReview
        } else {
            decision = .rejected
        }

        recordAudit(
            fieldName: fieldName,
            oldValue: oldValue,
            candidateValue: candidateValue,
            confidence: candidate.confidence,
            level: candidate.level,
            evidenceQuote: candidate.evidence.first?.quote,
            decision: decision,
            validationNotes: candidate.validationNotes,
            context: context
        )
    }

    private func processCandidate(
        _ fieldName: String,
        _ candidate: ExtractedFieldCandidate<String>?,
        oldValue: String?,
        currentStageOrder: Int?,
        context: ModelContext,
        commit: (String) -> Void
    ) {
        processCandidate(
            fieldName,
            candidate,
            oldValue: oldValue,
            candidateValueFormatter: { $0 },
            currentStageOrder: currentStageOrder,
            context: context,
            commit: commit
        )
    }

    private func latestStageExtractionLogs(
        forStageOrder stageOrder: Int,
        decisions: [ExtractionAuditDecision]
    ) -> [ExtractionAuditLog] {
        let stageFields = StageDefinition.all
            .first(where: { $0.order == stageOrder })?
            .briefFields ?? []

        return stageFields.compactMap { field in
            extractionAuditLogs
                .filter {
                    $0.fieldName == field.rawValue
                        && decisions.contains($0.decisionValue)
                }
                .max(by: { $0.timestamp < $1.timestamp })
        }
    }

    private func recordAudit(
        fieldName: String,
        oldValue: String?,
        candidateValue: String?,
        confidence: Double,
        level: FieldConfidenceLevel,
        evidenceQuote: String?,
        decision: ExtractionAuditDecision,
        validationNotes: [String],
        context: ModelContext
    ) {
        let log = ExtractionAuditLog(
            fieldName: fieldName,
            oldValue: oldValue,
            candidateValue: candidateValue,
            confidence: confidence,
            level: level,
            evidenceQuote: evidenceQuote,
            decision: decision,
            validationNotes: validationNotes
        )
        context.insert(log)
        extractionAuditLogs.append(log)
    }

    // MARK: - Merge strategies

    private func mergeBoundaryItems(_ items: [BoundaryItemDTO], context: ModelContext) {
        var existingKeys = Set(boundaryItems.map { normalizedKey($0.content) })
        for item in items {
            let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            let key = normalizedKey(content)
            guard !existingKeys.contains(key) else { continue }
            let model = BoundaryItem(content: content, isIncluded: item.isIncluded)
            context.insert(model)
            boundaryItems.append(model)
            existingKeys.insert(key)
        }
    }

    private func mergeSuccessMetrics(_ items: [SuccessMetricDTO], context: ModelContext) {
        var existingKeys = Set(successMetrics.map { normalizedKey("\($0.metric)|\($0.target)") })
        for item in items {
            let metric = item.metric.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = item.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !metric.isEmpty, !target.isEmpty else { continue }
            let key = normalizedKey("\(metric)|\(target)")
            guard !existingKeys.contains(key) else { continue }
            let model = SuccessMetric(metric: metric, target: target, measurement: item.measurement)
            context.insert(model)
            successMetrics.append(model)
            existingKeys.insert(key)
        }
    }

    private func mergeRisks(_ items: [RiskItemDTO], context: ModelContext) {
        var existingKeys = Set(risks.map { normalizedKey($0.desc) })
        for item in items {
            let desc = item.desc.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !desc.isEmpty else { continue }
            let key = normalizedKey(desc)
            guard !existingKeys.contains(key) else { continue }
            let model = RiskItem(
                desc: desc,
                probability: item.probability,
                impact: item.impact,
                mitigation: item.mitigation
            )
            context.insert(model)
            risks.append(model)
            existingKeys.insert(key)
        }
    }

    // MARK: - Review commit helpers

    private func commitReviewValue(_ value: String, fieldName: String, context: ModelContext) {
        switch fieldName {
        case "targetUser": targetUser = value
        case "painPoint": painPoint = value
        case "useScenario": useScenario = value
        case "coreValue": coreValue = value
        case "differentiation": differentiation = value
        case "mvpFeatures": mvpFeatures = value
        case "technicalModules": technicalModules = value
        case "interactionFlow": interactionFlow = value
        case "operationLogic": operationLogic = value
        case "hardConstraints": hardConstraints = value
        case "milestones": milestones = value
        case "boundaryItems":
            mergeBoundaryItems(parseBoundaryItems(value), context: context)
        case "successMetrics":
            mergeSuccessMetrics(parseSuccessMetrics(value), context: context)
        case "risks":
            mergeRisks(parseRisks(value), context: context)
        default:
            break
        }
    }

    private func parseBoundaryItems(_ text: String) -> [BoundaryItemDTO] {
        text.split(separator: "\n").map { line in
            let raw = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            let isIncluded = !raw.hasPrefix("[不做]")
            let content = raw
                .replacingOccurrences(of: "[做]", with: "")
                .replacingOccurrences(of: "[不做]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return BoundaryItemDTO(content: content, isIncluded: isIncluded)
        }
    }

    private func parseSuccessMetrics(_ text: String) -> [SuccessMetricDTO] {
        text.split(separator: "\n").map { line in
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                return SuccessMetricDTO(metric: parts[0].trimmed, target: parts[1].trimmed)
            }
            return SuccessMetricDTO(metric: String(line).trimmed, target: "待确认")
        }
    }

    private func parseRisks(_ text: String) -> [RiskItemDTO] {
        text.split(separator: "\n").map {
            RiskItemDTO(desc: String($0).trimmed, probability: 3, impact: 3, mitigation: nil)
        }
    }

    // MARK: - Formatting

    private var boundaryItemsText: String? {
        guard !boundaryItems.isEmpty else { return nil }
        return formatBoundaryItems(boundaryItems.map { $0.toDTO() })
    }

    private var successMetricsText: String? {
        guard !successMetrics.isEmpty else { return nil }
        return formatSuccessMetrics(successMetrics.map { $0.toDTO() })
    }

    private var risksText: String? {
        guard !risks.isEmpty else { return nil }
        return formatRisks(risks.map { $0.toDTO() })
    }

    private func formatBoundaryItems(_ items: [BoundaryItemDTO]) -> String {
        items.map { "\($0.isIncluded ? "[做]" : "[不做]") \($0.content)" }
            .joined(separator: "\n")
    }

    private func formatSuccessMetrics(_ items: [SuccessMetricDTO]) -> String {
        items.map { "\($0.metric): \($0.target)" }
            .joined(separator: "\n")
    }

    private func formatRisks(_ items: [RiskItemDTO]) -> String {
        items.map { "\($0.desc)（概率 \($0.probability)/5，影响 \($0.impact)/5）" }
            .joined(separator: "\n")
    }

    private func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func legacyCandidate<Value: Codable>(_ value: Value?) -> ExtractedFieldCandidate<Value>? {
        guard let value else { return nil }
        return ExtractedFieldCandidate(
            value: value,
            confidence: 0.4,
            level: .needsReview,
            validationNotes: ["legacy ExtractedFields path; requires user review"],
            shouldAutoCommit: false
        )
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
