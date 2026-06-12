import Foundation

struct ProjectReportSnapshotBuilder {
    private let recommendationService: ResourceRecommendationService

    init(recommendationService: ResourceRecommendationService = ResourceRecommendationService()) {
        self.recommendationService = recommendationService
    }

    func build(
        project: Project,
        options: ReportExportOptions,
        exportedAt: Date = Date()
    ) -> ProjectReportSnapshot {
        let brief = options.includeDesignBrief ? (project.brief?.toSnapshot() ?? DesignBriefSnapshot()) : DesignBriefSnapshot()
        let stages = project.stages
            .sorted { $0.order < $1.order }
            .map {
                StageExportSnapshot(
                    id: $0.id.uuidString,
                    order: $0.order,
                    name: $0.name,
                    status: $0.status,
                    completionRatio: $0.completionRatio,
                    lastUpdated: $0.lastUpdated
                )
            }
        let currentStageOrder = project.currentStageOrder
        let currentStageName = stages.first { $0.order == currentStageOrder }?.name
            ?? ReportSnapshotValue.stageTitle(currentStageOrder)
        let resources = options.includeResources
            ? recommendationService
                .recommend(
                    currentStageOrder: currentStageOrder,
                    brief: project.brief,
                    recentMessage: project.latestConversationText,
                    limit: 8,
                    mode: .normal
                )
                .map(ResourceCardSnapshot.init(resource:))
            : []

        let thinkingMoments = includedThinkingMoments(project: project, options: options)
        let decisionTrace = options.includeDecisionTrace
            ? buildDecisionTrace(project: project, includeArchivedBranches: options.includeArchivedBranches)
            : []
        let learningTraces = project.learningTraces
            .sorted { $0.timestamp < $1.timestamp }
            .map {
                LearningTraceSnapshot(
                    id: $0.id.uuidString,
                    stageOrder: $0.stageOrder,
                    stageTitle: ReportSnapshotValue.stageTitle($0.stageOrder),
                    actionType: $0.actionType,
                    title: $0.title,
                    detail: $0.detail,
                    timestamp: $0.timestamp
                )
            }

        return ProjectReportSnapshot(
            schemaVersion: "1.0",
            documentType: "codesign.reportData",
            exportedAt: exportedAt,
            project: ProjectInfoSnapshot(
                id: project.id.uuidString,
                name: project.name,
                briefDescription: project.briefDescription,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt,
                completionRate: project.completionRate,
                currentStageOrder: currentStageOrder,
                currentStageName: currentStageName
            ),
            stages: stages,
            brief: brief,
            reportSections: options.includeReportSections
                ? buildReportSections(brief: brief, project: project, currentStageName: currentStageName)
                : emptyReportSections(),
            processEvidence: ProcessEvidenceSnapshot(
                decisionTrace: decisionTrace,
                thinkingMoments: thinkingMoments,
                learningTraces: learningTraces,
                resources: resources,
                conversationSummary: options.includeConversationSummary
                    ? conversationSummary(for: project)
                    : nil
            ),
            exportOptions: options
        )
    }

    private func includedThinkingMoments(
        project: Project,
        options: ReportExportOptions
    ) -> [ThinkingMomentSnapshot] {
        guard options.includeFullMindTree else { return [] }
        return project.thinkingMoments
            .filter { options.includeArchivedBranches || $0.isActiveBranch }
            .sorted { lhs, rhs in
                if lhs.stageOrder == rhs.stageOrder {
                    return lhs.timestamp < rhs.timestamp
                }
                return lhs.stageOrder < rhs.stageOrder
            }
            .map { moment in
                ThinkingMomentSnapshot(
                    id: moment.id.uuidString,
                    parentMomentID: moment.parentMomentID?.uuidString,
                    stageOrder: moment.stageOrder,
                    stageTitle: ReportSnapshotValue.stageTitle(moment.stageOrder),
                    momType: moment.momType,
                    kind: ReportSnapshotValue.momentTypeTitle(moment.momType),
                    content: moment.content,
                    relatedField: moment.relatedField,
                    timestamp: moment.timestamp,
                    isActiveBranch: moment.isActiveBranch,
                    branchVersion: moment.branchVersion,
                    archivedAt: moment.archivedAt
                )
            }
    }

    private func buildDecisionTrace(
        project: Project,
        includeArchivedBranches: Bool
    ) -> [DecisionTraceItem] {
        let moments = project.thinkingMoments
            .filter { includeArchivedBranches || $0.isActiveBranch }
            .sorted { lhs, rhs in
                if lhs.stageOrder == rhs.stageOrder {
                    return lhs.timestamp < rhs.timestamp
                }
                return lhs.stageOrder < rhs.stageOrder
            }
            .map { moment in
                DecisionTraceItem(
                    id: "moment-\(moment.id.uuidString)",
                    stageOrder: moment.stageOrder,
                    stageTitle: ReportSnapshotValue.stageTitle(moment.stageOrder),
                    type: ReportSnapshotValue.momentTypeTitle(moment.momType),
                    title: ReportSnapshotValue.momentTypeTitle(moment.momType),
                    content: moment.content,
                    relatedField: moment.relatedField,
                    timestamp: moment.timestamp,
                    sourceID: moment.id.uuidString,
                    isActiveBranch: moment.isActiveBranch,
                    branchVersion: moment.branchVersion
                )
            }

        let traces = project.learningTraces.map { trace in
            DecisionTraceItem(
                id: "trace-\(trace.id.uuidString)",
                stageOrder: trace.stageOrder,
                stageTitle: ReportSnapshotValue.stageTitle(trace.stageOrder),
                type: "学习轨迹",
                title: trace.title,
                content: trace.detail,
                relatedField: nil,
                timestamp: trace.timestamp,
                sourceID: trace.id.uuidString,
                isActiveBranch: true,
                branchVersion: 1
            )
        }

        return (moments + traces).sorted { lhs, rhs in
            if lhs.stageOrder == rhs.stageOrder {
                return lhs.timestamp < rhs.timestamp
            }
            return lhs.stageOrder < rhs.stageOrder
        }
    }

