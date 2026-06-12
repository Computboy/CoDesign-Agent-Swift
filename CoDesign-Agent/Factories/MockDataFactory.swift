import Foundation
import SwiftData

struct MockDataFactory {
    static let completedDemoProjectName = "已完成测试任务：非遗 AI 短视频"

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

        // 6. 创建模拟 ThinkingMoment（思维树种子节点）
        let rootMoment = ThinkingMoment(
            momType: "seed",
            content: "项目想法诞生",
            stageOrder: 0,
            relatedField: nil
        )
        context.insert(rootMoment)
        project.thinkingMoments.append(rootMoment)

        let s1Branch = ThinkingMoment(
            momType: "branch",
            content: "开始探索痛点与场景",
            stageOrder: 1,
            relatedField: nil,
            parentMomentID: rootMoment.id
        )
        context.insert(s1Branch)
        project.thinkingMoments.append(s1Branch)

        // ── 演示分支编辑：旧版 targetUser（已归档）──
        let oldTargetUser = ThinkingMoment(
            momType: "deepen",
            content: "锚定目标用户: 所有大学生",
            stageOrder: 1,
            relatedField: BriefField.targetUser.rawValue,
            parentMomentID: s1Branch.id,
            timestamp: Date().addingTimeInterval(-600),
            isActiveBranch: false,
            branchVersion: 1,
            archivedAt: Date().addingTimeInterval(-300)
        )
        context.insert(oldTargetUser)
        project.thinkingMoments.append(oldTargetUser)

        // ── 新版 targetUser（活跃分支，基于旧版编辑后创建）──
        let newTargetUser = ThinkingMoment(
            momType: "deepen",
            content: "锚定目标用户: 大一新生",
            stageOrder: 1,
            relatedField: BriefField.targetUser.rawValue,
            parentMomentID: s1Branch.id,
            timestamp: Date().addingTimeInterval(-200),
            isActiveBranch: true,
            branchVersion: 2
        )
        context.insert(newTargetUser)
        project.thinkingMoments.append(newTargetUser)

        let s1OtherFields: [(BriefField, String)] = [
            (.painPoint, "发现核心痛点: 校园导航困难"),
            (.useScenario, "确定使用场景: 开学第一周赶课")
        ]
        for (field, desc) in s1OtherFields {
            let m = ThinkingMoment(
                momType: "deepen",
                content: desc,
                stageOrder: 1,
                relatedField: field.rawValue,
                parentMomentID: s1Branch.id
            )
            context.insert(m)
            project.thinkingMoments.append(m)
        }

        let s2Branch = ThinkingMoment(
            momType: "branch",
            content: "开始提炼差异化价值",
            stageOrder: 2,
            relatedField: nil,
            parentMomentID: rootMoment.id
        )
        context.insert(s2Branch)
        project.thinkingMoments.append(s2Branch)

        let s2Fields: [(BriefField, String)] = [
            (.coreValue, "明确核心价值: AR 室内导航"),
            (.differentiation, "找到差异化点: 专注校园场景")
        ]
        for (field, desc) in s2Fields {
            let m = ThinkingMoment(
                momType: "deepen",
                content: desc,
                stageOrder: 2,
                relatedField: field.rawValue,
                parentMomentID: s2Branch.id
            )
            context.insert(m)
            project.thinkingMoments.append(m)
        }

        let s3Branch = ThinkingMoment(
            momType: "converge",
            content: "收缩项目边界",
            stageOrder: 3,
            relatedField: nil,
            parentMomentID: rootMoment.id
        )
        context.insert(s3Branch)
        project.thinkingMoments.append(s3Branch)

        let s3Field = ThinkingMoment(
            momType: "deepen",
            content: "划定边界: 聚焦核心导航功能",
            stageOrder: 3,
            relatedField: BriefField.boundaryItems.rawValue,
            parentMomentID: s3Branch.id
        )
        context.insert(s3Field)
        project.thinkingMoments.append(s3Field)

        let s4Branch = ThinkingMoment(
            momType: "branch",
            content: "拆解功能与技术方案",
            stageOrder: 4,
            relatedField: nil,
            parentMomentID: rootMoment.id
        )
        context.insert(s4Branch)
        project.thinkingMoments.append(s4Branch)

