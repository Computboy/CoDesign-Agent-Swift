import Foundation

enum ReportSectionID: String, CaseIterable, Codable {
    case projectDefinition
    case productScope
    case coreExperienceFlow
    case aiBehaviorBoundary
    case validationRisks
}

enum ReportFactKey: String, Hashable, Codable {
    case projectName
    case oneSentenceSolution
    case targetUser
    case painPoint
    case useScenario
    case coreValue
    case differentiation
    case includedScope
    case excludedScope
    case mvpFeatures
    case technicalModules
    case interactionFlow
    case operationLogic
    case hardConstraints
    case milestones
    case successMetrics
    case risks
}

/// PDF 导出层的只读派生模型。它不写回 Project，也不保存画布或分支状态。
struct ReportDocumentModel: Equatable {
    var title: String
    var subtitle: String = ReportCopy.documentSubtitle
    var projectName: String
    var projectTagline: String? = nil
    var metadata: [ReportMetadata] = []
    var sections: [ReportSection]

    func occurrenceCount(of factKey: ReportFactKey) -> Int {
        sections.reduce(into: 0) { count, section in
            count += section.blocks.reduce(into: 0) { blockCount, block in
                if block.factKeys.contains(factKey) {
                    blockCount += 1
                }
            }
        }
    }

    var allTextFragments: [String] {
        [title, subtitle, projectName, projectTagline]
            .compactMap { $0 }
            + metadata.flatMap { [$0.label, $0.value] }
            + sections.flatMap(\.allTextFragments)
    }
}

/// 保留短名称，避免让渲染与测试代码承担迁移噪音。
typealias ReportDocument = ReportDocumentModel

struct ReportMetadata: Equatable {
    var label: String
    var value: String
}

struct ReportSection: Identifiable, Equatable {
    var id: ReportSectionID
    var title: String
    var englishTitle: String? = nil
    var purpose: String
    var blocks: [ReportBlock]

    var allTextFragments: [String] {
        [title, englishTitle, purpose].compactMap { $0 } + blocks.flatMap(\.allTextFragments)
    }
}

enum ReportBlock: Equatable {
    case keyValues([ReportKeyValue])
    case fieldGroup(ReportFieldGroup)
    case twoColumn(ReportColumn, ReportColumn)
    case bulletList(ReportBulletList)
    case flow(ReportFlow)
    case callout(ReportCallout)
    case metrics(ReportMetricsTable)
    case risks(ReportRisksTable)
    case pendingNote(ReportPendingNote)

    var factKeys: Set<ReportFactKey> {
        switch self {
        case .keyValues(let items):
            return Set(items.compactMap(\.factKey))
        case .fieldGroup(let group):
            return Set(group.items.compactMap(\.factKey))
        case .twoColumn(let left, let right):
            return Set([left.factKey, right.factKey].compactMap { $0 })
        case .bulletList(let list):
            return Set([list.factKey].compactMap { $0 })
        case .flow(let flow):
            return [flow.factKey]
        case .callout(let callout):
            return Set([callout.factKey].compactMap { $0 })
        case .metrics(let table):
            return [table.factKey]
        case .risks(let table):
            return [table.factKey]
        case .pendingNote:
            return []
        }
    }

    var allTextFragments: [String] {
        switch self {
        case .keyValues(let items):
            return items.flatMap { [$0.label, $0.value] }
        case .fieldGroup(let group):
            return [group.title] + group.items.flatMap { [$0.label, $0.value] }
        case .twoColumn(let left, let right):
            return [left.title] + left.items + [right.title] + right.items
        case .bulletList(let list):
            return [list.title] + list.items
        case .flow(let flow):
            return flow.steps.flatMap { [$0.actor.primaryLabel, $0.actor.auxiliaryLabel, $0.text] }
        case .callout(let callout):
            return [callout.title, callout.body]
        case .metrics(let table):
            return table.rows.flatMap { [$0.metric, $0.category, $0.target, $0.measurement, $0.status] }
        case .risks(let table):
            return table.rows.flatMap { row in
                [row.risk, row.triggerOrFailure, row.detection, row.recovery, row.userControl].compactMap { $0 }
            }
        case .pendingNote(let note):
            return [note.title, note.body].compactMap { $0 }
        }
    }
}

struct ReportKeyValue: Equatable {
    var label: String
    var value: String
    var factKey: ReportFactKey?
}

struct ReportFieldGroup: Equatable {
    var title: String
    var items: [ReportKeyValue]
}

struct ReportColumn: Equatable {
    var title: String
    var items: [String]
    var factKey: ReportFactKey?
}

struct ReportBulletList: Equatable {
    var title: String
    var items: [String]
    var factKey: ReportFactKey?
}

enum ReportFlowActor: String, Equatable {
    case user
    case ai
    case system
    case humanInTheLoop
    case unspecified

    var primaryLabel: String {
        switch self {
        case .user: return ReportCopy.Flow.user
        case .ai: return ReportCopy.Flow.ai
        case .system: return ReportCopy.Flow.system
        case .humanInTheLoop: return ReportCopy.Flow.humanConfirmation
        case .unspecified: return ReportCopy.Flow.unspecified
        }
    }