    private func buildReportSections(
        brief: DesignBriefSnapshot,
        project: Project,
        currentStageName: String
    ) -> ReportSectionsSnapshot {
        let included = brief.boundaryItems.filter(\.isIncluded).map(\.content).joined(separator: "；")
        let excluded = brief.boundaryItems.filter { !$0.isIncluded }.map(\.content).joined(separator: "；")
        let coreComplete = [
            brief.targetUser,
            brief.painPoint,
            brief.useScenario,
            brief.coreValue
        ].allSatisfy { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !trimmed.isEmpty
        }

        return ReportSectionsSnapshot(
            projectSummary: [
                "目标用户": ReportSnapshotValue.text(brief.targetUser),
                "核心痛点": ReportSnapshotValue.text(brief.painPoint),
                "使用场景": ReportSnapshotValue.text(brief.useScenario),
                "核心价值": ReportSnapshotValue.text(brief.coreValue),
                "差异化价值": ReportSnapshotValue.text(brief.differentiation),
                "当前阶段 / 完成状态": "\(currentStageName) / \(Int(project.completionRate * 100))%"
            ],
            aiValueHypothesis: [
                "价值假设": "我们认为 AI 能帮助解决「\(ReportSnapshotValue.text(brief.painPoint)) / \(ReportSnapshotValue.text(brief.useScenario))」，因为「\(ReportSnapshotValue.text(brief.coreValue)) / \(ReportSnapshotValue.text(brief.differentiation))」。",
                "自动化 / 增强判断": ReportSnapshotValue.missing,
                "AI 不适合做的事": excluded.isEmpty ? ReportSnapshotValue.missing : excluded,
                "Go / No-go 结论": coreComplete ? "Go，待人工确认" : "需要补充"
            ],
            behaviorSpec: [
                "UNDERSTAND": [
                    "输入维度": ReportSnapshotValue.text(brief.useScenario),
                    "输出维度": ReportSnapshotValue.text(brief.coreValue ?? brief.mvpFeatures),
                    "时机维度": ReportSnapshotValue.text(brief.interactionFlow ?? brief.operationLogic),
                    "Bloom 层级": ReportSnapshotValue.missing
                ],
                "CAPABILITY": [
                    "推理模式": ReportSnapshotValue.text(brief.technicalModules ?? brief.operationLogic),
                    "输出模态": ReportSnapshotValue.text(brief.mvpFeatures ?? brief.interactionFlow),
                    "语言层": ReportSnapshotValue.missing,
                    "反馈回路": ReportSnapshotValue.text(brief.interactionFlow ?? brief.operationLogic)
                ],
                "BOUNDARY": [
                    "做的清单": included.isEmpty ? ReportSnapshotValue.missing : included,
                    "不做的清单": excluded.isEmpty ? ReportSnapshotValue.missing : excluded,
                    "审批链": ReportSnapshotValue.text(brief.hardConstraints),
                    "责任归属": ReportSnapshotValue.text(brief.hardConstraints),
                    "降级剧本入口": brief.risks.map(\.desc).joined(separator: "；").nilIfEmpty ?? ReportSnapshotValue.missing
                ]
            ],
            rewardFunction: [
                "指标数量": brief.successMetrics.isEmpty ? "0" : "\(brief.successMetrics.count)",
                "Goodhart 自查": ReportSnapshotValue.missing,
                "Action Plan": "如果 ______ 跌破 ______，我们将 ______。\n如果 ______ 超过 ______，我们将 ______。\n如果 ______ 跌破 ______，我们将 ______。"
            ],
            failureRecovery: [
                "风险来源": brief.risks.isEmpty ? ReportSnapshotValue.missing : brief.risks.map(\.desc).joined(separator: "；"),
                "硬性约束": ReportSnapshotValue.text(brief.hardConstraints),
                "排除边界": excluded.isEmpty ? ReportSnapshotValue.missing : excluded
            ],
            interventionSpec: [
                "时机": ReportSnapshotValue.text(brief.interactionFlow ?? brief.operationLogic),
                "强度": ReportSnapshotValue.missing,
                "可见": ReportSnapshotValue.missing,
                "干预": ReportSnapshotValue.missing,
                "实际场景验证": [brief.useScenario, brief.hardConstraints].compactMap { $0 }.joined(separator: "；").nilIfEmpty ?? ReportSnapshotValue.missing,
                "失败恢复": brief.risks.compactMap(\.mitigation).joined(separator: "；").nilIfEmpty ?? ReportSnapshotValue.missing,
                "关系识别": ReportSnapshotValue.missing,
                "层级定位": ReportSnapshotValue.missing
            ]
        )
    }

    private func emptyReportSections() -> ReportSectionsSnapshot {
        ReportSectionsSnapshot(
            projectSummary: [:],
            aiValueHypothesis: [:],
            behaviorSpec: [:],
            rewardFunction: [:],
            failureRecovery: [:],
            interventionSpec: [:]
        )
    }

    private func conversationSummary(for project: Project) -> String {
        let userCount = project.messages.filter { $0.role == "user" }.count
        let assistantCount = project.messages.filter { $0.role == "assistant" }.count
        return "本项目共记录 \(userCount) 条用户输入与 \(assistantCount) 条 AI 回复。原始聊天记录未被导出。"
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
