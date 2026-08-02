import Foundation
import UniformTypeIdentifiers

enum ReportExportFormat: String, CaseIterable, Codable, Identifiable {
    case pdf
    case markdown
    case json
    case codesignPackage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pdf:
            return "PDF 报告"
        case .markdown:
            return "Markdown 文档"
        case .json:
            return "JSON 数据"
        case .codesignPackage:
            return "CoDesign 交互项目包 (.codesign)"
        }
    }

    var subtitle: String {
        switch self {
        case .pdf:
            return "AI 产品设计交接简报，适合产品评审、原型、开发拆解与验证。"
        case .markdown:
            return "适合继续编辑、同步到 Notion / 飞书 / GitHub / PRD。"
        case .json:
            return "适合备份、开发调试和未来数据迁移。"
        case .codesignPackage:
            return "保存完整设计过程、思维树、回溯分支、Design Brief 与资源线索。"
        }
    }

    var fileExtension: String {
        switch self {
        case .pdf:
            return "pdf"
        case .markdown:
            return "md"
        case .json:
            return "json"
        case .codesignPackage:
            return "codesign"
        }
    }

    var contentType: UTType {
        switch self {
        case .pdf:
            return .pdf
        case .markdown:
            return .markdownReport
        case .json:
            return .json
        case .codesignPackage:
            return .codesignProject
        }
    }

    var isStaticReport: Bool {
        self == .pdf || self == .markdown
    }
}

extension UTType {
    static let markdownReport = UTType(filenameExtension: "md") ?? .plainText
    static let codesignProject = UTType(exportedAs: "com.codesign.project", conformingTo: .json)
}
