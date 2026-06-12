import Foundation

struct ProjectReportSnapshot: Codable {
    var schemaVersion: String
    var documentType: String
    var exportedAt: Date
    var project: ProjectInfoSnapshot
    var stages: [StageExportSnapshot]
    var brief: DesignBriefSnapshot
    var reportSections: ReportSectionsSnapshot
    var processEvidence: ProcessEvidenceSnapshot
    var exportOptions: ReportExportOptions
}

struct ProjectInfoSnapshot: Codable {
    var id: String
    var name: String
    var briefDescription: String
    var createdAt: Date
    var updatedAt: Date
    var completionRate: Double
    var currentStageOrder: Int
    var currentStageName: String
}

struct StageExportSnapshot: Codable, Identifiable {
    var id: String
    var order: Int
    var name: String
    var status: String
    var completionRatio: Double
    var lastUpdated: Date?
}

struct ReportSectionsSnapshot: Codable {
    var projectSummary: [String: String]
    var aiValueHypothesis: [String: String]
    var behaviorSpec: [String: [String: String]]
    var rewardFunction: [String: String]
    var failureRecovery: [String: String]
    var interventionSpec: [String: String]
}

struct ProcessEvidenceSnapshot: Codable {
    var decisionTrace: [DecisionTraceItem]
    var thinkingMoments: [ThinkingMomentSnapshot]
    var learningTraces: [LearningTraceSnapshot]
    var resources: [ResourceCardSnapshot]
    var conversationSummary: String?
}

struct DecisionTraceItem: Codable, Identifiable {
    var id: String
    var stageOrder: Int
    var stageTitle: String
    var type: String
    var title: String
    var content: String
    var relatedField: String?
    var timestamp: Date
    var sourceID: String
    var isActiveBranch: Bool
    var branchVersion: Int
}

struct ThinkingMomentSnapshot: Codable, Identifiable {
    var id: String
    var parentMomentID: String?
    var stageOrder: Int
    var stageTitle: String
    var momType: String
    var kind: String
    var content: String
    var relatedField: String?
    var timestamp: Date
    var isActiveBranch: Bool
    var branchVersion: Int
    var archivedAt: Date?
}

struct LearningTraceSnapshot: Codable, Identifiable {
    var id: String
    var stageOrder: Int
    var stageTitle: String
    var actionType: String
    var title: String
    var detail: String
    var timestamp: Date
}

struct ResourceCardSnapshot: Codable, Identifiable {
    var id: String
    var title: String
    var type: String
    var summary: String
    var whyRelevant: String
    var howToUse: String
    var sourceURL: String?
    var citation: String?
    var authors: String?
    var year: Int?
    var venue: String?
    var relatedStages: [Int]
    var tags: [String]
    var researchInsight: String?
    var designImplication: String?

    init(resource: ResourceCard) {
        id = resource.id
        title = resource.title
        type = resource.type.rawValue
        summary = resource.summary
        whyRelevant = resource.whyRelevant
        howToUse = resource.howToUse
        sourceURL = resource.sourceURL?.absoluteString
        citation = resource.citation
        authors = resource.authors
        year = resource.year
        venue = resource.venue
        relatedStages = resource.relatedStages
        tags = resource.tags
        researchInsight = resource.researchInsight
        designImplication = resource.designImplication
    }
}

enum ReportSnapshotValue {
    static let missing = "待补充"

    static func text(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? missing : trimmed
    }

    static func stageTitle(_ order: Int) -> String {
        StageDefinition.all.first { $0.order == order }?.name ?? "Stage \(order)"
    }

    static func momentTypeTitle(_ type: String) -> String {
        switch type {
        case "seed":
            return "初始想法"
        case "branch":
            return "阶段探索"
        case "question":
            return "问题"
        case "answer":
            return "回答"
        case "decision", "deepen":
            return "判断"
        case "method":
            return "方法依据"
        case "evidence":
            return "证据"
        case "revise":
            return "修订"
        default:
            return type.isEmpty ? "过程" : type
        }
    }
}
