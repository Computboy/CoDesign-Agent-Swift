import Foundation
import Markdown

/// Converts the Swift Markdown AST into a deliberately small HTML vocabulary.
///
/// Raw HTML and remote images are never passed through. Link destinations are limited
/// to http/https and all text/attributes are escaped before reaching the web view.
nonisolated struct MarkdownHTMLRenderer: MarkupWalker {
    private(set) var result = ""
    private var inTableHead = false
    private var tableColumnAlignments: [Table.ColumnAlignment?]?
    private var currentTableColumn = 0

    nonisolated static func render(_ markdown: String) -> String {
        guard !markdown.isEmpty else { return "" }
        let document = Document(parsing: markdown)
        var renderer = MarkdownHTMLRenderer()
        renderer.visit(document)
        return renderer.result
    }

    nonisolated static func renderBlocks(_ markdown: String) -> [RenderedMarkdownBlock] {
        guard !markdown.isEmpty else { return [] }
        let document = Document(parsing: markdown)
        return document.children.enumerated().map { index, child in
            var renderer = MarkdownHTMLRenderer()
            renderer.visit(child)
            let html = renderer.result
            return RenderedMarkdownBlock(
                id: "stable-\(index)-\(stableHash(html))",
                html: html
            )
        }
    }

    nonisolated static func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        wrap("blockquote", around: blockQuote, trailingNewline: true)
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let language = codeBlock.language.flatMap(Self.safeCSSIdentifier)
        let languageAttribute = language.map { " class=\"language-\($0)\"" } ?? ""
        result += "<pre><code\(languageAttribute)>\(Self.escapeText(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHeading(_ heading: Heading) {
        result += "<h\(heading.level)>"
        descendInto(heading)
        result += "</h\(heading.level)>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        result += "<hr>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        result += "<p class=\"raw-markdown-html\">\(Self.escapeText(html.rawHTML))</p>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) {
        result += "<li>"
        if let checkbox = listItem.checkbox {
            let symbol = checkbox == .checked ? "☑︎ " : "☐ "
            result += "<span class=\"task-marker\" aria-hidden=\"true\">\(symbol)</span>"
        }
        descendInto(listItem)
        result += "</li>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let start = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
        result += "<ol\(start)>\n"
        descendInto(orderedList)
        result += "</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        result += "<ul>\n"
        descendInto(unorderedList)
        result += "</ul>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        wrap("p", around: paragraph, trailingNewline: true)
    }

    mutating func visitTable(_ table: Table) {
        result += "<div class=\"table-scroll\"><table>\n"
        tableColumnAlignments = table.columnAlignments
        descendInto(table)
        tableColumnAlignments = nil
        result += "</table></div>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) {
        result += "<thead><tr>\n"
        inTableHead = true
        currentTableColumn = 0
        descendInto(tableHead)
        inTableHead = false
        result += "</tr></thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) {
        guard !tableBody.isEmpty else { return }
        result += "<tbody>\n"
        descendInto(tableBody)
        result += "</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) {
        currentTableColumn = 0
        result += "<tr>\n"
        descendInto(tableRow)
        result += "</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) {
        guard tableCell.colspan > 0, tableCell.rowspan > 0 else { return }
        let element = inTableHead ? "th" : "td"
        var attributes = ""

        if let alignments = tableColumnAlignments,
           currentTableColumn < alignments.count,
           let alignment = alignments[currentTableColumn] {
            attributes += " class=\"align-\(Self.escapeText(String(describing: alignment)))\""
        }
        currentTableColumn += 1

        if tableCell.rowspan > 1 {
            attributes += " rowspan=\"\(tableCell.rowspan)\""
        }
        if tableCell.colspan > 1 {
            attributes += " colspan=\"\(tableCell.colspan)\""
        }

        result += "<\(element)\(attributes)>"
        descendInto(tableCell)
        result += "</\(element)>\n"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        result += "<code>\(Self.escapeText(inlineCode.code))</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        wrap("em", around: emphasis)
    }

    mutating func visitStrong(_ strong: Strong) {
        wrap("strong", around: strong)
    }

    mutating func visitImage(_ image: Image) {
        result += "<span class=\"image-alt\" role=\"note\">"
        descendInto(image)
        result += "</span>"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        result += Self.escapeText(inlineHTML.rawHTML)
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        result += "<br>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        result += "\n"
    }

    mutating func visitLink(_ link: Link) {
        guard let destination = link.destination,
              Self.isAllowedLink(destination) else {
            descendInto(link)
            return
        }

        result += "<a href=\"\(Self.escapeText(destination))\" rel=\"noreferrer noopener\">"
        descendInto(link)
        result += "</a>"
    }

    mutating func visitText(_ text: Text) {
        result += Self.escapeText(text.string)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        wrap("del", around: strikethrough)
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) {
        if let destination = symbolLink.destination {
            result += "<code>\(Self.escapeText(destination))</code>"
        }
    }

    mutating func visitInlineAttributes(_ attributes: InlineAttributes) {
        descendInto(attributes)
    }

    private mutating func wrap(
        _ tag: String,
        around markup: Markup,
        trailingNewline: Bool = false
    ) {
        result += "<\(tag)>"
        descendInto(markup)
        result += "</\(tag)>"
        if trailingNewline {
            result += "\n"
        }
    }

    nonisolated private static func isAllowedLink(_ destination: String) -> Bool {
        guard let components = URLComponents(string: destination),
              let scheme = components.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    nonisolated private static func safeCSSIdentifier(_ value: String) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let filtered = value.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(filtered))
        return result.isEmpty ? nil : result
    }

    nonisolated private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
