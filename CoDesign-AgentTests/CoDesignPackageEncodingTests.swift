import Foundation
import Testing
@testable import CoDesign_Agent

struct CoDesignPackageEncodingTests {
    @Test @MainActor func packageBuildsFromMockProject() {
        let project = ExportTestFixtures.makeProject()
        let package = CoDesignPackageBuilder().build(project: project)

        #expect(package.schemaVersion == "1.1")
        #expect(package.documentType == "codesign.project")
        #expect(package.project.name == "校园导航助手")
        #expect(!package.mindTree.nodes.isEmpty)
        #expect(!package.decisionTrace.isEmpty)
    }

    @Test @MainActor func packageRoundTripsThroughJSON() throws {
        let package = CoDesignPackageBuilder().build(project: ExportTestFixtures.makeProject())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CoDesignPackage.self, from: data)

        #expect(decoded.project.name == package.project.name)
        #expect(decoded.mindTree.nodes.count == package.mindTree.nodes.count)
    }

    @Test @MainActor func packageDoesNotContainSensitiveKeys() throws {
        let package = CoDesignPackageBuilder().build(project: ExportTestFixtures.makeProject())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)
        let string = String(decoding: data, as: UTF8.self).lowercased()

        #expect(!string.contains("apikey"))
        #expect(!string.contains("baseurl"))
        #expect(!string.contains("systemprompt"))
    }
}
