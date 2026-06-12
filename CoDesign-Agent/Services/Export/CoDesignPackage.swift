import Foundation

struct CoDesignPackage: Codable, Identifiable {
    var schemaVersion: String
    var documentType: String
    var exportedAt: Date
    var appVersion: String
    var sourcePlatform: String
    var project: ProjectInfoSnapshot
    var stages: [StageExportSnapshot]
    var brief: DesignBriefSnapshot
    var reportSections: ReportSectionsSnapshot
    var mindTree: CoDesignMindTreeSnapshot
    var decisionTrace: [DecisionTraceItem]
    var resources: [ResourceCardSnapshot]
    var learningTraces: [LearningTraceSnapshot]
    var display: CoDesignPackageDisplay
    var exportOptions: ReportExportOptions

    var id: String { "\(project.id)-\(exportedAt.timeIntervalSince1970)" }

    static var empty: CoDesignPackage {
        CoDesignPackage(
            schemaVersion: "1.0",
            documentType: "codesign.project",
            exportedAt: Date(),
            appVersion: "1.0",
            sourcePlatform: "unknown",
            project: ProjectInfoSnapshot(
                id: UUID().uuidString,
                name: "CoDesign 项目",
                briefDescription: "",
                createdAt: Date(),
                updatedAt: Date(),
                completionRate: 0,
                currentStageOrder: 1,
                currentStageName: "痛点与场景锚定"
            ),
            stages: [],
            brief: DesignBriefSnapshot(),
            reportSections: ReportSectionsSnapshot(
                projectSummary: [:],
                aiValueHypothesis: [:],
                behaviorSpec: [:],
                rewardFunction: [:],
                failureRecovery: [:],
                interventionSpec: [:]
            ),
            mindTree: CoDesignMindTreeSnapshot(
                nodes: [],
                edges: [],
                activeBranchID: "",
                branchVersions: [],
                archivedBranches: []
            ),
            decisionTrace: [],
            resources: [],
            learningTraces: [],
            display: CoDesignPackageDisplay(),
            exportOptions: .defaults(for: .codesignPackage)
        )
    }
}

struct CoDesignMindTreeSnapshot: Codable {
    var nodes: [CoDesignMindTreeNode]
    var edges: [CoDesignMindTreeEdge]
    var activeBranchID: String
    var branchVersions: [Int]
    var archivedBranches: [CoDesignArchivedBranch]
}

struct CoDesignMindTreeNode: Codable, Identifiable {
    var id: String
    var parentID: String?
    var stageOrder: Int
    var stageTitle: String
    var kind: String
    var momType: String
    var content: String
    var relatedField: String?
    var timestamp: Date?
    var isActiveBranch: Bool
    var branchVersion: Int
    var archivedAt: Date?
    var positionHint: CoDesignPositionHint?
    var metadata: [String: String]

    var isArchived: Bool { !isActiveBranch || archivedAt != nil }
}

struct CoDesignMindTreeEdge: Codable, Identifiable {
    var id: String
    var sourceID: String
    var targetID: String
    var edgeType: String
    var isArchived: Bool
    var branchVersion: Int
}

struct CoDesignArchivedBranch: Codable, Identifiable {
    var id: String
    var branchVersion: Int
    var stageOrder: Int
    var archivedAt: Date?
    var summary: String
}

struct CoDesignPositionHint: Codable {
    var x: Double
    var y: Double
}

struct CoDesignPackageDisplay: Codable {
    var defaultView: String = "mindTree"
    var expandedStages: [Int] = Array(1...9)
    var selectedNodeID: String?
    var showArchivedBranches: Bool = true
}
