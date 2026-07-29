import Foundation

struct CoDesignPackageBuilder {
    private let snapshotBuilder: ProjectReportSnapshotBuilder

    init(snapshotBuilder: ProjectReportSnapshotBuilder = ProjectReportSnapshotBuilder()) {
        self.snapshotBuilder = snapshotBuilder
    }

    @MainActor
    func build(project: Project, exportedAt: Date = Date()) -> CoDesignPackage {
        let options = ReportExportOptions.defaults(for: .codesignPackage)
        let snapshot = snapshotBuilder.build(project: project, options: options, exportedAt: exportedAt)
        return build(
            from: snapshot,
            mindTreeAnnotations: project.mindTreeAnnotations
                .sorted { $0.createdAt < $1.createdAt }
                .map { MindTreeAnnotationSnapshot(annotation: $0) }
        )
    }

    func build(
        from snapshot: ProjectReportSnapshot,
        mindTreeAnnotations: [MindTreeAnnotationSnapshot] = []
    ) -> CoDesignPackage {
        let mindTree = buildMindTree(snapshot: snapshot)
        return CoDesignPackage(
            schemaVersion: "1.2",
            documentType: "codesign.project",
            exportedAt: snapshot.exportedAt,
            appVersion: appVersion,
            sourcePlatform: sourcePlatform,
            project: snapshot.project,
            stages: snapshot.stages,
            brief: snapshot.brief,
            reportSections: snapshot.reportSections,
            mindTree: mindTree,
            decisionTrace: snapshot.processEvidence.decisionTrace.filter(\.isActiveBranch),
            resources: snapshot.processEvidence.resources,
            learningTraces: snapshot.processEvidence.learningTraces,
            mindTreeAnnotations: mindTreeAnnotations,
            display: CoDesignPackageDisplay(
                defaultView: "mindTree",
                expandedStages: Array(1...max(snapshot.project.currentStageOrder, 1)),
                selectedNodeID: nil,
                showArchivedBranches: true
            ),
            exportOptions: snapshot.exportOptions
        )
    }

    private func buildMindTree(snapshot: ProjectReportSnapshot) -> CoDesignMindTreeSnapshot {
        var nodes: [CoDesignMindTreeNode] = []
        var edges: [CoDesignMindTreeEdge] = []

        let rootID = "project-\(snapshot.project.id)"
        nodes.append(
            CoDesignMindTreeNode(
                id: rootID,
                parentID: nil,
                stageOrder: 0,
                stageTitle: "项目主题",
                kind: "root",
                momType: "project",
                content: snapshot.project.name,
                relatedField: nil,
                timestamp: snapshot.project.createdAt,
                isActiveBranch: true,
                branchVersion: 1,
                archivedAt: nil,
                positionHint: nil,
                metadata: ["briefDescription": snapshot.project.briefDescription]
            )
        )

        for stage in snapshot.stages {
            let stageID = stageNodeID(stage.order)
            nodes.append(
                CoDesignMindTreeNode(
                    id: stageID,
                    parentID: stage.order == 1 ? rootID : stageNodeID(stage.order - 1),
                    stageOrder: stage.order,
                    stageTitle: stage.name,
                    kind: "stage",
                    momType: "stage",
                    content: "Stage \(stage.order)",
                    relatedField: nil,
                    timestamp: stage.lastUpdated,
                    isActiveBranch: true,
                    branchVersion: 1,
                    archivedAt: nil,
                    positionHint: nil,
                    metadata: [
                        "status": stage.status,
                        "completionRatio": "\(stage.completionRatio)"
                    ]
                )
            )
            edges.append(
                CoDesignMindTreeEdge(
                    id: "\(stage.order == 1 ? rootID : stageNodeID(stage.order - 1))-\(stageID)",
                    sourceID: stage.order == 1 ? rootID : stageNodeID(stage.order - 1),
                    targetID: stageID,
                    edgeType: "stage",
                    isArchived: false,
                    branchVersion: 1
                )
            )
        }

        let stageIDs = Set(snapshot.stages.map { stageNodeID($0.order) })
        for moment in snapshot.processEvidence.thinkingMoments {
            let nodeID = momentNodeID(moment.id)
            let parentID: String
            if let parentMomentID = moment.parentMomentID {
                parentID = momentNodeID(parentMomentID)
            } else if stageIDs.contains(stageNodeID(moment.stageOrder)) {
                parentID = stageNodeID(moment.stageOrder)
            } else {
                parentID = rootID
            }

            nodes.append(
                CoDesignMindTreeNode(
                    id: nodeID,
                    parentID: parentID,
                    stageOrder: moment.stageOrder,
                    stageTitle: moment.stageTitle,
                    kind: moment.kind,
                    momType: moment.momType,
                    content: moment.content,
                    relatedField: moment.relatedField,
                    timestamp: moment.timestamp,
                    isActiveBranch: moment.isActiveBranch,
                    branchVersion: moment.branchVersion,
                    archivedAt: moment.archivedAt,
                    positionHint: nil,
                    metadata: [:]
                )
            )
            edges.append(
                CoDesignMindTreeEdge(
                    id: "\(parentID)-\(nodeID)",
                    sourceID: parentID,
                    targetID: nodeID,
                    edgeType: moment.isActiveBranch ? "active" : "archived",
                    isArchived: !moment.isActiveBranch,
                    branchVersion: moment.branchVersion
                )
            )
        }

        let branchVersions = Array(Set(snapshot.processEvidence.thinkingMoments.map(\.branchVersion))).sorted()
        let archivedBranches = snapshot.processEvidence.thinkingMoments
            .filter { !$0.isActiveBranch }
            .map {
                CoDesignArchivedBranch(
                    id: "\($0.branchVersion)-\($0.id)",
                    branchVersion: $0.branchVersion,
                    stageOrder: $0.stageOrder,
                    archivedAt: $0.archivedAt,
                    summary: $0.content
                )
            }

        return CoDesignMindTreeSnapshot(
            nodes: nodes,
            edges: edges,
            activeBranchID: "active",
            branchVersions: branchVersions.isEmpty ? [1] : branchVersions,
            archivedBranches: archivedBranches
        )
    }

    private func stageNodeID(_ order: Int) -> String {
        "stage-\(order)"
    }

    private func momentNodeID(_ id: String) -> String {
        "moment-\(id)"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var sourcePlatform: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "Apple"
        #endif
    }
}
