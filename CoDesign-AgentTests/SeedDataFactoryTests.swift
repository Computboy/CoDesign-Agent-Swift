import Foundation
import SwiftData
import Testing
@testable import CoDesign_Agent

struct SeedDataFactoryTests {
    @Test @MainActor func seedIncludesCompletedExportFixture() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        SeedDataFactory.seedIfNeeded(context: context)

        let projects = try context.fetch(FetchDescriptor<Project>())
        let completed = try #require(projects.first { $0.name == MockDataFactory.completedDemoProjectName })

        #expect(completed.stages.count == StageDefinition.all.count)
        #expect(completed.stages.allSatisfy { $0.status == "completed" && $0.completionRatio == 1 })
        let brief = try #require(completed.brief?.toSnapshot())
        #expect(BriefField.allCases.allSatisfy { $0.isFilled(in: brief) })

        let snapshot = ProjectReportSnapshotBuilder().build(
            project: completed,
            options: .defaults(for: .markdown)
        )
        let markdown = MarkdownReportRenderer().render(snapshot: snapshot)
        #expect(markdown.contains("AI 产品设计报告"))
        #expect(markdown.contains("非遗 AI 短视频"))
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Project.self,
            ChatMessage.self,
            DesignBrief.self,
            ProgressStage.self,
            BoundaryItem.self,
            RiskItem.self,
            SuccessMetric.self,
            LearningTrace.self,
            ThinkingMoment.self,
            ExtractionAuditLog.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
