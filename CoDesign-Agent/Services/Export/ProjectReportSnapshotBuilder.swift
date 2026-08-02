import Foundation

struct ProjectReportSnapshotBuilder {
    private let recommendationService: ResourceRecommendationService

    init(recommendationService: ResourceRecommendationService = ResourceRecommendationService()) {
        self.recommendationService = recommendationService
    }

    @MainActor
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
                    summary: moment.summary,
                    relatedField: moment.relatedField,
                    resourceCardID: moment.resourceCardID,
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
        let semantic = ReportSemanticMapper().map(brief: brief)

        return ReportSectionsSnapshot(
            projectSummary: [
                "目标用户": ReportSnapshotValue.text(brief.targetUser),
                "核心痛点": ReportSnapshotValue.text(brief.painPoint),
                "使用场景": ReportSnapshotValue.text(brief.useScenario),
                "核心价值": ReportSnapshotValue.text(brief.coreValue),
                "差异化价值": ReportSnapshotValue.text(brief.differentiation),
                "当前阶段 / 完成状态": "\(currentStageName) / \(Int(project.completionRate * 100))%"
            ],
            aiValueHypothesis: [:],
            behaviorSpec: semantic.availableBehaviorSpec,
            rewardFunction: [:],
            failureRecovery: [:],
            interventionSpec: [:]
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
