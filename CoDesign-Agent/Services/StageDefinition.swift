import Foundation

// MARK: - BriefField

/// DesignBrief 中可独立判断"是否已填充"的字段
enum BriefField: String, CaseIterable {
    // 阶段 1：痛点与场景锚定
    case targetUser
    case painPoint
    case useScenario

    // 阶段 2：差异化价值提炼
    case coreValue
    case differentiation

    // 阶段 3：项目边界划定
    case boundaryItems

    // 阶段 4：功能与技术方案拆解
    case mvpFeatures
    case technicalModules
    case interactionFlow

    // 阶段 5：运行逻辑与规则定义
    case operationLogic

    // 阶段 6：硬性约束设计
    case hardConstraints

    // 阶段 7：量化验收标准制定
    case successMetrics

    // 阶段 8：风险识别与预案制定
    case risks

    // 阶段 9：项目阶段拆分与排期
    case milestones

    /// 字段的中文显示名称
    var displayName: String {
        switch self {
        case .targetUser: return "目标用户"
        case .painPoint: return "核心痛点"
        case .useScenario: return "使用场景"
        case .coreValue: return "核心价值"
        case .differentiation: return "差异化"
        case .boundaryItems: return "项目边界"
        case .mvpFeatures: return "MVP 功能"
        case .technicalModules: return "技术模块"
        case .interactionFlow: return "交互流程"
        case .operationLogic: return "运行逻辑"
        case .hardConstraints: return "硬性约束"
        case .successMetrics: return "验收标准"
        case .risks: return "风险预案"
        case .milestones: return "里程碑"
        }
    }

    /// SF Symbol used when a field is shown in compact status lists.
    var systemImage: String {
        switch self {
        case .targetUser: return "person.crop.circle"
        case .painPoint: return "scope"
        case .useScenario: return "rectangle.on.rectangle.angled"
        case .coreValue: return "diamond"
        case .differentiation: return "square.grid.2x2"
        case .boundaryItems: return "rectangle.dashed"
        case .mvpFeatures: return "shippingbox"
        case .technicalModules: return "square.stack.3d.up"
        case .interactionFlow: return "point.bottomleft.forward.to.point.topright.scurvepath"
        case .operationLogic: return "slider.horizontal.3"
        case .hardConstraints: return "lock.shield"
        case .successMetrics: return "checklist"
        case .risks: return "exclamationmark.triangle"
        case .milestones: return "calendar"
        }
    }

    var stageOrder: Int {
        switch self {
        case .targetUser, .painPoint, .useScenario:
            return 1
        case .coreValue, .differentiation:
            return 2
        case .boundaryItems:
            return 3
        case .mvpFeatures, .technicalModules, .interactionFlow:
            return 4
        case .operationLogic:
            return 5
        case .hardConstraints:
            return 6
        case .successMetrics:
            return 7
        case .risks:
            return 8
        case .milestones:
            return 9
        }
    }

    /// 判断该字段在 snapshot 中是否已填充
    func isFilled(in snapshot: DesignBriefSnapshot) -> Bool {
        switch self {
        case .targetUser:
            return snapshot.targetUser?.isEmpty == false
        case .painPoint:
            return snapshot.painPoint?.isEmpty == false
        case .useScenario:
            return snapshot.useScenario?.isEmpty == false
        case .coreValue:
            return snapshot.coreValue?.isEmpty == false
        case .differentiation:
            return snapshot.differentiation?.isEmpty == false
        case .boundaryItems:
            return BoundaryItemHeuristics.completionRatio(for: snapshot.boundaryItems) >= 1
        case .mvpFeatures:
            return snapshot.mvpFeatures?.isEmpty == false
        case .technicalModules:
            return snapshot.technicalModules?.isEmpty == false
        case .interactionFlow:
            return snapshot.interactionFlow?.isEmpty == false
        case .operationLogic:
            return snapshot.operationLogic?.isEmpty == false
        case .hardConstraints:
            return snapshot.hardConstraints?.isEmpty == false
        case .successMetrics:
            return !snapshot.successMetrics.isEmpty
        case .risks:
            return !snapshot.risks.isEmpty
        case .milestones:
            return snapshot.milestones?.isEmpty == false
        }
    }
}

// MARK: - StageDefinition

struct StageDefinition {
    let order: Int
    let name: String
    let briefFields: [BriefField]
    let description: String

    /// 该阶段的完成度 = 已填充字段数 / 总字段数
    func completionRatio(from snapshot: DesignBriefSnapshot) -> Double {
        guard !briefFields.isEmpty else { return 0 }
        if briefFields == [.boundaryItems] {
            return BoundaryItemHeuristics.completionRatio(for: snapshot.boundaryItems)
        }
        let filled = briefFields.filter { $0.isFilled(in: snapshot) }.count
        return Double(filled) / Double(briefFields.count)
    }

    var iconName: String {
        switch order {
        case 1: return "scope"
        case 2: return "sparkles"
        case 3: return "rectangle.dashed"
        case 4: return "square.stack.3d.up"
        case 5: return "slider.horizontal.3"
        case 6: return "lock.shield"
        case 7: return "checklist"
        case 8: return "exclamationmark.triangle"
        case 9: return "calendar"
        default: return "circle.grid.3x3"
        }
    }

    var shortSubtitle: String {
        switch order {
        case 1: return "痛点与场景"
        case 2: return "价值与差异化"
        case 3: return "项目边界"
        case 4: return "功能与模块"
        case 5: return "规则与运行"
        case 6: return "硬性约束"
        case 7: return "验收标准"
        case 8: return "风险与预案"
        case 9: return "里程碑与排期"
        default: return "设计澄清"
        }
    }

