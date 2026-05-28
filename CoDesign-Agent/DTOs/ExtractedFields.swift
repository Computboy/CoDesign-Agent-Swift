import Foundation

struct ExtractedFields: Codable {
    var targetUser: String?
    var painPoint: String?
    var useScenario: String?
    var coreValue: String?
    var differentiation: String?
    var boundaryItems: [BoundaryItemDTO]?
    var mvpFeatures: String?
    var technicalModules: String?
    var interactionFlow: String?
    var hardConstraints: String?
    var operationLogic: String?
    var successMetrics: [SuccessMetricDTO]?
    var risks: [RiskItemDTO]?
    var milestones: String?

    /// 显式 init，所有参数默认为 nil，表示"本轮未提取到"
    init(
        targetUser: String? = nil,
        painPoint: String? = nil,
        useScenario: String? = nil,
        coreValue: String? = nil,
        differentiation: String? = nil,
        boundaryItems: [BoundaryItemDTO]? = nil,
        mvpFeatures: String? = nil,
        technicalModules: String? = nil,
        interactionFlow: String? = nil,
        hardConstraints: String? = nil,
        operationLogic: String? = nil,
        successMetrics: [SuccessMetricDTO]? = nil,
        risks: [RiskItemDTO]? = nil,
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
        self.hardConstraints = hardConstraints
        self.operationLogic = operationLogic
        self.successMetrics = successMetrics
        self.risks = risks
        self.milestones = milestones
    }
}
