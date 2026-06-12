import Foundation
import Testing
@testable import CoDesign_Agent

struct CoDesignPackageBuilderTests {
    @Test @MainActor func packageDefaultsIncludeFullMindTreeAndArchivedBranches() {
        let package = CoDesignPackageBuilder().build(project: ExportTestFixtures.makeProject())

        #expect(package.exportOptions.includeFullMindTree)
        #expect(package.exportOptions.includeArchivedBranches)
        #expect(package.mindTree.nodes.contains { $0.isArchived })
    }

    @Test @MainActor func decisionTraceOnlyContainsActiveBranchByDefault() {
        let package = CoDesignPackageBuilder().build(project: ExportTestFixtures.makeProject())

        #expect(!package.decisionTrace.contains { !$0.isActiveBranch })
    }

    @Test @MainActor func resourcesMayBeEmptyButFieldExists() throws {
        let package = CoDesignPackageBuilder().build(project: Project(name: "空项目", briefDescription: ""))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)
        let string = String(decoding: data, as: UTF8.self)

        #expect(string.contains("\"resources\""))
    }

    @Test @MainActor func missingFieldsDoNotCrashBuilder() {
        let package = CoDesignPackageBuilder().build(project: Project(name: "空项目", briefDescription: ""))

        #expect(package.project.name == "空项目")
        #expect(package.brief.targetUser == nil)
    }
}