    var compactPurpose: String {
        switch order {
        case 1:
            return "明确你的设计对象是谁、他们面临什么问题、在什么场景发生。"
        case 2:
            return "将价值主张具体化，并与现有方案区分开来。"
        case 3:
            return "明确第一版做什么、不做什么，划定项目边界。"
        case 4:
            return "将想法拆解为用户可见的功能、模块和交互流程。"
        case 5:
            return "定义保持体验可预测的运行规则。"
        case 6:
            return "明确设计不可突破的限制条件。"
        case 7:
            return "将成功转化为可见、可量化的验收标准。"
        case 8:
            return "提前暴露风险并准备应对方案。"
        case 9:
            return "将已澄清的简报转化为阶段和下一步行动。"
        default:
            return description
        }
    }

    var recommendedCardIDs: [String] {
        switch order {
        case 1:
            return [
                "method-persona",
                "method-empathy-map",
                "method-user-journey-map",
                "method-five-whys",
                "method-problem-statement",
                "method-how-might-we",
            ]
        case 2:
            return [
                "method-jobs-to-be-done",
                "method-insight-statement",
                "method-how-might-we",
                "method-assumption-mapping",
                "method-concept-testing",
            ]
        case 3:
            return [
                "method-mvp",
                "method-impact-effort-matrix",
                "method-assumption-mapping",
                "method-decision-log",
            ]
        case 4:
            return [
                "method-prototype",
                "method-user-journey-map",
                "method-service-blueprint",
                "method-crazy-8s",
                "method-design-critique",
            ]
        case 5:
            return [
                "method-service-blueprint",
                "method-decision-log",
                "method-assumption-mapping",
                "method-pre-mortem",
            ]
        case 6:
            return [
                "method-assumption-mapping",
                "method-impact-effort-matrix",
                "method-mvp",
                "method-pre-mortem",
            ]
        case 7:
            return [
                "method-experiment-plan",
                "method-usability-testing",
                "method-mvp",
                "method-concept-testing",
            ]
        case 8:
            return [
                "method-pre-mortem",
                "method-assumption-mapping",
                "method-five-whys",
                "method-decision-log",
            ]
        case 9:
            return [
                "method-decision-log",
                "method-reflection",
                "method-retrospective",
                "method-mvp",
                "method-impact-effort-matrix",
            ]
        default:
            return []
        }
    }

    /// 该阶段的思考问题
    var thinkingQuestions: [String] {
        switch order {
        case 1:
            return [
                "谁是你的目标用户？",
                "他们在什么场景下遇到问题？",
                "问题的具体表现是什么？"
            ]
        case 2:
            return [
                "你的方案与现有方案有何不同？",
                "用户为什么选择你的方案？",
                "核心价值主张是什么？"
            ]
        case 3:
            return [
                "MVP 包含哪些核心功能？",
                "哪些功能被排除在外？",
                "项目边界如何划定？"
            ]
        case 4:
            return [
                "用户如何与系统交互？",
                "需要哪些技术模块？",
                "交互流程是否清晰？"
            ]
        case 5:
            return [
                "可能面临哪些风险？",
                "风险发生的概率有多大？",
                "如何应对这些风险？"
            ]
        case 6:
            return [
                "如何衡量项目成功？",
                "有哪些可量化的指标？",
                "评估标准是什么？"
            ]
        case 7:
            return [
                "需要展示什么原型？",
                "哪些视觉证据能说服评审？",
                "如何呈现设计过程？"
            ]
        case 8:
            return [
                "技术实现有哪些约束？",
                "时间和资源如何分配？",
                "实现路径是否可行？"
            ]
        case 9:
            return [
                "最终方案如何总结？",
                "学到了什么？",
                "下一步如何迭代？"
            ]
        default:
            return ["请思考这个阶段的核心问题和关键决策。"]
        }
    }

    // MARK: - 9 阶段静态定义

    static let all: [StageDefinition] = [
        StageDefinition(
            order: 1,
            name: "痛点与场景锚定",
            briefFields: [.targetUser, .painPoint, .useScenario],
            description: "明确目标用户是谁，他们遇到什么具体问题，在什么场景下发生"
        ),
        StageDefinition(
            order: 2,
            name: "差异化价值提炼",
            briefFields: [.coreValue, .differentiation],
            description: "提炼核心价值主张，明确与已有方案的差异"
        ),
        StageDefinition(
            order: 3,
            name: "项目边界划定",
            briefFields: [.boundaryItems],
            description: "明确 MVP 做什么、不做什么，划定项目边界"
        ),
        StageDefinition(
            order: 4,
            name: "功能与技术方案拆解",
            briefFields: [.mvpFeatures, .technicalModules, .interactionFlow],
            description: "拆解核心功能模块、技术选型和交互流程"
        ),
        StageDefinition(
            order: 5,
            name: "运行逻辑与规则定义",
            briefFields: [.operationLogic],
            description: "定义系统运行逻辑、异常处理和规则约束"
        ),
        StageDefinition(
            order: 6,
            name: "硬性约束设计",
            briefFields: [.hardConstraints],
            description: "明确预算、时间、硬件等不可突破的约束"
        ),
        StageDefinition(
            order: 7,
            name: "量化验收标准制定",
            briefFields: [.successMetrics],
            description: "制定可量化的验收指标和目标值"
        ),
        StageDefinition(
            order: 8,
            name: "风险识别与预案制定",
            briefFields: [.risks],
            description: "识别主要风险，制定缓解预案"
        ),
        StageDefinition(
            order: 9,
            name: "项目阶段拆分与排期",
            briefFields: [.milestones],
            description: "拆分开发阶段，制定里程碑与排期"
        ),
    ]
}