        let s4Fields: [(BriefField, String)] = [
            (.mvpFeatures, "确定 MVP: AR 导航 + POI 搜索 + 课表"),
            (.technicalModules, "选型技术: ARKit + CoreLocation + SQLite")
        ]
        for (field, desc) in s4Fields {
            let m = ThinkingMoment(
                momType: "deepen",
                content: desc,
                stageOrder: 4,
                relatedField: field.rawValue,
                parentMomentID: s4Branch.id
            )
            context.insert(m)
            project.thinkingMoments.append(m)
        }

        return project
    }

    static func ensureCompletedDemoProject(context: ModelContext) {
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        guard !projects.contains(where: { $0.name == completedDemoProjectName }) else { return }
        _ = createCompletedDemoProject(context: context)
    }

    static func createCompletedDemoProject(context: ModelContext) -> Project {
        let baseDate = Date().addingTimeInterval(-86_400 * 7)
        let project = Project(
            name: completedDemoProjectName,
            briefDescription: "面向大学生的传统文化短视频 AI 共创方案，用于测试完整 Design Brief、思维树和导出报告。",
            createdAt: baseDate,
            updatedAt: Date()
        )
        context.insert(project)

        let brief = DesignBrief(
            targetUser: "18-24 岁大学生，尤其是对传统文化有兴趣但缺少持续接触入口的短视频用户",
            painPoint: "传统文化内容常被学生感知为说教、遥远、记不住，难以在日常短视频语境中形成主动传播",
            useScenario: "课程展示或校园文化活动前，学生需要在 3 周内产出一个可演示的 AI 短视频原型",
            coreValue: "把传统文化知识转译为有情绪记忆点的短视频脚本和分镜，降低创作门槛",
            differentiation: "不是泛泛生成视频，而是围绕文化主题、受众情绪、传播场景和边界取舍生成可解释的创作方案",
            mvpFeatures: "主题输入、受众画像选择、脚本生成、分镜草稿、文化依据卡片、人工确认与导出",
            technicalModules: "LLM 脚本生成、RAG 文化素材检索、分镜结构化输出、人工审核节点、报告导出模块",
            interactionFlow: "用户输入文化主题后，系统追问受众和传播目标，再生成脚本与分镜，最后由用户确认边界和导出简报",
            operationLogic: "AI 只提供创作建议和结构化草稿，关键文化解释、价值判断和最终发布内容由用户确认",
            hardConstraints: "3 周内完成可演示原型；不得生成未经核验的文化事实；不得替代人工审核；优先使用公开可信材料",
            milestones: "第 1 周完成用户场景与内容边界；第 2 周完成脚本/分镜生成原型；第 3 周完成测试、报告和课堂演示"
        )
        context.insert(brief)
        project.brief = brief

        let boundaryItems = [
            BoundaryItem(content: "第一版支持文化主题输入与目标受众选择", isIncluded: true),
            BoundaryItem(content: "第一版生成短视频脚本、分镜草稿和文化依据卡片", isIncluded: true),
            BoundaryItem(content: "第一版保留人工确认，不自动发布内容", isIncluded: true),
            BoundaryItem(content: "暂不做真实视频渲染和复杂剪辑", isIncluded: false),
            BoundaryItem(content: "暂不做社交平台账号运营和推荐算法", isIncluded: false),
        ]
        boundaryItems.forEach {
            context.insert($0)
            brief.boundaryItems.append($0)
        }

        let metrics = [
            SuccessMetric(metric: "脚本可用率", target: "≥ 80%", measurement: "5 名同学试用后认为脚本可继续修改成作品的比例"),
            SuccessMetric(metric: "文化事实错误率", target: "≤ 5%", measurement: "人工抽查生成内容中的事实错误比例"),
            SuccessMetric(metric: "完成时间", target: "≤ 10 分钟", measurement: "从输入主题到导出第一版简报的平均用时"),
        ]
        metrics.forEach {
            context.insert($0)
            brief.successMetrics.append($0)
        }

        let risks = [
            RiskItem(desc: "AI 生成文化事实不准确", probability: 4, impact: 5, mitigation: "输出依据卡片并要求人工确认来源"),
            RiskItem(desc: "生成内容仍然像课堂讲稿，不适合短视频语境", probability: 3, impact: 4, mitigation: "加入情绪目标、冲突点和观看后行动的追问"),
            RiskItem(desc: "用户误以为系统可以直接生成最终视频", probability: 2, impact: 3, mitigation: "在界面和报告中明确 MVP 只覆盖脚本与分镜草稿"),
        ]
        risks.forEach {
            context.insert($0)
            brief.risks.append($0)
        }

        project.stages = StageDefinition.all.map { definition in
            let stage = ProgressStage(
                order: definition.order,
                name: definition.name,
                status: "completed",
                completionRatio: 1,
                lastUpdated: Date()
            )
            context.insert(stage)
            return stage
        }

        let messages: [(String, String)] = [
            ("user", "我想做一个关于提升大学生传统文化传承意识的 AI 视频。"),
            ("assistant", "这个方向里，最需要先确认目标用户和观看场景。你希望影响哪类大学生？"),
            ("user", "18 到 24 岁大学生，他们平时刷短视频，但觉得传统文化内容太说教，看完记不住。"),
            ("assistant", "那核心问题不是传统文化本身，而是表达方式和记忆留存。你希望第一版视频让他们记住什么？"),
            ("user", "希望他们记住一个知识点，也产生一点情绪共鸣，愿意主动分享。"),
            ("assistant", "我们可以把 MVP 边界收紧到脚本、分镜和文化依据，不先做真实视频渲染。"),
            ("user", "可以，三周内完成课堂可演示原型，不做真实发布和社交运营。"),
        ]
        for (index, message) in messages.enumerated() {
            let chat = ChatMessage(
                role: message.0,
                content: message.1,
                timestamp: baseDate.addingTimeInterval(Double(index) * 180)
            )
            context.insert(chat)
            project.messages.append(chat)
        }

        let traces: [(Int, String, String, String)] = [
            (1, "reframe", "你重新定义了问题", "从“提升意识”收窄到“短视频场景下的表达方式和记忆留存”。"),
            (2, "differentiate", "你提炼了差异价值", "方案不只生成内容，而是保留文化依据和人工确认。"),
            (3, "boundaryShrink", "你收缩了项目边界", "第一版只做脚本、分镜和依据卡片，暂不做真实渲染和发布。"),
            (7, "differentiate", "你区分了成功标准", "用脚本可用率、事实错误率和完成时间衡量原型质量。"),
        ]
        traces.forEach { order, type, title, detail in
            let trace = LearningTrace(stageOrder: order, actionType: type, title: title, detail: detail)
            context.insert(trace)
            project.learningTraces.append(trace)
        }

        let root = ThinkingMoment(
            momType: "seed",
            content: "提出非遗 AI 短视频项目",
            stageOrder: 0,
            timestamp: baseDate
        )
        context.insert(root)
        project.thinkingMoments.append(root)

        let stageMoments: [(Int, String, BriefField?)] = [
            (1, "锚定目标用户与痛点：短视频语境下的传统文化记忆留存", .targetUser),
            (2, "提炼差异价值：AI 生成草稿但保留文化依据和人工确认", .coreValue),
            (3, "划定 MVP 边界：只做脚本、分镜和依据卡片", .boundaryItems),
            (4, "拆解功能模块：LLM 生成、RAG 检索、结构化分镜、导出", .technicalModules),
            (5, "定义运行规则：AI 建议，用户确认", .operationLogic),
            (6, "确认硬约束：三周、事实核验、课堂演示", .hardConstraints),
            (7, "制定验收指标：可用率、错误率、完成时间", .successMetrics),
            (8, "识别风险：事实错误、表达说教、能力误解", .risks),
            (9, "拆分里程碑：三周完成原型与报告", .milestones),
        ]
        for (index, item) in stageMoments.enumerated() {
            let branch = ThinkingMoment(
                momType: item.0 == 3 ? "converge" : "decision",
                content: item.1,
                stageOrder: item.0,
                relatedField: item.2?.rawValue,
                parentMomentID: root.id,
                timestamp: baseDate.addingTimeInterval(Double(index + 1) * 240)
            )
            context.insert(branch)
            project.thinkingMoments.append(branch)
        }

        let archived = ThinkingMoment(
            momType: "decision",
            content: "旧方案：直接生成完整视频并自动发布",
            stageOrder: 3,
            relatedField: BriefField.boundaryItems.rawValue,
            parentMomentID: root.id,
            timestamp: baseDate.addingTimeInterval(420),
            isActiveBranch: false,
            branchVersion: 1,
            archivedAt: baseDate.addingTimeInterval(900)
        )
        context.insert(archived)
        project.thinkingMoments.append(archived)

        return project
    }
}
