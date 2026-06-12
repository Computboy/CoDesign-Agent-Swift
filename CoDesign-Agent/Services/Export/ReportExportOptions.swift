import Foundation

struct ReportExportOptions: Codable, Equatable {
    var format: ReportExportFormat
    var includeDecisionTrace: Bool
    var includeFullMindTree: Bool
    var includeArchivedBranches: Bool
    var includeResources: Bool
    var includeConversationSummary: Bool
    var includeReportSections: Bool
    var includeDesignBrief: Bool

    init(format: ReportExportFormat) {
        self = Self.defaults(for: format)
    }

    init(
        format: ReportExportFormat,
        includeDecisionTrace: Bool,
        includeFullMindTree: Bool,
        includeArchivedBranches: Bool,
        includeResources: Bool,
        includeConversationSummary: Bool = false,
        includeReportSections: Bool,
        includeDesignBrief: Bool
    ) {
        self.format = format
        self.includeDecisionTrace = includeDecisionTrace
        self.includeFullMindTree = includeFullMindTree
        self.includeArchivedBranches = includeArchivedBranches
        self.includeResources = includeResources
        self.includeConversationSummary = includeConversationSummary
        self.includeReportSections = includeReportSections
        self.includeDesignBrief = includeDesignBrief
    }

    static func defaults(for format: ReportExportFormat) -> ReportExportOptions {
        switch format {
        case .pdf, .markdown:
            return ReportExportOptions(
                format: format,
                includeDecisionTrace: true,
                includeFullMindTree: false,
                includeArchivedBranches: false,
                includeResources: true,
                includeConversationSummary: false,
                includeReportSections: true,
                includeDesignBrief: true
            )
        case .json, .codesignPackage:
            return ReportExportOptions(
                format: format,
                includeDecisionTrace: true,
                includeFullMindTree: true,
                includeArchivedBranches: true,
                includeResources: true,
                includeConversationSummary: false,
                includeReportSections: true,
                includeDesignBrief: true
            )
        }
    }

    mutating func normalizeForFormat() {
        let defaults = Self.defaults(for: format)
        switch format {
        case .pdf, .markdown:
            includeDecisionTrace = true
            includeReportSections = true
            includeDesignBrief = true
            if !includeFullMindTree {
                includeArchivedBranches = false
            }
        case .json, .codesignPackage:
            includeDecisionTrace = defaults.includeDecisionTrace
            includeFullMindTree = defaults.includeFullMindTree
            includeArchivedBranches = defaults.includeArchivedBranches
            includeResources = defaults.includeResources
            includeReportSections = defaults.includeReportSections
            includeDesignBrief = defaults.includeDesignBrief
        }
    }
}
