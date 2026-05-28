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
            return !snapshot.boundaryItems.isEmpty
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
        let filled = briefFields.filter { $0.isFilled(in: snapshot) }.count
        return Double(filled) / Double(briefFields.count)
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
