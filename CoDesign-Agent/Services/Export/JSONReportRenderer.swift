import Foundation

struct JSONReportRenderer {
    func render(snapshot: ProjectReportSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(snapshot)
        } catch {
            throw ReportExportError.encodingFailed(error.localizedDescription)
        }
    }
}
