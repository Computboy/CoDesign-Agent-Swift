import Foundation

enum ReportFileWriter {
    static func defaultFileName(projectName: String, format: ReportExportFormat, date: Date = Date()) -> String {
        let safeName = sanitizeFileName(projectName.isEmpty ? "CoDesign项目" : projectName)
        let dateString = compactDateFormatter.string(from: date)

        switch format {
        case .pdf:
            return "\(safeName)-AI产品设计交接简报-\(dateString).pdf"
        case .markdown:
            return "\(safeName)-AI产品设计报告-\(dateString).md"
        case .json:
            return "\(safeName)-AI产品设计数据-\(dateString).json"
        case .codesignPackage:
            return "\(safeName)-CoDesign交互项目包-\(dateString).codesign"
        }
    }

    static func sanitizeFileName(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_()（）[]【】. ")
        let scalars = raw.unicodeScalars.map { scalar -> String in
            let isCJK = (0x4E00...0x9FFF).contains(Int(scalar.value))
            if allowed.contains(scalar) || isCJK {
                return String(scalar)
            }
            return "-"
        }
        let collapsed = scalars
            .joined()
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ". -\n\r\t"))
        return collapsed.isEmpty ? "CoDesign项目" : String(collapsed.prefix(80))
    }

    static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
