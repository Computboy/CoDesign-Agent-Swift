import Foundation
import Testing
@testable import CoDesign_Agent

struct MarkdownReportRendererTests {
    @Test @MainActor func reportContainsCoreSectionsWhenBriefExists() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .markdown)
        let markdown = MarkdownReportRenderer().render(snapshot: snapshot)

        #expect(markdown.contains("## 1. 项目摘要"))
        #expect(markdown.contains("## 3. Behavior Spec"))
        #expect(markdown.contains("## 4. Reward Function"))
        #expect(markdown.contains("## 6. Intervention Spec"))
        #expect(markdown.contains("外地大一新生"))
    }

    @Test @MainActor func missingFieldsRenderAsPlaceholder() {
        let project = Project(name: "空项目", briefDescription: "")
        let snapshot = ProjectReportSnapshotBuilder().build(
            project: project,
            options: .defaults(for: .markdown)
        )
        let markdown = MarkdownReportRenderer().render(snapshot: snapshot)

        #expect(markdown.contains("待补充"))
    }

    @Test @MainActor func defaultIncludesDecisionTraceButNotFullMindTree() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .markdown)
        let markdown = MarkdownReportRenderer().render(snapshot: snapshot)

        #expect(markdown.contains("## 7. 设计决策路径"))
        #expect(!markdown.contains("## 附录 A：完整思维树"))
    }

    @Test @MainActor func fullMindTreeOptionAddsAppendix() {
        let project = ExportTestFixtures.makeProject()
        var options = ReportExportOptions.defaults(for: .markdown)
        options.includeFullMindTree = true
        options.includeArchivedBranches = true
        let snapshot = ProjectReportSnapshotBuilder().build(project: project, options: options)
        let markdown = MarkdownReportRenderer().render(snapshot: snapshot)

        #expect(markdown.contains("## 附录 A：完整思维树"))
        #expect(markdown.contains("旧方案：面向所有校园访客"))
    }
}
