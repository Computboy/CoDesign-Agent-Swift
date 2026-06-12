import Foundation
import Testing
@testable import CoDesign_Agent

struct JSONReportRendererTests {
    @Test @MainActor func jsonContainsStableTopLevelKeys() throws {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .json)
        let data = try JSONReportRenderer().render(snapshot: snapshot)
        let string = String(decoding: data, as: UTF8.self)

        #expect(string.contains("\"schemaVersion\""))
        #expect(string.contains("\"project\""))
        #expect(string.contains("\"brief\""))
        #expect(string.contains("\"reportSections\""))
        #expect(string.contains("\"processEvidence\""))
    }

    @Test @MainActor func thinkingMomentsKeepBranchMetadata() throws {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .json)
        let data = try JSONReportRenderer().render(snapshot: snapshot)
        let string = String(decoding: data, as: UTF8.self)

        #expect(string.contains("\"isActiveBranch\""))
        #expect(string.contains("\"branchVersion\""))
        #expect(string.contains("\"archivedAt\""))
    }

    @Test @MainActor func decisionTraceRespectsArchivedBranchOption() {
        let project = ExportTestFixtures.makeProject()

        var activeOnly = ReportExportOptions.defaults(for: .markdown)
        activeOnly.includeArchivedBranches = false
        let activeSnapshot = ProjectReportSnapshotBuilder().build(project: project, options: activeOnly)
        #expect(!activeSnapshot.processEvidence.decisionTrace.contains { !$0.isActiveBranch })

        var withArchived = ReportExportOptions.defaults(for: .json)
        withArchived.includeArchivedBranches = true
        let archivedSnapshot = ProjectReportSnapshotBuilder().build(project: project, options: withArchived)
        #expect(archivedSnapshot.processEvidence.decisionTrace.contains { !$0.isActiveBranch })
    }

    @Test @MainActor func jsonDoesNotContainSensitiveKeys() throws {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .json)
        let data = try JSONReportRenderer().render(snapshot: snapshot)
        let string = String(decoding: data, as: UTF8.self).lowercased()

        #expect(!string.contains("apikey"))
        #expect(!string.contains("baseurl"))
        #expect(!string.contains("systemprompt"))
        #expect(!string.contains("authorization"))
    }
}
