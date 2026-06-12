import Foundation
import SwiftData
import Testing
@testable import CoDesign_Agent

struct CoDesignPackageImportTests {
    @Test @MainActor func wrongDocumentTypeIsRejected() throws {
        var package = CoDesignPackageBuilder().build(project: ExportTestFixtures.makeProject())
        package.documentType = "wrong.type"

        do {
            try CoDesignPackageImporter().validateForImport(package)
            Issue.record("Expected invalid package error")
        } catch let error as ReportExportError {
            #expect(error.localizedDescription.contains("documentType"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func unsupportedSchemaShowsReadableError() throws {
        var package = CoDesignPackageBuilder().build(project: ExportTestFixtures.makeProject())
        package.schemaVersion = "9.9"

        do {
            try CoDesignPackageImporter().validateForImport(package)
            Issue.record("Expected unsupported schema error")
        } catch {
            #expect(error.localizedDescription.contains("暂不支持"))
        }
    }

    @Test @MainActor func legalPackageCanCreatePreviewModel() {
        let package = CoDesignPackageBuilder().build(project: ExportTestFixtures.makeProject())

        #expect(package.documentType == "codesign.project")
        #expect(!package.mindTree.nodes.isEmpty)
        #expect(package.display.defaultView == "mindTree")
    }

    @Test @MainActor func importingAsNewProjectDoesNotOverwriteExistingProject() throws {
        let container = try ExportTestFixtures.makeInMemoryContainer()
        let context = container.mainContext
        let existing = ExportTestFixtures.makeProject(insertInto: context)
        let package = CoDesignPackageBuilder().build(project: existing)

        let imported = try CoDesignPackageImporter().importAsNewProject(package: package, context: context)

        #expect(imported.id != existing.id)
        #expect(imported.name.contains("（导入）"))
        #expect(existing.name == "校园导航助手")
    }
}
