import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct GeneratedReportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.plainText, .markdownReport, .json, .pdf, .codesignProject]
    }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
