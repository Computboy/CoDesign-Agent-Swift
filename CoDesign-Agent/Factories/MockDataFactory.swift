import Foundation
import SwiftData

struct MockDataFactory {
    /// 创建一个完整的演示项目，用于展示系统功能和 UI 效果
    static func createDemoProject(context: ModelContext) -> Project {
        // 1. 创建 Project
        let project = Project(
            name: "智能校园导航助手",
            briefDescription: "帮助大学新生在复杂校园中快速找到目的地的智能导航应用"
        )
        context.insert(project)

        // 2. 创建 DesignBrief（部分字段填充）
        let brief = DesignBrief(
            targetUser: "大一新生，尤其是来自外地的学生",
            painPoint: "校园面积大、建筑命名混乱，新生经常找不到教室和办公室",
            useScenario: "开学第一周，新生需要在 10 分钟内从宿舍赶到陌生的教学楼",
            coreValue: "基于 AR 的室内导航，解决 GPS 在建筑内失灵的问题",
            differentiation: "不同于百度/高德地图，专注室内场景 + 校园 POI 数据",
            mvpFeatures: "AR 导航 + POI 搜索 + 课表导入",
            technicalModules: "ARKit + CoreLocation + 本地 SQLite POI 数据库"
        )
        context.insert(brief)
        project.brief = brief

        // 添加 boundaryItems（通过 isIncluded 区分"做"与"不做"）
        let boundaryItems = [
            BoundaryItem(content: "AR 实时导航箭头", isIncluded: true),
            BoundaryItem(content: "校园 POI 搜索", isIncluded: true),
            BoundaryItem(content: "课表导入与自动导航", isIncluded: true),
            BoundaryItem(content: "社交功能（找同学）", isIncluded: false),
            BoundaryItem(content: "外卖配送", isIncluded: false)
        ]
        for item in boundaryItems {
            context.insert(item)
            brief.boundaryItems.append(item)
        }

        // 添加 successMetrics
        let successMetrics = [
            SuccessMetric(metric: "首次导航成功率", target: "≥ 90%"),
            SuccessMetric(metric: "平均找到目的地时间", target: "≤ 5 分钟",
                         measurement: "从发起导航到到达")
        ]
        for metric in successMetrics {
            context.insert(metric)
            brief.successMetrics.append(metric)
        }

        // 添加 risks（注意使用 desc 字段）
        let risks = [
            RiskItem(desc: "AR 在弱光环境下识别不稳定",
                    probability: 4, impact: 4,
                    mitigation: "增加 2D 地图备选方案"),
            RiskItem(desc: "POI 数据采集工作量大",
                    probability: 3, impact: 5,
                    mitigation: "先覆盖主楼，后续众包")
        ]
        for risk in risks {
            context.insert(risk)
            brief.risks.append(risk)
        }

        // 3. 创建 9 个 ProgressStage
        let stages = StageDefinition.all.map { def in
            let stage = ProgressStage(order: def.order, name: def.name)
            context.insert(stage)
            return stage
        }
        project.stages = stages

        // 根据 demo brief 填充情况设置阶段状态
        stages[0].status = "completed"; stages[0].completionRatio = 1.0  // 痛点与场景
        stages[1].status = "completed"; stages[1].completionRatio = 1.0  // 差异化价值
        stages[2].status = "completed"; stages[2].completionRatio = 1.0  // 项目边界
        stages[3].status = "active";    stages[3].completionRatio = 0.67 // 功能与技术
        // stages[4]~[8] 保持 notStarted（默认值）

        // 4. 创建模拟 ChatMessage（8 条交替消息）
        let conversation: [(String, String)] = [
            ("user", "我想做一个帮助大学生在校园里导航的应用"),
            ("assistant", "这个想法很实际！能具体说说，你觉得哪类学生最需要这个？"),
            ("user", "主要是大一新生，尤其是外地来的，对校园完全不熟悉"),
            ("assistant", "你能描述一个具体的场景吗？比如这个新生在什么情况下最着急找不到路？"),
            ("user", "开学第一周，在宿舍出发去一个完全没去过的教学楼上课，快迟到了"),
            ("assistant", "很好的场景描述。那在你想到的领域里，目前有没有类似的产品？"),
            ("user", "高德百度地图都有导航，但在建筑里面 GPS 就失灵了"),
            ("assistant", "你发现了一个关键差异点。那你觉得你的方案和这些地图应用有什么本质区别？")
        ]
        for (i, (role, content)) in conversation.enumerated() {
            let msg = ChatMessage(
                role: role,
                content: content,
                timestamp: Date().addingTimeInterval(Double(i) * 60)
            )
            context.insert(msg)
            project.messages.append(msg)
        }

        // 5. 创建模拟 LearningTrace（3 种核心认知动作）
        let traces: [(Int, String, String, String)] = [
            (1, "converge", "你完成了一次收敛思考",
             "从模糊的「校园应用」收敛到了「导航」这个具体问题"),
            (1, "reframe", "你重新定义了问题",
             "从「校园信息应用」重新定义为「室内导航」问题"),
            (3, "boundaryShrink", "你收缩了项目边界",
             "排除了社交功能和外卖配送，聚焦核心导航需求")
        ]
        for (order, type, title, detail) in traces {
            let trace = LearningTrace(
                stageOrder: order,
                actionType: type,
                title: title,
                detail: detail
            )
            context.insert(trace)
            project.learningTraces.append(trace)
        }

        return project
    }
}
