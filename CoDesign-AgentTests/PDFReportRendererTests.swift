import Foundation
import CoreGraphics
import Testing
@testable import CoDesign_Agent

struct PDFReportRendererTests {
    @Test @MainActor func rendererAcceptsMockSnapshot() throws {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        let data = try PDFReportRenderer().render(snapshot: snapshot)
        let prefix = String(decoding: data.prefix(4), as: UTF8.self)
        let provider = CGDataProvider(data: data as CFData)
        let document = provider.flatMap(CGPDFDocument.init)

        #expect(prefix == "%PDF")
        #expect((document?.numberOfPages ?? 0) >= 2)
    }

    @Test func readablePDFErrorExists() {
        let error = ReportExportError.unsupportedPDFPlatform
        #expect(error.localizedDescription.contains("PDF"))
    }

    @Test @MainActor func pdfRendererDoesNotAffectMarkdownOrJSON() throws {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        _ = try PDFReportRenderer().render(snapshot: snapshot)

        let markdown = MarkdownReportRenderer().render(snapshot: snapshot)
        let json = try JSONReportRenderer().render(snapshot: snapshot)

        #expect(markdown.contains("AI 产品设计报告"))
        #expect(!json.isEmpty)
    }
}
