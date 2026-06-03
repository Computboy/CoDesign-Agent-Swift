import Foundation

protocol StructuredExtractorProtocol {
    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractionOutcome
}
