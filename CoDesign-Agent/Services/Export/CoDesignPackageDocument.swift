import Foundation

enum CoDesignPackageDataCodec {
    static func decode(_ data: Data) throws -> CoDesignPackage {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CoDesignPackage.self, from: data)
        } catch {
            throw ReportExportError.decodingFailed(error.localizedDescription)
        }
    }

    static func encode(_ package: CoDesignPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(package)
        } catch {
            throw ReportExportError.encodingFailed(error.localizedDescription)
        }
    }
}
