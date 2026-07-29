import Foundation

/// Finds conservative block boundaries without trying to replace a Markdown parser.
///
/// Completed blocks are rendered once in the stable region. The unfinished tail stays
/// in the draft region and may be reparsed as chunks arrive.
struct MarkdownBlockAssembler: Sendable {
    nonisolated static func assemble(_ source: String) -> MarkdownBlockAssembly {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        guard !normalized.isEmpty else {
            return MarkdownBlockAssembly(
                source: "",
                stableMarkdown: "",
                draftMarkdown: "",
                draftRequiresPlainText: false,
                readableDraftText: ""
            )
        }

        let candidates = stableBoundaryCandidates(in: normalized)
        let boundary = candidates.reversed().first { candidate in
            let prefix = String(normalized[..<candidate])
            return !hasUnclosedInlineConstruct(in: prefix)
        } ?? normalized.startIndex

        let stable = String(normalized[..<boundary])
        let draft = String(normalized[boundary...])
        let draftIsIncomplete = hasUnclosedConstruct(in: draft)

        return MarkdownBlockAssembly(
            source: normalized,
            stableMarkdown: stable,
            draftMarkdown: draft,
            draftRequiresPlainText: draftIsIncomplete,
            readableDraftText: readableDraft(from: draft)
        )
    }

    nonisolated private static func stableBoundaryCandidates(in source: String) -> [String.Index] {
        var candidates: [String.Index] = [source.startIndex]
        var lineStart = source.startIndex
        var insideFence = false
        var activeFenceMarker: Character?

        while lineStart < source.endIndex {
            let newline = source[lineStart...].firstIndex(of: "\n")
            let lineEnd = newline ?? source.endIndex
            let nextLineStart = newline.map { source.index(after: $0) } ?? source.endIndex
            let line = source[lineStart..<lineEnd]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let marker = fenceMarker(in: trimmed) {
                if insideFence, marker == activeFenceMarker {
                    insideFence = false
                    activeFenceMarker = nil
                    if newline != nil {
                        candidates.append(nextLineStart)
                    }
                } else if !insideFence {
                    insideFence = true
                    activeFenceMarker = marker
                }
            } else if !insideFence, trimmed.isEmpty, newline != nil {
                candidates.append(nextLineStart)
            } else if !insideFence,
                      newline != nil,
                      isStandaloneLineBlock(trimmed) {
                candidates.append(nextLineStart)
            }

            lineStart = nextLineStart
        }

        if !insideFence,
           source.hasSuffix("\n\n"),
           !hasUnclosedInlineConstruct(in: source) {
            candidates.append(source.endIndex)
        }

        return candidates
    }

    nonisolated private static func isStandaloneLineBlock(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        if headingPrefixLength(in: line) > 0 {
            return true
        }

        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy { $0 == "-" }
            || compact.allSatisfy { $0 == "*" }
            || compact.allSatisfy { $0 == "_" }
    }

    nonisolated private static func hasUnclosedConstruct(in text: String) -> Bool {
        hasUnclosedFence(in: text) || hasUnclosedInlineConstruct(in: text)
    }

