import Foundation

struct ProgressAnalyzer {

    // MARK: - analyze

    /// 根据 DesignBriefSnapshot 字段填充情况，计算各阶段新状态
    func analyze(
        brief: DesignBriefSnapshot,
        stages: [ProgressStageSnapshot]
    ) -> [ProgressStageSnapshot] {
        stages.map { stage in
            guard let def = StageDefinition.all.first(where: { $0.order == stage.order })
            else { return stage }

            let ratio = def.completionRatio(from: brief)
            var newStatus = stage.status

            switch ratio {
            case 0:
                // 全空：如果原状态是 notStarted 则保持，否则降回 active
                newStatus = (stage.status == .notStarted) ? .notStarted : .active
            case 1.0:
                // 全满：除非是 needsReview，否则标记 completed
                if stage.status != .needsReview { newStatus = .completed }
            default:
                // 部分填充：active
                newStatus = .active
            }

            return ProgressStageSnapshot(
                order: stage.order,
                name: stage.name,
                status: newStatus,
                completionRatio: ratio
            )
        }
    }

    // MARK: - missingFields

    /// 返回当前最靠前的未完成阶段中，所有未填字段的中文名称
    func missingFields(brief: DesignBriefSnapshot) -> [String] {
        for def in StageDefinition.all {
            let unfilled = def.briefFields.filter { !$0.isFilled(in: brief) }
            if !unfilled.isEmpty {
                return unfilled.map { field in
                    switch field {
                    case .targetUser:       return "目标用户画像"
                    case .painPoint:        return "核心痛点描述"
                    case .useScenario:      return "真实使用场景"
                    case .coreValue:        return "核心价值主张"
                    case .differentiation:  return "差异化分析"
                    case .boundaryItems:    return "项目边界（做什么/不做什么）"
                    case .mvpFeatures:      return "MVP 功能列表"
                    case .technicalModules: return "技术模块拆解"
                    case .interactionFlow:  return "交互流程"
                    case .operationLogic:   return "运行逻辑"
                    case .hardConstraints:  return "硬性约束"
                    case .successMetrics:   return "量化验收标准"
                    case .risks:            return "风险与预案"
                    case .milestones:       return "里程碑排期"
                    }
                }
            }
        }
        return []
    }

    // MARK: - detectLearningTraces

    /// v0.1：检测 3 种核心认知动作（reframe / converge / boundaryShrink）
    func detectLearningTraces(
        previousBrief: DesignBriefSnapshot,
        currentBrief: DesignBriefSnapshot,
        activeStageOrder: Int
    ) -> [LearningTraceDTO] {
        var traces: [LearningTraceDTO] = []

        // ── reframe：用户修改了痛点或目标用户（且新值非空） ──
        let targetChanged = previousBrief.targetUser != currentBrief.targetUser
            && currentBrief.targetUser != nil
        let painChanged = previousBrief.painPoint != currentBrief.painPoint
            && currentBrief.painPoint != nil
        if targetChanged || painChanged {
            traces.append(LearningTraceDTO(
                stageOrder: activeStageOrder,
                actionType: "reframe",
                title: "你重新定义了问题",
                detail: "你修正了对目标用户或痛点的理解——这是设计思维中最关键的认知动作。好的设计往往从重新定义问题开始。"
            ))
        }

        // ── converge：某阶段从未填充变为有填充（首次收敛） ──
        for def in StageDefinition.all {
            let prevRatio = def.completionRatio(from: previousBrief)
            let currRatio = def.completionRatio(from: currentBrief)
            if prevRatio == 0 && currRatio > 0 {
                traces.append(LearningTraceDTO(
                    stageOrder: def.order,
                    actionType: "converge",
                    title: "你完成了一次收敛思考",
                    detail: "在「\(def.name)」阶段，你从模糊的想法收敛到了具体的描述。这就是设计思维中的「收敛」——把发散的信息聚焦为明确的判断。"
                ))
            }
        }

        // ── boundaryShrink：新增排除项 ──
        let prevExcluded = previousBrief.boundaryItems.filter { !$0.isIncluded }.count
        let currExcluded = currentBrief.boundaryItems.filter { !$0.isIncluded }.count
        if currExcluded > prevExcluded {
            traces.append(LearningTraceDTO(
                stageOrder: activeStageOrder,
                actionType: "boundaryShrink",
                title: "你收缩了项目边界",
                detail: "你主动说了「不做什么」——这比说「做什么」更需要判断力。边界收缩是项目从空想走向落地的关键一步。"
            ))
        }

        return traces
    }
}