    var auxiliaryLabel: String {
        switch self {
        case .user: return "USER"
        case .ai: return "AI"
        case .system: return "SYSTEM"
        case .humanInTheLoop: return "HITL"
        case .unspecified: return ""
        }
    }

    var displayLabel: String {
        auxiliaryLabel.isEmpty ? primaryLabel : "\(primaryLabel) · \(auxiliaryLabel)"
    }
}

struct ReportFlowStep: Equatable {
    var actor: ReportFlowActor
    var text: String
    var isConfirmation: Bool
}

struct ReportFlow: Equatable {
    var factKey: ReportFactKey
    var steps: [ReportFlowStep]
}

struct ReportCallout: Equatable {
    var title: String
    var body: String
    var factKey: ReportFactKey?
}

struct ReportMetricRow: Equatable {
    var metric: String
    var category: String
    var target: String
    var measurement: String
    var status: String
}

struct ReportMetricsTable: Equatable {
    var factKey: ReportFactKey
    var rows: [ReportMetricRow]
}

struct ReportRiskRow: Equatable {
    var risk: String
    var probability: Int?
    var impact: Int?
    var triggerOrFailure: String?
    var detection: String?
    var recovery: String?
    var userControl: String?

    var availableDetails: [(String, String)] {
        [
            (ReportCopy.Risk.trigger, triggerOrFailure),
            (ReportCopy.Risk.detection, detection),
            (ReportCopy.Risk.response, recovery),
            (ReportCopy.Risk.userControl, userControl),
        ].compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }
    }
}

struct ReportRisksTable: Equatable {
    var factKey: ReportFactKey
    var rows: [ReportRiskRow]
}

struct ReportPendingNote: Equatable {
    var title: String
    var body: String?
}

enum ReportContentTier: String, Equatable {
    case required = "A"
    case conditional = "B"
    case archiveOnly = "C"
}

enum ReportSourceField: String, CaseIterable {
    case schemaMetadata
    case projectID
    case projectName
    case briefDescription
    case projectDates
    case completionAndCurrentStage
    case stages
    case targetUser
    case painPoint
    case useScenario
    case coreValue
    case differentiation
    case boundaryItems
    case mvpFeatures
    case technicalModules
    case interactionFlow
    case operationLogic
    case hardConstraints
    case successMetrics
    case risks
    case milestones
    case derivedReportSections
    case decisionTrace
    case thinkingMoments
    case learningTraces
    case resources
    case conversationSummary
    case exportOptions
}

struct ReportFieldPolicy: Equatable {
    var field: ReportSourceField
    var tier: ReportContentTier
    var ownerSection: ReportSectionID?
}

enum CompactReportFieldPolicy {
    static let all: [ReportFieldPolicy] = [
        .init(field: .projectName, tier: .required, ownerSection: .projectDefinition),
        .init(field: .briefDescription, tier: .required, ownerSection: .projectDefinition),
        .init(field: .targetUser, tier: .required, ownerSection: .projectDefinition),
        .init(field: .painPoint, tier: .required, ownerSection: .projectDefinition),
        .init(field: .useScenario, tier: .required, ownerSection: .projectDefinition),
        .init(field: .coreValue, tier: .required, ownerSection: .projectDefinition),
        .init(field: .differentiation, tier: .conditional, ownerSection: .projectDefinition),
        .init(field: .boundaryItems, tier: .required, ownerSection: .productScope),
        .init(field: .mvpFeatures, tier: .required, ownerSection: .productScope),
        .init(field: .technicalModules, tier: .required, ownerSection: .productScope),
        .init(field: .hardConstraints, tier: .required, ownerSection: .productScope),
        .init(field: .interactionFlow, tier: .required, ownerSection: .coreExperienceFlow),
        .init(field: .operationLogic, tier: .conditional, ownerSection: .coreExperienceFlow),
        .init(field: .successMetrics, tier: .required, ownerSection: .validationRisks),
        .init(field: .risks, tier: .required, ownerSection: .validationRisks),
        .init(field: .milestones, tier: .conditional, ownerSection: .validationRisks),
        .init(field: .schemaMetadata, tier: .archiveOnly, ownerSection: nil),
        .init(field: .projectID, tier: .archiveOnly, ownerSection: nil),
        .init(field: .projectDates, tier: .archiveOnly, ownerSection: nil),
        .init(field: .completionAndCurrentStage, tier: .archiveOnly, ownerSection: nil),
        .init(field: .stages, tier: .archiveOnly, ownerSection: nil),
        .init(field: .derivedReportSections, tier: .archiveOnly, ownerSection: nil),
        .init(field: .decisionTrace, tier: .archiveOnly, ownerSection: nil),
        .init(field: .thinkingMoments, tier: .archiveOnly, ownerSection: nil),
        .init(field: .learningTraces, tier: .archiveOnly, ownerSection: nil),
        .init(field: .resources, tier: .archiveOnly, ownerSection: nil),
        .init(field: .conversationSummary, tier: .archiveOnly, ownerSection: nil),
        .init(field: .exportOptions, tier: .archiveOnly, ownerSection: nil),
    ]

    static func policy(for field: ReportSourceField) -> ReportFieldPolicy {
        guard let policy = all.first(where: { $0.field == field }) else {
            preconditionFailure("Missing compact report policy for \(field.rawValue)")
        }
        return policy
    }
}