    nonisolated private static func hasUnclosedFence(in text: String) -> Bool {
        var openMarker: Character?
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let marker = fenceMarker(in: line) else { continue }
            if openMarker == marker {
                openMarker = nil
            } else if openMarker == nil {
                openMarker = marker
            }
        }
        return openMarker != nil
    }

    nonisolated private static func hasUnclosedInlineConstruct(in text: String) -> Bool {
        let withoutEscapes = removingEscapedCharacters(from: text)
        if occurrenceCount(of: "**", in: withoutEscapes).isMultiple(of: 2) == false {
            return true
        }
        if occurrenceCount(of: "__", in: withoutEscapes).isMultiple(of: 2) == false {
            return true
        }
        if occurrenceCount(of: "`", in: withoutEscapes).isMultiple(of: 2) == false {
            return true
        }
        let withoutStrongMarkers = withoutEscapes
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
        if singleEmphasisMarkerCount("*", in: withoutStrongMarkers).isMultiple(of: 2) == false {
            return true
        }
        if singleEmphasisMarkerCount("_", in: withoutStrongMarkers).isMultiple(of: 2) == false {
            return true
        }

        if let opening = withoutEscapes.range(of: "](", options: .backwards),
           withoutEscapes[opening.upperBound...].contains(")") == false {
            return true
        }

        return false
    }

    nonisolated private static func readableDraft(from draft: String) -> String {
        guard !draft.isEmpty else { return "" }
        var result = draft

        if hasUnclosedFence(in: result) {
            var lines = result.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if let index = lines.firstIndex(where: {
                fenceMarker(in: $0.trimmingCharacters(in: .whitespaces)) != nil
            }) {
                lines.remove(at: index)
            }
            result = lines.joined(separator: "\n")
        }

        result = removingUnpairedDelimiter("**", from: result)
        result = removingUnpairedDelimiter("__", from: result)
        result = removingUnpairedDelimiter("`", from: result)
        result = removingUnpairedSingleEmphasis("*", from: result)
        result = removingUnpairedSingleEmphasis("_", from: result)
        result = simplifyingIncompleteLink(in: result)

        let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
        result = lines.map { rawLine in
            let line = String(rawLine)
            let prefixLength = headingPrefixLength(in: line)
            guard prefixLength > 0 else { return line }
            return String(line.dropFirst(prefixLength)).drop(while: \.isWhitespace).description
        }
        .joined(separator: "\n")

        return result
    }

    nonisolated private static func removingUnpairedDelimiter(
        _ delimiter: String,
        from text: String
    ) -> String {
        let count = occurrenceCount(of: delimiter, in: removingEscapedCharacters(from: text))
        guard !count.isMultiple(of: 2),
              let range = text.range(of: delimiter, options: .backwards) else {
            return text
        }
        var copy = text
        copy.removeSubrange(range)
        return copy
    }

    nonisolated private static func removingUnpairedSingleEmphasis(
        _ marker: Character,
        from text: String
    ) -> String {
        var characters = Array(
            text
                .replacingOccurrences(of: String(repeating: marker, count: 2), with: "")
        )
        guard !singleEmphasisMarkerCount(marker, in: String(characters)).isMultiple(of: 2) else {
            return text
        }

        for index in characters.indices.reversed() where characters[index] == marker {
            let previous = index > characters.startIndex ? characters[index - 1] : nil
            let next = index < characters.index(before: characters.endIndex) ? characters[index + 1] : nil
            if marker == "_", previous?.isLetterOrNumber == true, next?.isLetterOrNumber == true {
                continue
            }
            characters.remove(at: index)
            return String(characters)
        }
        return text
    }

    nonisolated private static func simplifyingIncompleteLink(in text: String) -> String {
        guard let separator = text.range(of: "](", options: .backwards),
              text[separator.upperBound...].contains(")") == false,
              let opening = text[..<separator.lowerBound].lastIndex(of: "[") else {
            return text
        }

        let labelStart = text.index(after: opening)
        let label = text[labelStart..<separator.lowerBound]
        var copy = text
        copy.replaceSubrange(opening..<copy.endIndex, with: label)
        return copy
    }

    nonisolated private static func fenceMarker(in line: String) -> Character? {
        guard line.count >= 3, let first = line.first, first == "`" || first == "~" else {
            return nil
        }
        let prefixCount = line.prefix { $0 == first }.count
        return prefixCount >= 3 ? first : nil
    }

    nonisolated private static func headingPrefixLength(in line: String) -> Int {
        var count = 0
        for character in line {
            guard character == "#", count < 6 else { break }
            count += 1
        }
        guard count > 0 else { return 0 }
        let index = line.index(line.startIndex, offsetBy: count)
        guard index == line.endIndex || line[index].isWhitespace else { return 0 }
        return count
    }

    nonisolated private static func occurrenceCount(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var searchStart = haystack.startIndex
        while searchStart < haystack.endIndex,
              let range = haystack.range(of: needle, range: searchStart..<haystack.endIndex) {
            count += 1
            searchStart = range.upperBound
        }
        return count
    }

    nonisolated private static func singleEmphasisMarkerCount(
        _ marker: Character,
        in text: String
    ) -> Int {
        let characters = Array(text)
        var count = 0
        for index in characters.indices where characters[index] == marker {
            let previous = index > characters.startIndex ? characters[index - 1] : nil
            let next = index < characters.index(before: characters.endIndex) ? characters[index + 1] : nil
            if marker == "_", previous?.isLetterOrNumber == true, next?.isLetterOrNumber == true {
                continue
            }
            count += 1
        }
        return count
    }

    nonisolated private static func removingEscapedCharacters(from text: String) -> String {
        var result = ""
        var isEscaped = false
        for character in text {
            if isEscaped {
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            result.append(character)
        }
        return result
    }
}

private extension Character {
    nonisolated var isLetterOrNumber: Bool {
        unicodeScalars.allSatisfy {
            CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
        }
    }
}
