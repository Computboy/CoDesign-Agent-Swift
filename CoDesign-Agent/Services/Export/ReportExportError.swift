import Foundation

enum ReportExportError: LocalizedError {
    case encodingFailed(String)
    case decodingFailed(String)
    case invalidPackage(String)
    case unsupportedSchema(String)
    case unsupportedPDFPlatform
    case emptyPackage
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let message):
            return "导出编码失败：\(message)"
        case .decodingFailed(let message):
            return "文件读取失败：\(message)"
        case .invalidPackage(let message):
            return "这不是合法的 CoDesign 项目包：\(message)"
        case .unsupportedSchema(let version):
            return "此 CoDesign 项目包版本暂不支持导入，但可以尝试只读预览。（schemaVersion: \(version)）"
        case .unsupportedPDFPlatform:
            return "当前平台暂不支持 PDF 生成，请先导出 Markdown / JSON / .codesign。"
        case .emptyPackage:
            return "项目包中没有可显示的思维树数据。"
        case .importFailed(let message):
            return "导入失败：\(message)"
        }
    }
}
