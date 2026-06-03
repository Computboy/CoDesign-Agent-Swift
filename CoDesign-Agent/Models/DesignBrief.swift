import Foundation
import SwiftData

@Model
final class DesignBrief {
    @Attribute(.unique) var id: UUID
    var lastExtractedAt: Date?

    // ── 阶段 1：痛点与场景锚定 ──
    var targetUser: String?
    var painPoint: String?
    var useScenario: String?

    // ── 阶段 2：差异化价值提炼 ──
    var coreValue: String?
    var differentiation: String?

    // ── 阶段 3：项目边界划定（单一 relationship，isIncluded 区分） ──
    @Relationship(deleteRule: .cascade, inverse: \BoundaryItem.brief)
    var boundaryItems: [BoundaryItem]

    // ── 阶段 4：功能与技术方案拆解 ──
    var mvpFeatures: String?
    var technicalModules: String?
    var interactionFlow: String?

    // ── 阶段 5：运行逻辑与规则定义 ──
    var operationLogic: String?

    // ── 阶段 6：硬性约束设计 ──
    var hardConstraints: String?

    // ── 阶段 7：量化验收标准 ──
    @Relationship(deleteRule: .cascade, inverse: \SuccessMetric.brief)
    var successMetrics: [SuccessMetric]

    // ── 阶段 8：风险识别与预案 ──
    @Relationship(deleteRule: .cascade, inverse: \RiskItem.brief)
    var risks: [RiskItem]

    @Relationship(deleteRule: .cascade, inverse: \ExtractionAuditLog.brief)
    var extractionAuditLogs: [ExtractionAuditLog]

    // ── 阶段 9：项目阶段拆分与排期 ──
    var milestones: String?

    var project: Project?         // 反向关系，SwiftData 自动维护

    init(
        id: UUID = UUID(),
        lastExtractedAt: Date? = nil,
        targetUser: String? = nil,
        painPoint: String? = nil,
        useScenario: String? = nil,
        coreValue: String? = nil,
        differentiation: String? = nil,
        boundaryItems: [BoundaryItem] = [],
        mvpFeatures: String? = nil,
        technicalModules: String? = nil,
        interactionFlow: String? = nil,
        operationLogic: String? = nil,
        hardConstraints: String? = nil,
        successMetrics: [SuccessMetric] = [],
        risks: [RiskItem] = [],
        extractionAuditLogs: [ExtractionAuditLog] = [],
        milestones: String? = nil
    ) {
        self.id = id
        self.lastExtractedAt = lastExtractedAt
        self.targetUser = targetUser
        self.painPoint = painPoint
        self.useScenario = useScenario
        self.coreValue = coreValue
        self.differentiation = differentiation
        self.boundaryItems = boundaryItems
        self.mvpFeatures = mvpFeatures
        self.technicalModules = technicalModules
        self.interactionFlow = interactionFlow
        self.operationLogic = operationLogic
        self.hardConstraints = hardConstraints
        self.successMetrics = successMetrics
        self.risks = risks
        self.extractionAuditLogs = extractionAuditLogs
        self.milestones = milestones
    }

    // ── 便捷计算属性 ──
    var includedFeatures: [BoundaryItem] {
        boundaryItems.filter { $0.isIncluded }
    }
    var excludedFeatures: [BoundaryItem] {
        boundaryItems.filter { !$0.isIncluded }
    }
}
