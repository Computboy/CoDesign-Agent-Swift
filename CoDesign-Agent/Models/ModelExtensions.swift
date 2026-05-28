import Foundation
import SwiftData

// MARK: - ChatMessage → ChatPayloadMessage

extension ChatMessage {
    func toPayload() -> ChatPayloadMessage {
        ChatPayloadMessage(role: role, content: content)
    }
}

// MARK: - DesignBrief → DesignBriefSnapshot

extension DesignBrief {
    func toSnapshot() -> DesignBriefSnapshot {
        DesignBriefSnapshot(
            targetUser: targetUser,
            painPoint: painPoint,
            useScenario: useScenario,
            coreValue: coreValue,
            differentiation: differentiation,
            boundaryItems: boundaryItems.map { $0.toDTO() },
            mvpFeatures: mvpFeatures,
            technicalModules: technicalModules,
            interactionFlow: interactionFlow,
            operationLogic: operationLogic,
            hardConstraints: hardConstraints,
            successMetrics: successMetrics.map { $0.toDTO() },
            risks: risks.map { $0.toDTO() },
            milestones: milestones
        )
    }
}

// MARK: - ProgressStage → ProgressStageSnapshot

extension ProgressStage {
    func toSnapshot() -> ProgressStageSnapshot {
        ProgressStageSnapshot(
            order: order,
            name: name,
            status: stageStatusValue,
            completionRatio: completionRatio
        )
    }
}

// MARK: - BoundaryItem → BoundaryItemDTO

extension BoundaryItem {
    func toDTO() -> BoundaryItemDTO {
        BoundaryItemDTO(id: id, content: content, isIncluded: isIncluded)
    }
}

// MARK: - RiskItem → RiskItemDTO

extension RiskItem {
    func toDTO() -> RiskItemDTO {
        RiskItemDTO(
            id: id,
            desc: desc,
            probability: probability,
            impact: impact,
            mitigation: mitigation
        )
    }
}

// MARK: - SuccessMetric → SuccessMetricDTO

extension SuccessMetric {
    func toDTO() -> SuccessMetricDTO {
        SuccessMetricDTO(
            id: id,
            metric: metric,
            target: target,
            measurement: measurement
        )
    }
}

// MARK: - LearningTrace → LearningTraceDTO

extension LearningTrace {
    func toDTO() -> LearningTraceDTO {
        LearningTraceDTO(
            id: id,
            stageOrder: stageOrder,
            actionType: actionType,
            title: title,
            detail: detail,
            timestamp: timestamp
        )
    }
}

// MARK: - ExtractedFields → DesignBrief（增量合并写回）

extension DesignBrief {
    /// 将 ExtractedFields 增量合并到当前 DesignBrief
    /// - 简单 String? 字段：非 nil 才覆盖
    /// - 数组字段（boundaryItems / risks / successMetrics）：非 nil 则替换式更新
    func applyExtracted(_ fields: ExtractedFields, context: ModelContext) {
        // ── 简单字段：非 nil 才覆盖 ──
        if let v = fields.targetUser { targetUser = v }
        if let v = fields.painPoint { painPoint = v }
        if let v = fields.useScenario { useScenario = v }
        if let v = fields.coreValue { coreValue = v }
        if let v = fields.differentiation { differentiation = v }
        if let v = fields.mvpFeatures { mvpFeatures = v }
        if let v = fields.technicalModules { technicalModules = v }
        if let v = fields.interactionFlow { interactionFlow = v }
        if let v = fields.operationLogic { operationLogic = v }
        if let v = fields.hardConstraints { hardConstraints = v }
        if let v = fields.milestones { milestones = v }

        // ── boundaryItems：替换式更新 ──
        if let items = fields.boundaryItems {
            boundaryItems.forEach { context.delete($0) }
            boundaryItems = items.map {
                let bi = BoundaryItem(content: $0.content, isIncluded: $0.isIncluded)
                context.insert(bi)
                return bi
            }
        }

        // ── risks：替换式更新 ──
        if let items = fields.risks {
            risks.forEach { context.delete($0) }
            risks = items.map {
                let ri = RiskItem(
                    desc: $0.desc,
                    probability: $0.probability,
                    impact: $0.impact,
                    mitigation: $0.mitigation
                )
                context.insert(ri)
                return ri
            }
        }

        // ── successMetrics：替换式更新 ──
        if let items = fields.successMetrics {
            successMetrics.forEach { context.delete($0) }
            successMetrics = items.map {
                let sm = SuccessMetric(
                    metric: $0.metric,
                    target: $0.target,
                    measurement: $0.measurement
                )
                context.insert(sm)
                return sm
            }
        }

        // ── 记录提取时间 ──
        lastExtractedAt = Date()
    }
}
