import Foundation

final class LiveStructuredExtractor: StructuredExtractorProtocol {
    private let apiClient = LLMAPIClient()
    private let validator = ExtractionSchemaValidator()
    private let scorer = ExtractionConfidenceScorer()

    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractionOutcome {
        do {
            let rawJSON = try await apiClient.completeJSON(
                messages: buildMessages(messages: messages, existing: existing)
            )

            let decodedEnvelope: ExtractionEnvelope
            let decodedAttemptCount: Int
            do {
                decodedEnvelope = try decodeEnvelope(rawJSON)
                decodedAttemptCount = 1
            } catch {
                let repairedJSON = try await apiClient.completeJSON(
                    messages: buildRepairMessages(rawJSON: rawJSON, error: error)
                )
                do {
                    decodedEnvelope = try decodeEnvelope(repairedJSON)
                    decodedAttemptCount = 2
                } catch {
                    return ExtractionOutcome.failed(
                        source: .live,
                        message: "JSON repair failed: \(error)",
                        attemptCount: 2
                    )
                }
            }

            let evaluated = evaluate(decodedEnvelope, messages: messages)
            if evaluated.report.hasErrors {
                return await repairValidationFailures(
                    envelope: evaluated.envelope,
                    report: evaluated.report,
                    messages: messages,
                    existing: existing,
                    previousAttemptCount: decodedAttemptCount
                )
            }

            return ExtractionOutcome(
                source: .live,
                status: .succeeded,
                envelope: evaluated.envelope,
                validationReport: evaluated.report,
                attemptCount: decodedAttemptCount
            )
        } catch {
            print("[LiveStructuredExtractor] Live extraction failed without fallback: \(error)")
            return ExtractionOutcome.failed(
                source: .live,
                message: "Live extraction failed: \(error)",
                attemptCount: 1
            )
        }
    }

    // MARK: - Private

    private func buildMessages(
        messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) -> [ChatCompletionMessage] {
        [
            ChatCompletionMessage(
                role: "system",
                content: ExtractionPromptTemplates.systemPrompt()
            ),
            ChatCompletionMessage(
                role: "user",
                content: ExtractionPromptTemplates.userPrompt(
                    messages: messages,
                    existing: existing
                )
            ),
        ]
    }

    private func buildRepairMessages(
        rawJSON: String,
        error: Error
    ) -> [ChatCompletionMessage] {
        [
            ChatCompletionMessage(
                role: "system",
                content: "You repair JSON for a Swift JSONDecoder. Output only a JSON object."
            ),
            ChatCompletionMessage(
                role: "user",
                content: ExtractionPromptTemplates.repairPrompt(
                    rawJSON: rawJSON,
                    errorDescription: String(describing: error)
                )
            ),
        ]
    }

    private func buildValidationRepairMessages(
        messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?,
        invalidFieldNames: [String],
        validationErrors: [String],
        previousEnvelopeJSON: String
    ) -> [ChatCompletionMessage] {
        [
            ChatCompletionMessage(
                role: "system",
                content: ExtractionPromptTemplates.systemPrompt()
            ),
            ChatCompletionMessage(
                role: "user",
                content: ExtractionPromptTemplates.validationRepairPrompt(
                    messages: messages,
                    existing: existing,
                    invalidFieldNames: invalidFieldNames,
                    validationErrors: validationErrors,
                    previousEnvelopeJSON: previousEnvelopeJSON
                )
            ),
        ]
    }

    private func decodeEnvelope(_ raw: String) throws -> ExtractionEnvelope {
        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw APIError.decodingFailed
        }
        return try JSONDecoder().decode(ExtractionEnvelope.self, from: data)
    }

    private func evaluate(
        _ envelope: ExtractionEnvelope,
        messages: [ChatPayloadMessage]
    ) -> (envelope: ExtractionEnvelope, report: ExtractionValidationReport) {
        let report = validator.validate(envelope: envelope, messages: messages)
        let scored = scorer.score(envelope: envelope, validationReport: report)
        return (scored, report)
    }

    private func repairValidationFailures(
        envelope: ExtractionEnvelope,
        report: ExtractionValidationReport,
        messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?,
        previousAttemptCount: Int
    ) async -> ExtractionOutcome {
        let attemptCount = max(3, previousAttemptCount + 1)
        let previousJSON = encodeEnvelopeForPrompt(envelope)
        let repairedJSON: String
        do {
            repairedJSON = try await apiClient.completeJSON(
                messages: buildValidationRepairMessages(
                    messages: messages,
                    existing: existing,
                    invalidFieldNames: report.invalidFieldNames,
                    validationErrors: report.allErrors,
                    previousEnvelopeJSON: previousJSON
                )
            )
        } catch {
            return ExtractionOutcome.failed(
                source: .live,
                message: "Validation repair request failed: \(error)",
                envelope: envelope,
                validationReport: report,
                attemptCount: attemptCount
            )
        }

        let repairedEnvelope: ExtractionEnvelope
        do {
            repairedEnvelope = try decodeEnvelope(repairedJSON)
        } catch {
            return ExtractionOutcome.failed(
                source: .live,
                message: "Validation repair returned invalid JSON: \(error)",
                envelope: envelope,
                validationReport: report,
                attemptCount: attemptCount
            )
        }

        let evaluated = evaluate(repairedEnvelope, messages: messages)
        if evaluated.report.hasErrors && !evaluated.envelope.hasReliableCandidate {
            return ExtractionOutcome.failed(
                source: .live,
                message: "No reliable fields after validation repair.",
                envelope: evaluated.envelope,
                validationReport: evaluated.report,
                attemptCount: attemptCount
            )
        }

        return ExtractionOutcome(
            source: .live,
            status: .succeeded,
            envelope: evaluated.envelope,
            validationReport: evaluated.report,
            attemptCount: attemptCount
        )
    }

    private func encodeEnvelopeForPrompt(_ envelope: ExtractionEnvelope) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(envelope),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    /// 去除模型可能返回的 ```json / ``` 包裹和首尾空白
    private func cleanJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 去除开头 ```json 或 ```
        if s.hasPrefix("```json") {
            s = String(s.dropFirst(7))
        } else if s.hasPrefix("```") {
            s = String(s.dropFirst(3))
        }

        // 去除结尾 ```
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
