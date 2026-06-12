import Foundation
import SwiftData
@testable import CoDesign_Agent

enum ExportTestFixtures {
    @MainActor
    static func makeProject(insertInto context: ModelContext? = nil) -> Project {
        let project = Project(
            name: "校园导航助手",
            briefDescription: "帮助外地大一新生减少校园迷路",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_010_000)
        )
        context?.insert(project)

        let brief = DesignBrief(
            targetUser: "外地大一新生",
            painPoint: "开学第一周经常找不到教学楼",
            useScenario: "报到和上课前需要快速确认路线",
            coreValue: "降低迷路和迟到焦虑",
            differentiation: "结合新生任务情境做路线解释",
            mvpFeatures: "路线查询、关键地标提醒",
            technicalModules: "地图检索、路径规划",
            interactionFlow: "输入目的地后获得路线与提醒",
            operationLogic: "根据时间和当前位置给出建议",
            hardConstraints: "不采集精确轨迹历史",
            milestones: "两周内完成可测试原型"
        )
        context?.insert(brief)
        project.brief = brief

        let include = BoundaryItem(content: "做校内教学楼导航", isIncluded: true)
        let exclude = BoundaryItem(content: "不做校外商业导航", isIncluded: false)
        let metric = SuccessMetric(metric: "首次到达成功率", target: "80%", measurement: "任务完成率")
        let risk = RiskItem(desc: "定位漂移导致路线错误", probability: 3, impact: 4, mitigation: "提示用户核对地标")
        context?.insert(include)
        context?.insert(exclude)
        context?.insert(metric)
        context?.insert(risk)
        brief.boundaryItems = [include, exclude]
        brief.successMetrics = [metric]
        brief.risks = [risk]

        project.stages = StageDefinition.all.map { definition in
            let stage = ProgressStage(
                order: definition.order,
                name: definition.name,
                status: definition.order <= 2 ? "completed" : (definition.order == 3 ? "active" : "notStarted"),
                completionRatio: definition.order <= 2 ? 1 : (definition.order == 3 ? 0.4 : 0)
            )
            context?.insert(stage)
            return stage
        }

        let base = Date(timeIntervalSince1970: 1_700_020_000)
        let question = ThinkingMoment(
            momType: "question",
            content: "核心用户是谁？",
            stageOrder: 1,
            timestamp: base
        )
        let decision = ThinkingMoment(
            momType: "decision",
            content: "确认目标用户为外地大一新生",
            stageOrder: 1,
            relatedField: BriefField.targetUser.rawValue,
            parentMomentID: question.id,
            timestamp: base.addingTimeInterval(60)
        )
        let oldDecision = ThinkingMoment(
            momType: "decision",
            content: "旧方案：面向所有校园访客",
            stageOrder: 1,
            relatedField: BriefField.targetUser.rawValue,
            parentMomentID: question.id,
            timestamp: base.addingTimeInterval(30),
            isActiveBranch: false,
            branchVersion: 2,
            archivedAt: base.addingTimeInterval(90)
        )
        context?.insert(question)
        context?.insert(decision)
        context?.insert(oldDecision)
        project.thinkingMoments = [question, oldDecision, decision]

        let trace = LearningTrace(
            stageOrder: 1,
            actionType: "reframe",
            title: "收窄目标用户",
            detail: "从所有访客收窄到外地大一新生",
            timestamp: base.addingTimeInterval(120)
        )
        context?.insert(trace)
        project.learningTraces = [trace]

        return project
    }

    @MainActor
    static func makeSnapshot(format: ReportExportFormat = .markdown) -> ProjectReportSnapshot {
        let project = makeProject()
        let options = ReportExportOptions.defaults(for: format)
        return ProjectReportSnapshotBuilder().build(
            project: project,
            options: options,
            exportedAt: Date(timeIntervalSince1970: 1_700_030_000)
        )
    }

    @MainActor
    static func makeInMemoryContainer() throws -> ModelContainer {
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
