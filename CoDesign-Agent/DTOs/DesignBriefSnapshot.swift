import Foundation

struct DesignBriefSnapshot: Codable {
    var targetUser: String?
    var painPoint: String?
    var useScenario: String?
    var coreValue: String?
    var differentiation: String?
    var boundaryItems: [BoundaryItemDTO]
    var mvpFeatures: String?
    var technicalModules: String?
    var interactionFlow: String?
    var operationLogic: String?
    var hardConstraints: String?
    var successMetrics: [SuccessMetricDTO]
    var risks: [RiskItemDTO]
    var milestones: String?

    /// 显式 init，所有参数有默认值，支持 `DesignBriefSnapshot()` 空快照
    init(
        targetUser: String? = nil,
        painPoint: String? = nil,
        useScenario: String? = nil,
        coreValue: String? = nil,
        differentiation: String? = nil,
        boundaryItems: [BoundaryItemDTO] = [],
        mvpFeatures: String? = nil,
        technicalModules: String? = nil,
        interactionFlow: String? = nil,
        operationLogic: String? = nil,
        hardConstraints: String? = nil,
        successMetrics: [SuccessMetricDTO] = [],
        risks: [RiskItemDTO] = [],
        milestones: String? = nil
    ) {
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
        self.milestones = milestones
    }
}
