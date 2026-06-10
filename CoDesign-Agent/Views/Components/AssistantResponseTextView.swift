import SwiftUI
import Foundation

struct AssistantResponseTextView: View {
    let text: String
    var font: Font = AppTheme.Typography.body
    var foregroundColor: Color = .textPrimary
    var lineSpacing: CGFloat = 2

    var body: some View {
        let normalized = AssistantTextNormalizer.normalize(text)

        Group {
            if let attributed = try? AttributedString(markdown: normalized) {
                Text(attributed)
            } else {
                Text(normalized)
            }
        }
        .font(font)
        .foregroundStyle(foregroundColor)
        .lineSpacing(lineSpacing)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum AssistantTextNormalizer {
    static func normalize(_ text: String) -> String {
        let unified = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !unified.isEmpty else { return "" }

        let lines = unified
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { stripMarkdownHeading(String($0)) }

        var paragraphs: [String] = []
        var current = ""

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                paragraphs.append(trimmed)
            }
            current = ""
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                flush()
                continue
            }

            if current.isEmpty {
                current = trimmed
                continue
            }

            if shouldMerge(previous: current, next: trimmed) {
                current += joiner(previous: current, next: trimmed) + trimmed
            } else {
                flush()
                current = trimmed
            }
        }

        flush()
        return paragraphs.joined(separator: "\n\n")
    }

    private static func stripMarkdownHeading(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"^\s{0,3}#{1,6}\s*"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func shouldMerge(previous: String, next: String) -> Bool {
        guard !isListOrLabel(next) else { return false }
        return !endsWithStrongPunctuation(previous)
    }

    private static func endsWithStrongPunctuation(_ value: String) -> Bool {
        guard let last = value.trimmingCharacters(in: .whitespacesAndNewlines).last else {
            return false
        }
        return "。！？!?：:；;」”）)".contains(last)
    }

    private static func isListOrLabel(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
            return true
        }
        if trimmed.range(of: #"^\d+[\.、]\s*"#, options: .regularExpression) != nil {
            return true
        }

        let labels = ["理解", "线索", "追问", "依据", "例子", "下一步", "这个问题会决定", "参考"]
        return labels.contains { label in
            trimmed.hasPrefix("\(label)：") || trimmed.hasPrefix("\(label):")
        }
    }

    private static func joiner(previous: String, next: String) -> String {
        guard let last = previous.last, let first = next.first else { return "" }
        if isASCII(last) && isASCII(first) {
            return " "
        }
        return ""
    }

    private static func isASCII(_ character: Character) -> Bool {
        String(character).unicodeScalars.allSatisfy(\.isASCII)
    }
}
