import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CoDesignPackageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.codesignProject] }

    var package: CoDesignPackage

    init(package: CoDesignPackage) {
        self.package = package
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw ReportExportError.decodingFailed("文件没有可读取的内容。")
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            package = try decoder.decode(CoDesignPackage.self, from: data)
        } catch {
            throw ReportExportError.decodingFailed(error.localizedDescription)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(package)
            return FileWrapper(regularFileWithContents: data)
        } catch {
            throw ReportExportError.encodingFailed(error.localizedDescription)
        }
    }
}
