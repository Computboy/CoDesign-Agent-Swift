import Foundation
#if canImport(UIKit)
import UIKit
#else
import CoreGraphics
import CoreText
#endif

struct PDFPaginationDiagnostics: Equatable {
    var pageCount: Int
    var pageContentHeights: [CGFloat]
    var overflowCount: Int
    var orphanHeadingCount: Int
    var splitTextBlockCount: Int
    var repeatedTableHeaderCount: Int
    var forcedSectionPageBreakCount: Int
}

struct PDFRenderOutput {
    var data: Data
    var diagnostics: PDFPaginationDiagnostics
}

struct PDFReportRenderer {
    func render(snapshot: ProjectReportSnapshot) throws -> Data {
        let document = ReportContentBuilder().build(snapshot: snapshot)
        try ReportContentValidator.validate(document)
        #if canImport(UIKit)
        return StyledProjectPDFRenderer(snapshot: snapshot, document: document).render().data
        #else
        let reportText = CompactReportPlainTextRenderer().render(document: document)
        return try renderPDF(text: reportText)
        #endif
    }

    #if canImport(UIKit)
    func renderWithDiagnostics(
        snapshot: ProjectReportSnapshot,
        document: ReportDocument? = nil
    ) -> PDFRenderOutput {
        let document = document ?? ReportContentBuilder().build(snapshot: snapshot)
        return StyledProjectPDFRenderer(snapshot: snapshot, document: document).render()
    }
    #endif

    #if !canImport(UIKit)
    func renderPDF(text: String) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw ReportExportError.encodingFailed("无法创建 PDF 数据缓冲区。")
        }

        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ReportExportError.encodingFailed("无法创建 PDF 绘制上下文。")
        }

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("PingFang SC" as CFString, 10.5, nil),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.12, alpha: 1)
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let fullLength = attributed.length
        var currentIndex = 0
        let margin: CGFloat = 54
        let drawRect = CGRect(
            x: margin,
            y: margin,
            width: mediaBox.width - margin * 2,
            height: mediaBox.height - margin * 2
        )

        repeat {
            context.beginPDFPage(nil)
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)

            let path = CGMutablePath()
            path.addRect(drawRect)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: currentIndex, length: fullLength - currentIndex),
                path,
                nil
            )
            CTFrameDraw(frame, context)
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentIndex += max(visibleRange.length, 1)

            context.restoreGState()
            context.endPDFPage()
        } while currentIndex < fullLength

        context.closePDF()
        return data as Data
    }
    #endif
}

#if canImport(UIKit)
private struct ReportTextMeasurer {
    func attributedString(
        _ text: String,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineSpacing: CGFloat
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
    }

    func height(
        _ text: String,
        width: CGFloat,
        font: UIFont,
        lineSpacing: CGFloat
    ) -> CGFloat {
        let attributed = attributedString(
            text,
            font: font,
            color: PDFDesignTokens.Color.textPrimary,
            lineSpacing: lineSpacing
        )
        return ceil(
            attributed.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height
        )
    }
}

private struct ReportPaginationEngine {
    func shouldBeginNewPage(
        requiredHeight: CGFloat,
        remainingHeight: CGFloat,
        isAtPageTop: Bool,
        pageBodyHeight: CGFloat
    ) -> Bool {
        requiredHeight > remainingHeight && !isAtPageTop && requiredHeight <= pageBodyHeight
    }

    func splitText(
        _ text: String,
        maxHeight: CGFloat,
        measure: (String) -> CGFloat
    ) -> (prefix: String, remainder: String) {
        guard measure(text) > maxHeight else { return (text, "") }
        let characters = Array(text)
        var lower = 1
        var upper = characters.count
        var best = 1
        while lower <= upper {
            let midpoint = (lower + upper) / 2
            let candidate = String(characters.prefix(midpoint))
            if measure(candidate) <= maxHeight {
                best = midpoint
                lower = midpoint + 1
            } else {
                upper = midpoint - 1
            }
        }
        return (String(characters.prefix(best)), String(characters.dropFirst(best)))
    }
}

private final class StyledProjectPDFRenderer {
    private let snapshot: ProjectReportSnapshot
    private let document: ReportDocument
    private let pageRect = PDFVisualSystem.Page.rect
    private let margin = PDFVisualSystem.Page.horizontalMargin
    private let contentTop = PDFVisualSystem.Page.contentTop
    private var currentY = PDFVisualSystem.Page.contentTop
    private var pageNumber = 0
    private var context: UIGraphicsPDFRendererContext?
    private var pageContentHeights: [CGFloat] = []
    private var overflowCount = 0
    private var orphanHeadingCount = 0
    private var splitTextBlockCount = 0
    private var repeatedTableHeaderCount = 0
    private let layoutPolicy = ReportLayoutPolicy()
    private let textMeasurer = ReportTextMeasurer()
    private let paginationEngine = ReportPaginationEngine()

    private var contentWidth: CGFloat {
        pageRect.width - margin * 2
    }

    private var contentBottom: CGFloat {
        pageRect.height - PDFVisualSystem.Page.contentBottomInset
    }

    private var pageBodyHeight: CGFloat {
        contentBottom - contentTop
    }

    private var remainingHeight: CGFloat {
        max(0, contentBottom - currentY)
    }

    private var isAtPageTop: Bool {
        currentY <= contentTop + 0.5
    }

    init(snapshot: ProjectReportSnapshot, document: ReportDocument? = nil) {
        self.snapshot = snapshot
        self.document = document ?? CompactDesignHandoffReportBuilder().build(snapshot: snapshot)
    }

    func render() -> PDFRenderOutput {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(document.projectName)-\(ReportCopy.documentTitle)",
            kCGPDFContextAuthor as String: "CoDesign Agent",
            kCGPDFContextCreator as String: "CoDesign Agent"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { rendererContext in
            context = rendererContext
            beginPage()
            let sections = document.sections.filter { !$0.blocks.isEmpty }
            for (index, section) in sections.enumerated() {
                drawCompactSection(section, isFirstSection: index == 0)
            }
        }
        finalizeCurrentPageUsage()
        return PDFRenderOutput(
            data: data,
            diagnostics: PDFPaginationDiagnostics(
                pageCount: pageNumber,
                pageContentHeights: pageContentHeights,
                overflowCount: overflowCount,
                orphanHeadingCount: orphanHeadingCount,
                splitTextBlockCount: splitTextBlockCount,
                repeatedTableHeaderCount: repeatedTableHeaderCount,
                forcedSectionPageBreakCount: 0
            )
        )
    }

    private func drawCompactSection(_ section: ReportSection, isFirstSection: Bool) {
        if isFirstSection {
            let projectTitleHeight = measureText(
                document.projectName,
                width: contentWidth,
                font: PDFVisualSystem.Typography.projectTitle,
                lineSpacing: PDFVisualSystem.Typography.projectTitleSpacing
            )
            ensureSpace(min(pageBodyHeight, 58 + projectTitleHeight + PDFVisualSystem.Space.xl))
            drawDocumentHeader()
            drawStandaloneText(
                document.projectName,
                font: PDFVisualSystem.Typography.projectTitle,
                color: PDFVisualSystem.Color.textPrimary,
                lineSpacing: PDFVisualSystem.Typography.projectTitleSpacing,
                bottomSpacing: PDFVisualSystem.Space.xl
            )
        } else {
            let topSpacing: CGFloat = isAtPageTop ? 0 : PDFVisualSystem.Space.xl
            if let sectionHeight = compactSectionKeepTogetherHeight(section),
               topSpacing + sectionHeight > remainingHeight,
               sectionHeight <= pageBodyHeight {
                beginPage()
            } else if !isAtPageTop {
                currentY += topSpacing
            }
        }

        let behaviorOverviewHeight = section.id == .aiBehaviorBoundary
            ? behaviorGroupOverviewHeight(from: section.blocks)
            : nil
        drawSectionHeader(
            title: section.title,
            englishTitle: section.englishTitle,
            subtitle: section.purpose,
            keepWithNext: behaviorOverviewHeight
                ?? section.blocks.first.map(minimumLeadingHeight)
                ?? 0
        )
        if behaviorOverviewHeight != nil {
            drawBehaviorGroupOverview(from: section.blocks)
        } else {
            for block in section.blocks {
                drawCompactBlock(block)
                if currentY > contentBottom + 0.5 {
                    overflowCount += 1
                }
            }
        }
    }

    /// Short sections are treated as one semantic block only when their complete,
    /// measured content is small enough for a fresh page. This is deliberately not
    /// applied to long sections: they continue through the regular splitting rules.
    private func compactSectionKeepTogetherHeight(_ section: ReportSection) -> CGFloat? {
        let subtitleHeight = measureText(
            section.purpose,
            width: contentWidth,
            font: PDFVisualSystem.Typography.caption,
            lineSpacing: PDFVisualSystem.Typography.captionSpacing
        )
        var totalHeight = measureText(
            section.title,
            width: contentWidth - 14,
            font: PDFVisualSystem.Typography.h1,
            lineSpacing: PDFVisualSystem.Typography.h1Spacing
        )
            + PDFVisualSystem.Space.sm
            + (section.englishTitle.map {
                measureText(
                    $0,
                    width: contentWidth - 14,
                    font: PDFVisualSystem.Typography.caption,
                    lineSpacing: PDFVisualSystem.Typography.captionSpacing
                ) + PDFVisualSystem.Space.xs
            } ?? 0)
            + subtitleHeight
            + PDFVisualSystem.Space.lg
        if section.id == .aiBehaviorBoundary,
           let overviewHeight = behaviorGroupOverviewHeight(from: section.blocks) {
            totalHeight += overviewHeight
        } else {
            for block in section.blocks {
                guard let blockHeight = compactBlockKeepTogetherHeight(block) else { return nil }
                totalHeight += blockHeight
            }
        }
        let sectionLimit = section.id == .validationRisks ? 0.70 : 0.62
        return totalHeight <= pageBodyHeight * sectionLimit ? totalHeight : nil
    }

    private func behaviorGroupOverviewHeight(from blocks: [ReportBlock]) -> CGFloat? {
        let groups = blocks.compactMap { block -> ReportFieldGroup? in
            guard case .fieldGroup(let group) = block else { return nil }
            return group
        }
        guard groups.count == blocks.count,
              layoutPolicy.behaviorLayout(for: groups) == .matrix else { return nil }

        let gap = PDFVisualSystem.Space.lg
        let columnWidth = (contentWidth - gap * 2) / 3
        let innerWidth = columnWidth - PDFVisualSystem.Space.lg * 2
        let groupHeights = groups.map { group in
            let titleHeight = measureText(
                group.title,
                width: innerWidth,
                font: PDFVisualSystem.Typography.h2,
                lineSpacing: PDFVisualSystem.Typography.h2Spacing
            )
            let entriesHeight = behaviorDisplayEntries(group).reduce(CGFloat.zero) { partial, entry in
                partial + compactEntryMeasuredHeight(label: entry.0, value: entry.1, width: innerWidth)
            }
            return titleHeight + PDFVisualSystem.Space.md + entriesHeight
        }
        let height = PDFVisualSystem.Space.lg * 2 + (groupHeights.max() ?? 0)
        return height <= min(260, pageBodyHeight * 0.38)
            ? height + PDFVisualSystem.Space.md
            : nil
    }

    private func behaviorDisplayEntries(_ group: ReportFieldGroup) -> [(String, String)] {
        group.items.map { ($0.label, $0.value) }
    }

    private func drawBehaviorGroupOverview(from blocks: [ReportBlock]) {
        guard let heightWithSpacing = behaviorGroupOverviewHeight(from: blocks) else { return }
        let groups = blocks.compactMap { block -> ReportFieldGroup? in
            guard case .fieldGroup(let group) = block else { return nil }
            return group
        }
        ensureSpace(heightWithSpacing)

        let panelHeight = heightWithSpacing - PDFVisualSystem.Space.md
        let panelRect = CGRect(x: margin, y: currentY, width: contentWidth, height: panelHeight)
        drawRoundedRect(
            panelRect,
            radius: PDFVisualSystem.Radius.table,
            fill: PDFVisualSystem.Color.surface,
            stroke: PDFVisualSystem.Color.border,
            lineWidth: PDFVisualSystem.Table.borderWidth
        )
        PDFVisualSystem.Color.secondaryAccent.withAlphaComponent(0.16).setFill()
        UIBezierPath(
            roundedRect: CGRect(x: panelRect.minX, y: panelRect.minY, width: panelRect.width, height: 3),
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: PDFVisualSystem.Radius.table, height: PDFVisualSystem.Radius.table)
        ).fill()

        let gap = PDFVisualSystem.Space.lg
        let columnWidth = (contentWidth - gap * 2) / 3
        for (index, group) in groups.enumerated() {
            let columnX = margin + CGFloat(index) * (columnWidth + gap)
            if index > 0 {
                let ruleX = columnX - gap / 2
                drawRule(
                    from: CGPoint(x: ruleX, y: panelRect.minY + PDFVisualSystem.Space.lg),
                    to: CGPoint(x: ruleX, y: panelRect.maxY - PDFVisualSystem.Space.lg),
                    color: PDFVisualSystem.Color.border,
                    width: 0.5
                )
            }
            drawBehaviorGroupColumn(
                group,
                x: columnX + PDFVisualSystem.Space.lg,
                y: panelRect.minY + PDFVisualSystem.Space.lg,
                width: columnWidth - PDFVisualSystem.Space.lg * 2
            )
        }
        currentY += heightWithSpacing
    }

    private func drawBehaviorGroupColumn(
        _ group: ReportFieldGroup,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        let titleHeight = measureText(
            group.title,
            width: width,
            font: PDFVisualSystem.Typography.h2,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )
        _ = drawText(
            group.title,
            in: CGRect(x: x, y: y, width: width, height: titleHeight + 2),
            font: PDFVisualSystem.Typography.h2,
            color: PDFVisualSystem.Color.secondaryAccent,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )

        var entryY = y + titleHeight + PDFVisualSystem.Space.md
        for entry in behaviorDisplayEntries(group) {
            let labelHeight = measureText(
                entry.0,
                width: width,
                font: PDFVisualSystem.Typography.keyLabel,
                lineSpacing: PDFVisualSystem.Typography.labelSpacing
            )
            let valueHeight = measureText(
                entry.1,
                width: width,
                font: PDFVisualSystem.Typography.body,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            )
            _ = drawText(
                entry.0,
                in: CGRect(x: x, y: entryY, width: width, height: labelHeight + 2),
                font: PDFVisualSystem.Typography.keyLabel,
                color: PDFVisualSystem.Color.textPrimary,
                lineSpacing: PDFVisualSystem.Typography.labelSpacing
            )
            entryY += labelHeight + PDFVisualSystem.Space.xs
            _ = drawText(
                entry.1,
                in: CGRect(x: x, y: entryY, width: width, height: valueHeight + 2),
                font: PDFVisualSystem.Typography.body,
                color: PDFVisualSystem.Color.textSecondary,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            )
            entryY += valueHeight + PDFVisualSystem.Space.md
        }
    }

    private func compactBlockKeepTogetherHeight(_ block: ReportBlock) -> CGFloat? {
        switch block {
        case .keyValues(let items):
            return keyValueGroupHeight(items)

        case .fieldGroup(let group):
            let entries = group.items.map { ($0.label, $0.value) }
            guard let height = keepTogetherEntriesHeight(entries) else { return nil }
            return subsectionTitleHeight(group.title) + height

        case .twoColumn(let left, let right):
            if let visualHeight = twoColumnLayoutHeight(left: left, right: right) {
                return visualHeight
            }
            guard let leftHeight = compactListKeepTogetherHeight(title: left.title, items: left.items),
                  let rightHeight = compactListKeepTogetherHeight(title: right.title, items: right.items) else {
                return nil
            }
            return leftHeight + rightHeight

        case .bulletList(let list):
            return compactListKeepTogetherHeight(title: list.title, items: list.items)

        case .flow(let flow):
            let entries = flow.steps.enumerated().map { index, step in
                let confirmation = step.isConfirmation ? " · \(ReportCopy.Flow.finalConfirmation)" : ""
                return ("\(index + 1). \(step.actor.displayLabel)\(confirmation)", step.text)
            }
            guard let height = keepTogetherEntriesHeight(entries) else { return nil }
            return subsectionTitleHeight(ReportCopy.Flow.title) + height

        case .callout(let callout):
            return calloutLayoutHeight(title: callout.title, body: callout.body)
                ?? keepTogetherEntryHeight(label: callout.title, value: callout.body)

        case .metrics(let table):
            let headers = ReportCopy.Validation.metricHeaders
            let fractions: [CGFloat] = [0.19, 0.14, 0.18, 0.34, 0.15]
            let rowHeights = table.rows.map {
                tableRowHeight([$0.metric, $0.category, $0.target, $0.measurement, $0.status], fractions: fractions, isHeader: false)
            }
            guard rowHeights.allSatisfy({ $0 <= min(180, pageBodyHeight * 0.30) }) else { return nil }
            return subsectionTitleHeight(ReportCopy.Validation.metrics)
                + tableRowHeight(headers, fractions: fractions, isHeader: true)
                + rowHeights.reduce(0, +)
                + PDFVisualSystem.Space.md

        case .risks(let table):
            let rowHeights = table.rows.map { row in
                let priority = [
                    row.probability.map { "\(ReportCopy.Risk.probability) \($0)/5" },
                    row.impact.map { "\(ReportCopy.Risk.impact) \($0)/5" },
                ]
                .compactMap { $0 }
                .joined(separator: " · ")
                let riskValue = priority.isEmpty ? row.risk : "\(row.risk)（\(priority)）"
                if layoutPolicy.riskLayout(for: row) == .detailed {
                    return riskStructuredRowHeight(risk: riskValue, fields: row.availableDetails)
                }
                return compactRiskRowHeight(risk: riskValue, fields: row.availableDetails)
            }
            guard rowHeights.allSatisfy({ $0 <= min(220, pageBodyHeight * 0.36) }) else { return nil }
            return subsectionTitleHeight(ReportCopy.Risk.title) + rowHeights.reduce(0, +)

        case .pendingNote(let note):
            return calloutLayoutHeight(title: note.title, body: note.body ?? ReportCopy.pending)
                ?? keepTogetherEntryHeight(label: note.title, value: note.body ?? ReportCopy.pending)
        }
    }

    private func keepTogetherEntriesHeight(_ entries: [(String, String)]) -> CGFloat? {
        var totalHeight: CGFloat = 0
        for entry in entries {
            guard let height = keepTogetherEntryHeight(label: entry.0, value: entry.1) else { return nil }
            totalHeight += height
        }
        return totalHeight
    }

    private func compactListKeepTogetherHeight(title: String, items: [String]) -> CGFloat? {
        let heights = items.map { bulletItemHeight($0, width: contentWidth) }
        guard heights.allSatisfy({ $0 <= min(180, pageBodyHeight * 0.30) }) else { return nil }
        return subsectionTitleHeight(title) + heights.reduce(0, +)
    }

    private func subsectionTitleHeight(_ title: String) -> CGFloat {
        measureText(
            title,
            width: contentWidth,
            font: PDFVisualSystem.Typography.h2,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        ) + PDFVisualSystem.Space.md
    }

    private func keyValueGroupHeight(_ items: [ReportKeyValue]) -> CGFloat? {
        guard !items.isEmpty else { return 0 }
        var totalHeight: CGFloat = 0
        var gridItems = items
        if items.first?.label == "一句话方案", let first = items.first {
            guard let firstHeight = keepTogetherEntryHeight(label: first.label, value: first.value) else { return nil }
            totalHeight += firstHeight
            gridItems.removeFirst()
        }

        let gap = PDFVisualSystem.Space.xl
        let cellWidth = (contentWidth - gap) / 2
        var index = 0
        while index < gridItems.count {
            let row = Array(gridItems[index..<min(index + 2, gridItems.count)])
            let heights = row.map {
                compactEntryMeasuredHeight(label: $0.label, value: $0.value, width: cellWidth)
            }
            guard heights.allSatisfy({ $0 <= min(180, pageBodyHeight * 0.30) }) else { return nil }
            totalHeight += heights.max() ?? 0
            index += 2
        }
        return totalHeight
    }

    private func keepTogetherEntryHeight(label: String, value: String) -> CGFloat? {
        let height = measureText(
            label,
            width: contentWidth,
            font: PDFVisualSystem.Typography.keyLabel,
            lineSpacing: PDFVisualSystem.Typography.labelSpacing
        ) + measureText(
            value,
            width: contentWidth,
            font: PDFVisualSystem.Typography.body,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        ) + PDFVisualSystem.Space.lg
        return height <= min(180, pageBodyHeight * 0.30) ? height : nil
    }

    private func minimumLeadingHeight(for block: ReportBlock) -> CGFloat {
        switch block {
        case .keyValues(let items):
            guard let item = items.first else { return 0 }
            return compactEntryLeadingHeight(label: item.label, value: item.value)
        case .fieldGroup(let group):
            guard let item = group.items.first else { return subsectionTitleHeight(group.title) }
            return subsectionTitleHeight(group.title)
                + compactEntryLeadingHeight(label: item.label, value: item.value)
        case .twoColumn(let left, let right):
            if let height = twoColumnLayoutHeight(left: left, right: right) {
                return height
            }
            guard let item = left.items.first else { return subsectionTitleHeight(left.title) }
            return subsectionTitleHeight(left.title) + min(96, bulletItemHeight(item, width: contentWidth))
        case .bulletList(let list):
            guard let item = list.items.first else { return subsectionTitleHeight(list.title) }
            return subsectionTitleHeight(list.title) + min(96, bulletItemHeight(item, width: contentWidth))
        case .flow(let flow):
            guard let step = flow.steps.first else { return subsectionTitleHeight(ReportCopy.Flow.title) }
            return subsectionTitleHeight(ReportCopy.Flow.title)
                + compactEntryLeadingHeight(label: "1. \(step.actor.displayLabel)", value: step.text)
        case .callout(let callout):
            return calloutLayoutHeight(title: callout.title, body: callout.body)
                ?? compactEntryLeadingHeight(label: callout.title, value: callout.body)
        case .metrics(let table):
            let headers = ReportCopy.Validation.metricHeaders
            let fractions: [CGFloat] = [0.19, 0.14, 0.18, 0.34, 0.15]
            let firstRow = table.rows.first.map { [$0.metric, $0.category, $0.target, $0.measurement, $0.status] }
            return subsectionTitleHeight(ReportCopy.Validation.metrics)
                + tableRowHeight(headers, fractions: fractions, isHeader: true)
                + min(96, firstRow.map { tableRowHeight($0, fractions: fractions, isHeader: false) } ?? 0)
        case .risks(let table):
            guard let row = table.rows.first else { return subsectionTitleHeight(ReportCopy.Risk.title) }
            let rowHeight = layoutPolicy.riskLayout(for: row) == .detailed
                ? riskStructuredRowHeight(risk: row.risk, fields: row.availableDetails)
                : compactRiskRowHeight(risk: row.risk, fields: row.availableDetails)
            return subsectionTitleHeight(ReportCopy.Risk.title) + min(140, rowHeight)
        case .pendingNote(let note):
            return calloutLayoutHeight(title: note.title, body: note.body ?? ReportCopy.pending)
                ?? compactEntryLeadingHeight(label: note.title, value: note.body ?? ReportCopy.pending)
        }
    }

    private func drawCompactBlock(_ block: ReportBlock) {
        switch block {
        case .keyValues(let items):
            drawKeyValueGroup(items)
        case .fieldGroup(let group):
            let firstItem = group.items.first
            drawSubsectionTitle(
                group.title,
                keepWithNext: firstItem.map { compactEntryLeadingHeight(label: $0.label, value: $0.value) } ?? 0
            )
            for item in group.items {
                drawCompactEntry(label: item.label, value: item.value)
            }
        case .twoColumn(let left, let right):
            drawTwoColumn(left: left, right: right)
        case .bulletList(let list):
            drawCompactList(title: list.title, items: list.items)
        case .flow(let flow):
            if layoutPolicy.flowLayout(for: flow) == .horizontal {
                drawHorizontalFlow(flow)
                return
            }
            let firstStep = flow.steps.first
            drawSubsectionTitle(
                ReportCopy.Flow.title,
                keepWithNext: firstStep.map {
                    compactEntryLeadingHeight(label: "1. \($0.actor.displayLabel)", value: $0.text)
                } ?? 0
            )
            for (index, step) in flow.steps.enumerated() {
                let confirmation = step.isConfirmation ? " · \(ReportCopy.Flow.finalConfirmation)" : ""
                drawCompactEntry(
                    label: "\(index + 1). \(step.actor.displayLabel)\(confirmation)",
                    value: step.text
                )
            }
        case .callout(let callout):
            drawCallout(title: callout.title, body: callout.body)
        case .metrics(let table):
            drawMetricsTable(table)
        case .risks(let table):
            drawRisksTable(table)
        case .pendingNote(let note):
            drawPendingNote(note)
        }
    }

    private func drawKeyValueGroup(_ items: [ReportKeyValue]) {
        guard !items.isEmpty else { return }
        guard keyValueGroupHeight(items) != nil else {
            for item in items {
                drawCompactEntry(label: item.label, value: item.value)
            }
            return
        }

        var gridItems = items
        if items.first?.label == "一句话方案", let first = items.first {
            drawCompactEntry(label: first.label, value: first.value)
            gridItems.removeFirst()
        }

        let gap = PDFVisualSystem.Space.xl
        let cellWidth = (contentWidth - gap) / 2
        var index = 0
        while index < gridItems.count {
            let row = Array(gridItems[index..<min(index + 2, gridItems.count)])
            let rowHeight = row.map {
                compactEntryMeasuredHeight(label: $0.label, value: $0.value, width: cellWidth)
            }.max() ?? 0
            ensureSpace(rowHeight)

            for (column, item) in row.enumerated() {
                drawKeyValueCell(
                    label: item.label,
                    value: item.value,
                    rect: CGRect(
                        x: margin + CGFloat(column) * (cellWidth + gap),
                        y: currentY,
                        width: cellWidth,
                        height: rowHeight
                    )
                )
            }
            currentY += rowHeight
            index += 2
        }
    }

    private func drawKeyValueCell(label: String, value: String, rect: CGRect) {
        let labelHeight = measureText(
            label,
            width: rect.width,
            font: PDFVisualSystem.Typography.keyLabel,
            lineSpacing: PDFVisualSystem.Typography.labelSpacing
        )
        _ = drawText(
            label,
            in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: labelHeight + 2),
            font: PDFVisualSystem.Typography.keyLabel,
            color: PDFVisualSystem.Color.textPrimary,
            lineSpacing: PDFVisualSystem.Typography.labelSpacing
        )
        _ = drawText(
            value,
            in: CGRect(
                x: rect.minX,
                y: rect.minY + labelHeight + PDFVisualSystem.Space.xs,
                width: rect.width,
                height: rect.height - labelHeight - PDFVisualSystem.Space.md
            ),
            font: PDFVisualSystem.Typography.body,
            color: PDFVisualSystem.Color.textSecondary,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        )
        drawRule(
            from: CGPoint(x: rect.minX, y: rect.maxY - PDFVisualSystem.Space.xs),
            to: CGPoint(x: rect.maxX, y: rect.maxY - PDFVisualSystem.Space.xs),
            color: PDFVisualSystem.Color.border,
            width: 0.5
        )
    }

    private func twoColumnLayoutHeight(left: ReportColumn, right: ReportColumn) -> CGFloat? {
        let gap = PDFVisualSystem.Space.lg
        let columnWidth = (contentWidth - gap) / 2
        let innerWidth = columnWidth - PDFVisualSystem.Space.lg * 2
        let heights = [left, right].map { column in
            let titleHeight = measureText(
                column.title,
                width: innerWidth,
                font: PDFVisualSystem.Typography.h2,
                lineSpacing: PDFVisualSystem.Typography.h2Spacing
            )
            let itemsHeight = column.items.reduce(CGFloat.zero) { partial, item in
                partial + bulletItemHeight(item, width: innerWidth)
            }
            return PDFVisualSystem.Space.lg + titleHeight + PDFVisualSystem.Space.md
                + itemsHeight + PDFVisualSystem.Space.md
        }
        let height = heights.max() ?? 0
        return height <= min(300, pageBodyHeight * 0.45) ? height + PDFVisualSystem.Space.md : nil
    }

    private func drawTwoColumn(left: ReportColumn, right: ReportColumn) {
        guard let height = twoColumnLayoutHeight(left: left, right: right) else {
            drawCompactList(title: left.title, items: left.items)
            drawCompactList(title: right.title, items: right.items)
            return
        }
        ensureSpace(height)

        let gap = PDFVisualSystem.Space.lg
        let columnWidth = (contentWidth - gap) / 2
        let panelHeight = height - PDFVisualSystem.Space.md
        drawScopeColumn(
            left,
            rect: CGRect(x: margin, y: currentY, width: columnWidth, height: panelHeight),
            accent: PDFVisualSystem.Color.statusGreen,
            accentFill: PDFVisualSystem.Color.statusGreenBackground
        )
        drawScopeColumn(
            right,
            rect: CGRect(x: margin + columnWidth + gap, y: currentY, width: columnWidth, height: panelHeight),
            accent: PDFVisualSystem.Color.statusRed,
            accentFill: PDFVisualSystem.Color.statusRedBackground
        )
        currentY += height
    }

    private func drawScopeColumn(
        _ column: ReportColumn,
        rect: CGRect,
        accent: UIColor,
        accentFill: UIColor
    ) {
        drawRoundedRect(
            rect,
            radius: PDFVisualSystem.Radius.table,
            fill: PDFVisualSystem.Color.surface,
            stroke: PDFVisualSystem.Color.border,
            lineWidth: 0.5
        )
        let strip = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 3)
        accentFill.setFill()
        UIBezierPath(
            roundedRect: strip,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: PDFVisualSystem.Radius.table, height: PDFVisualSystem.Radius.table)
        ).fill()

        let innerX = rect.minX + PDFVisualSystem.Space.lg
        let innerWidth = rect.width - PDFVisualSystem.Space.lg * 2
        let titleY = rect.minY + PDFVisualSystem.Space.lg
        let titleHeight = measureText(
            column.title,
            width: innerWidth,
            font: PDFVisualSystem.Typography.h2,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )
        _ = drawText(
            column.title,
            in: CGRect(x: innerX, y: titleY, width: innerWidth, height: titleHeight + 2),
            font: PDFVisualSystem.Typography.h2,
            color: accent,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )

        var itemY = titleY + titleHeight + PDFVisualSystem.Space.md
        for item in column.items {
            let itemHeight = bulletItemHeight(item, width: innerWidth)
            drawBulletText(item, x: innerX, y: itemY, width: innerWidth, color: PDFVisualSystem.Color.textSecondary)
            itemY += itemHeight
        }
    }

    private func calloutLayoutHeight(title: String, body: String) -> CGFloat? {
        let innerWidth = contentWidth - PDFVisualSystem.Space.xl * 2
        let height = PDFVisualSystem.Space.md
            + measureText(title, width: innerWidth, font: PDFVisualSystem.Typography.h2, lineSpacing: PDFVisualSystem.Typography.h2Spacing)
            + PDFVisualSystem.Space.xs
            + measureText(body, width: innerWidth, font: PDFVisualSystem.Typography.body, lineSpacing: PDFVisualSystem.Typography.bodySpacing)
            + PDFVisualSystem.Space.md
        return height <= min(168, pageBodyHeight * 0.25) ? height : nil
    }

    private func drawCallout(title: String, body: String) {
        guard let height = calloutLayoutHeight(title: title, body: body) else {
            drawCompactEntry(label: title, value: body)
            return
        }
        ensureSpace(height + PDFVisualSystem.Space.sm)
        let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
        let accent = title.contains("约束")
            ? PDFVisualSystem.Color.statusYellow
            : PDFVisualSystem.Color.primary

        if let cgContext = context?.cgContext {
            cgContext.saveGState()
            cgContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 4,
                color: UIColor.black.withAlphaComponent(0.06).cgColor
            )
            drawRoundedRect(
                rect,
                radius: PDFVisualSystem.Radius.callout,
                fill: PDFVisualSystem.Color.surface,
                stroke: PDFVisualSystem.Color.border,
                lineWidth: 0.5
            )
            cgContext.restoreGState()
        }

        accent.setFill()
        UIBezierPath(
            roundedRect: CGRect(
                x: rect.minX,
                y: rect.minY + PDFVisualSystem.Space.sm,
                width: 3,
                height: rect.height - PDFVisualSystem.Space.lg
            ),
            cornerRadius: 1.5
        ).fill()

        let innerX = rect.minX + PDFVisualSystem.Space.xl
        let innerWidth = rect.width - PDFVisualSystem.Space.xl * 2
        let titleY = rect.minY + PDFVisualSystem.Space.md
        let titleHeight = measureText(title, width: innerWidth, font: PDFVisualSystem.Typography.h2, lineSpacing: PDFVisualSystem.Typography.h2Spacing)
        _ = drawText(
            title,
            in: CGRect(x: innerX, y: titleY, width: innerWidth, height: titleHeight + 2),
            font: PDFVisualSystem.Typography.h2,
            color: accent,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )
        _ = drawText(
            body,
            in: CGRect(
                x: innerX,
                y: titleY + titleHeight + PDFVisualSystem.Space.xs,
                width: innerWidth,
                height: rect.maxY - titleY - titleHeight - PDFVisualSystem.Space.md
            ),
            font: PDFVisualSystem.Typography.body,
            color: PDFVisualSystem.Color.textSecondary,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        )
        currentY += height + PDFVisualSystem.Space.sm
    }

    private func drawPendingNote(_ note: ReportPendingNote) {
        let body = note.body ?? ReportCopy.pending
        let innerWidth = contentWidth - PDFVisualSystem.Space.xl * 2
        let titleHeight = measureText(
            note.title,
            width: innerWidth,
            font: PDFVisualSystem.Typography.h2,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )
        let bodyHeight = note.body.map {
            measureText(
                $0,
                width: innerWidth,
                font: PDFVisualSystem.Typography.body,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            ) + PDFVisualSystem.Space.xs
        } ?? 0
        let height = PDFVisualSystem.Space.md * 2 + titleHeight + bodyHeight
        ensureSpace(height + PDFVisualSystem.Space.sm)
        let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
        drawRoundedRect(
            rect,
            radius: PDFVisualSystem.Radius.table,
            fill: PDFVisualSystem.Color.statusYellowBackground,
            stroke: PDFVisualSystem.Color.border,
            lineWidth: 0.5
        )
        _ = drawText(
            note.title,
            in: CGRect(
                x: rect.minX + PDFVisualSystem.Space.xl,
                y: rect.minY + PDFVisualSystem.Space.md,
                width: innerWidth,
                height: titleHeight + 2
            ),
            font: PDFVisualSystem.Typography.h2,
            color: PDFVisualSystem.Color.statusYellow,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )
        if note.body != nil {
            _ = drawText(
                body,
                in: CGRect(
                    x: rect.minX + PDFVisualSystem.Space.xl,
                    y: rect.minY + PDFVisualSystem.Space.md + titleHeight + PDFVisualSystem.Space.xs,
                    width: innerWidth,
                    height: bodyHeight + 2
                ),
                font: PDFVisualSystem.Typography.body,
                color: PDFVisualSystem.Color.textSecondary,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            )
        }
        currentY += height + PDFVisualSystem.Space.sm
    }

    private func horizontalFlowHeight(_ flow: ReportFlow) -> CGFloat {
        let gap: CGFloat = 18
        let count = max(1, flow.steps.count)
        let stepWidth = (contentWidth - CGFloat(count - 1) * gap) / CGFloat(count)
        let innerWidth = stepWidth - PDFVisualSystem.Space.lg * 2
        let stepHeights = flow.steps.map { step in
            measureText(
                step.actor.displayLabel,
                width: innerWidth,
                font: PDFVisualSystem.Typography.keyLabel,
                lineSpacing: PDFVisualSystem.Typography.labelSpacing
            ) + PDFVisualSystem.Space.xs + measureText(
                step.text,
                width: innerWidth,
                font: PDFVisualSystem.Typography.body,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            ) + PDFVisualSystem.Space.lg * 2
        }
        return (stepHeights.max() ?? 0) + PDFVisualSystem.Space.md
    }

    private func drawHorizontalFlow(_ flow: ReportFlow) {
        let flowHeight = horizontalFlowHeight(flow)
        drawSubsectionTitle(ReportCopy.Flow.title, keepWithNext: flowHeight)
        ensureSpace(flowHeight)

        let gap: CGFloat = 18
        let count = max(1, flow.steps.count)
        let stepWidth = (contentWidth - CGFloat(count - 1) * gap) / CGFloat(count)
        let cardHeight = flowHeight - PDFVisualSystem.Space.md
        for (index, step) in flow.steps.enumerated() {
            let x = margin + CGFloat(index) * (stepWidth + gap)
            let rect = CGRect(x: x, y: currentY, width: stepWidth, height: cardHeight)
            let style = flowStyle(for: step.actor)
            drawRoundedRect(
                rect,
                radius: PDFVisualSystem.Radius.table,
                fill: style.fill,
                stroke: style.stroke,
                lineWidth: step.actor == .humanInTheLoop ? 0.75 : 0.5
            )
            let inner = rect.insetBy(dx: PDFVisualSystem.Space.lg, dy: PDFVisualSystem.Space.lg)
            let label = "\(index + 1). \(step.actor.displayLabel)"
            let labelHeight = measureText(
                label,
                width: inner.width,
                font: PDFVisualSystem.Typography.keyLabel,
                lineSpacing: PDFVisualSystem.Typography.labelSpacing
            )
            _ = drawText(
                label,
                in: CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: labelHeight + 2),
                font: PDFVisualSystem.Typography.keyLabel,
                color: style.text,
                lineSpacing: PDFVisualSystem.Typography.labelSpacing
            )
            _ = drawText(
                step.text,
                in: CGRect(
                    x: inner.minX,
                    y: inner.minY + labelHeight + PDFVisualSystem.Space.xs,
                    width: inner.width,
                    height: inner.height - labelHeight - PDFVisualSystem.Space.xs
                ),
                font: PDFVisualSystem.Typography.body,
                color: PDFVisualSystem.Color.textPrimary,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            )
            if index < flow.steps.count - 1 {
                _ = drawText(
                    "→",
                    in: CGRect(x: rect.maxX, y: rect.midY - 8, width: gap, height: 16),
                    font: PDFVisualSystem.Typography.h2,
                    color: PDFVisualSystem.Color.caption,
                    alignment: .center
                )
            }
        }
        currentY += flowHeight
    }

    private func flowStyle(for actor: ReportFlowActor) -> (text: UIColor, fill: UIColor, stroke: UIColor) {
        switch actor {
        case .user:
            return (PDFVisualSystem.Color.primary, PDFVisualSystem.Color.primarySoft, PDFVisualSystem.Color.border)
        case .ai:
            return (PDFVisualSystem.Color.primary, PDFVisualSystem.Color.primarySoft, PDFVisualSystem.Color.primary)
        case .system:
            return (PDFVisualSystem.Color.textSecondary, PDFVisualSystem.Color.secondaryBackground, PDFVisualSystem.Color.border)
        case .humanInTheLoop:
            return (PDFVisualSystem.Color.statusRed, PDFVisualSystem.Color.statusRedBackground, PDFVisualSystem.Color.statusRed)
        case .unspecified:
            return (PDFVisualSystem.Color.textSecondary, PDFVisualSystem.Color.surface, PDFVisualSystem.Color.border)
        }
    }

    private func drawMetricsTable(_ table: ReportMetricsTable) {
        let title = ReportCopy.Validation.metrics
        let headers = ReportCopy.Validation.metricHeaders
        let fractions: [CGFloat] = [0.19, 0.14, 0.18, 0.34, 0.15]
        let firstValues = table.rows.first.map { [$0.metric, $0.category, $0.target, $0.measurement, $0.status] }
        let headerHeight = tableRowHeight(headers, fractions: fractions, isHeader: true)
        let firstRowHeight = firstValues.map {
            min(96, tableRowHeight($0, fractions: fractions, isHeader: false))
        } ?? 0

        drawSubsectionTitle(title, keepWithNext: headerHeight + firstRowHeight)
        drawTableRow(headers, fractions: fractions, isHeader: true)
        for row in table.rows {
            let values = [row.metric, row.category, row.target, row.measurement, row.status]
            drawMetricRowPaginated(
                values,
                title: title,
                headers: headers,
                fractions: fractions
            )
        }
        currentY += min(PDFVisualSystem.Space.md, remainingHeight)
    }

    private func drawMetricRowPaginated(
        _ values: [String],
        title: String,
        headers: [String],
        fractions: [CGFloat]
    ) {
        var pending = values
        var didSplit = false
        let headerHeight = tableRowHeight(headers, fractions: fractions, isHeader: true)
        let continuationTitleHeight = subsectionTitleHeight(ReportCopy.Validation.metricsContinuation)
        let freshPageCapacity = pageBodyHeight - continuationTitleHeight - headerHeight

        while pending.contains(where: { !$0.isEmpty }) {
            let fullHeight = tableRowHeight(pending, fractions: fractions, isHeader: false)
            if fullHeight <= remainingHeight {
                drawTableRow(pending, fractions: fractions, isHeader: false)
                pending = Array(repeating: "", count: pending.count)
                continue
            }

            if fullHeight <= freshPageCapacity {
                beginTableContinuation(title: title, headers: headers, fractions: fractions)
                drawTableRow(pending, fractions: fractions, isHeader: false)
                pending = Array(repeating: "", count: pending.count)
                continue
            }

            if remainingHeight < PDFVisualSystem.Table.minimumRowHeight + PDFVisualSystem.Space.lg {
                beginTableContinuation(title: title, headers: headers, fractions: fractions)
            }

            // fittingTextPrefix measures glyph bounds only; reserve the exact row
            // padding so drawTableRow never moves an otherwise valid fragment to a
            // fresh page and leaves a continuation header behind by itself.
            let maxTextHeight = max(
                18,
                remainingHeight - PDFVisualSystem.Table.verticalPadding * 2 - 2
            )
            var fragments: [String] = []
            var remainders: [String] = []
            for (value, fraction) in zip(pending, fractions) {
                let fragment = fittingTextPrefix(
                    value,
                    width: contentWidth * fraction - PDFVisualSystem.Table.horizontalPadding * 2,
                    font: PDFVisualSystem.Typography.tableBody,
                    lineSpacing: PDFVisualSystem.Typography.tableSpacing,
                    maxHeight: maxTextHeight
                )
                fragments.append(fragment.prefix)
                remainders.append(fragment.remainder)
            }
            drawTableRow(fragments, fractions: fractions, isHeader: false)
            pending = remainders

            if pending.contains(where: { !$0.isEmpty }) {
                didSplit = true
                beginTableContinuation(title: title, headers: headers, fractions: fractions)
            }
        }

        if didSplit {
            splitTextBlockCount += 1
        }
    }

    private func beginTableContinuation(
        title: String,
        headers: [String],
        fractions: [CGFloat]
    ) {
        beginPage()
        let headerHeight = tableRowHeight(headers, fractions: fractions, isHeader: true)
        drawSubsectionTitle(ReportCopy.Validation.metricsContinuation, keepWithNext: headerHeight)
        drawTableRow(headers, fractions: fractions, isHeader: true)
        repeatedTableHeaderCount += 1
    }

    private func drawRisksTable(_ table: ReportRisksTable) {
        let title = ReportCopy.Risk.title
        let firstRowHeight = table.rows.first.map { row in
            let riskValue = riskDisplayValue(row)
            let height = layoutPolicy.riskLayout(for: row) == .detailed
                ? riskStructuredRowHeight(risk: riskValue, fields: row.availableDetails)
                : compactRiskRowHeight(risk: riskValue, fields: row.availableDetails)
            return min(160, height)
        } ?? 0
        drawSubsectionTitle(title, keepWithNext: firstRowHeight)

        for (index, row) in table.rows.enumerated() {
            let fieldValues = row.availableDetails
            let riskValue = riskDisplayValue(row)
            let isDetailed = layoutPolicy.riskLayout(for: row) == .detailed
            let rowHeight = isDetailed
                ? riskStructuredRowHeight(risk: riskValue, fields: fieldValues)
                : compactRiskRowHeight(risk: riskValue, fields: fieldValues)
            let smallBlockLimit = min(220, pageBodyHeight * 0.36)

            if rowHeight <= smallBlockLimit {
                if index == table.rows.count - 2 {
                    let nextRow = table.rows[index + 1]
                    let nextRiskValue = riskDisplayValue(nextRow)
                    let nextHeight = layoutPolicy.riskLayout(for: nextRow) == .detailed
                        ? riskStructuredRowHeight(risk: nextRiskValue, fields: nextRow.availableDetails)
                        : compactRiskRowHeight(risk: nextRiskValue, fields: nextRow.availableDetails)
                    let pairHeight = rowHeight + nextHeight
                    let continuationHeight = subsectionTitleHeight(ReportCopy.Risk.continuation)
                    if rowHeight <= remainingHeight,
                       pairHeight > remainingHeight,
                       pairHeight + continuationHeight <= pageBodyHeight,
                       !isAtPageTop {
                        beginPage()
                        drawSubsectionTitle(ReportCopy.Risk.continuation, keepWithNext: min(140, rowHeight))
                    }
                }
                if rowHeight > remainingHeight {
                    beginPage()
                    drawSubsectionTitle(ReportCopy.Risk.continuation, keepWithNext: min(140, rowHeight))
                }
                if isDetailed {
                    drawRiskStructuredRow(risk: riskValue, fields: fieldValues)
                } else {
                    drawCompactRiskRow(risk: riskValue, fields: fieldValues)
                }
            } else {
                drawCompactEntry(label: ReportCopy.Risk.risk, value: riskValue)
                for (fieldIndex, field) in fieldValues.enumerated() {
                    var trailingKeepHeight: CGFloat = 0
                    if fieldIndex == fieldValues.count - 2,
                       let finalField = fieldValues.last {
                        let finalFieldHeight = compactEntryMeasuredHeight(
                            label: finalField.0,
                            value: finalField.1,
                            width: contentWidth
                        )
                        if finalFieldHeight <= min(180, pageBodyHeight * 0.30) {
                            trailingKeepHeight = finalFieldHeight
                        }
                    }
                    drawCompactEntry(
                        label: field.0,
                        value: field.1,
                        trailingKeepHeight: trailingKeepHeight
                    )
                }
            }
        }
    }

    private func riskDisplayValue(_ row: ReportRiskRow) -> String {
        let priority = [
            row.probability.map { "\(ReportCopy.Risk.probability) \($0)/5" },
            row.impact.map { "\(ReportCopy.Risk.impact) \($0)/5" },
        ].compactMap { $0 }.joined(separator: " · ")
        return priority.isEmpty ? row.risk : "\(row.risk)（\(priority)）"
    }

    private func compactRiskRowHeight(risk: String, fields: [(String, String)]) -> CGFloat {
        if fields.isEmpty {
            let textWidth = contentWidth - PDFVisualSystem.Space.xl * 2
            let contentHeight = measureText(
                ReportCopy.Risk.risk,
                width: textWidth,
                font: PDFVisualSystem.Typography.tableLabel,
                lineSpacing: PDFVisualSystem.Typography.metadataSpacing
            ) + PDFVisualSystem.Space.xs + measureText(
                risk,
                width: textWidth,
                font: PDFVisualSystem.Typography.tableEmphasis,
                lineSpacing: PDFVisualSystem.Typography.tableSpacing
            )
            return contentHeight + PDFVisualSystem.Space.xl * 2 + PDFVisualSystem.Space.md
        }

        let gap = PDFVisualSystem.Space.lg
        let leftWidth = contentWidth * 0.42 - PDFVisualSystem.Space.xl * 2
        let rightWidth = contentWidth * 0.58 - gap - PDFVisualSystem.Space.xl * 2
        let leftHeight = measureText(
            ReportCopy.Risk.risk,
            width: leftWidth,
            font: PDFVisualSystem.Typography.tableLabel,
            lineSpacing: PDFVisualSystem.Typography.metadataSpacing
        ) + PDFVisualSystem.Space.xs + measureText(
            risk,
            width: leftWidth,
            font: PDFVisualSystem.Typography.tableEmphasis,
            lineSpacing: PDFVisualSystem.Typography.tableSpacing
        )
        let rightHeight = fields.reduce(CGFloat.zero) { result, field in
            result + measureText(
                field.0,
                width: rightWidth,
                font: PDFVisualSystem.Typography.tableLabel,
                lineSpacing: PDFVisualSystem.Typography.metadataSpacing
            ) + PDFVisualSystem.Space.xs + measureText(
                field.1,
                width: rightWidth,
                font: PDFVisualSystem.Typography.tableBody,
                lineSpacing: PDFVisualSystem.Typography.tableSpacing
            ) + PDFVisualSystem.Space.sm
        }
        return max(leftHeight, rightHeight) + PDFVisualSystem.Space.xl * 2 + PDFVisualSystem.Space.md
    }

    private func drawCompactRiskRow(risk: String, fields: [(String, String)]) {
        let totalHeight = compactRiskRowHeight(risk: risk, fields: fields)
        let cardHeight = totalHeight - PDFVisualSystem.Space.md
        let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: cardHeight)
        drawRoundedRect(
            rect,
            radius: PDFVisualSystem.Radius.table,
            fill: PDFVisualSystem.Color.surface,
            stroke: PDFVisualSystem.Color.border,
            lineWidth: 0.5
        )
        PDFVisualSystem.Color.statusRed.setFill()
        UIBezierPath(
            roundedRect: CGRect(x: rect.minX, y: rect.minY + PDFVisualSystem.Space.sm, width: 3, height: rect.height - PDFVisualSystem.Space.lg),
            cornerRadius: 1.5
        ).fill()

        let gap = PDFVisualSystem.Space.lg
        let leftOuterWidth = fields.isEmpty ? contentWidth : contentWidth * 0.42
        let leftRect = CGRect(
            x: rect.minX + PDFVisualSystem.Space.xl,
            y: rect.minY + PDFVisualSystem.Space.xl,
            width: leftOuterWidth - PDFVisualSystem.Space.xl * 2,
            height: rect.height - PDFVisualSystem.Space.xl * 2
        )
        let riskLabelHeight = measureText(
            ReportCopy.Risk.risk,
            width: leftRect.width,
            font: PDFVisualSystem.Typography.tableLabel,
            lineSpacing: PDFVisualSystem.Typography.metadataSpacing
        )
        _ = drawText(
            ReportCopy.Risk.risk,
            in: CGRect(x: leftRect.minX, y: leftRect.minY, width: leftRect.width, height: riskLabelHeight + 2),
            font: PDFVisualSystem.Typography.tableLabel,
            color: PDFVisualSystem.Color.statusRed,
            lineSpacing: PDFVisualSystem.Typography.metadataSpacing
        )
        _ = drawText(
            risk,
            in: CGRect(
                x: leftRect.minX,
                y: leftRect.minY + riskLabelHeight + PDFVisualSystem.Space.xs,
                width: leftRect.width,
                height: leftRect.height - riskLabelHeight - PDFVisualSystem.Space.xs
            ),
            font: PDFVisualSystem.Typography.tableEmphasis,
            color: PDFVisualSystem.Color.textPrimary,
            lineSpacing: PDFVisualSystem.Typography.tableSpacing
        )

        guard !fields.isEmpty else {
            currentY += totalHeight
            return
        }

        let dividerX = rect.minX + leftOuterWidth
        drawRule(
            from: CGPoint(x: dividerX, y: rect.minY + PDFVisualSystem.Space.lg),
            to: CGPoint(x: dividerX, y: rect.maxY - PDFVisualSystem.Space.lg),
            color: PDFVisualSystem.Color.border,
            width: 0.5
        )
        let rightX = dividerX + gap
        let rightWidth = rect.maxX - PDFVisualSystem.Space.xl - rightX
        var fieldY = rect.minY + PDFVisualSystem.Space.xl
        for field in fields {
            let labelHeight = measureText(
                field.0,
                width: rightWidth,
                font: PDFVisualSystem.Typography.tableLabel,
                lineSpacing: PDFVisualSystem.Typography.metadataSpacing
            )
            let valueHeight = measureText(
                field.1,
                width: rightWidth,
                font: PDFVisualSystem.Typography.tableBody,
                lineSpacing: PDFVisualSystem.Typography.tableSpacing
            )
            _ = drawText(
                field.0,
                in: CGRect(x: rightX, y: fieldY, width: rightWidth, height: labelHeight + 2),
                font: PDFVisualSystem.Typography.tableLabel,
                color: PDFVisualSystem.Color.textPrimary,
                lineSpacing: PDFVisualSystem.Typography.metadataSpacing
            )
            fieldY += labelHeight + PDFVisualSystem.Space.xs
            _ = drawText(
                field.1,
                in: CGRect(x: rightX, y: fieldY, width: rightWidth, height: valueHeight + 2),
                font: PDFVisualSystem.Typography.tableBody,
                color: PDFVisualSystem.Color.textSecondary,
                lineSpacing: PDFVisualSystem.Typography.tableSpacing
            )
            fieldY += valueHeight + PDFVisualSystem.Space.sm
        }
        currentY += totalHeight
    }

    private func tableRowHeight(
        _ values: [String],
        fractions: [CGFloat],
        isHeader: Bool
    ) -> CGFloat {
        let font = isHeader ? PDFVisualSystem.Typography.tableHeader : PDFVisualSystem.Typography.tableBody
        let heights = zip(values, fractions).map { value, fraction in
            measureText(
                value,
                width: contentWidth * fraction - PDFVisualSystem.Table.horizontalPadding * 2,
                font: font,
                lineSpacing: PDFVisualSystem.Typography.tableSpacing
            ) + PDFVisualSystem.Table.verticalPadding * 2
        }
        return max(isHeader ? PDFVisualSystem.Table.minimumHeaderHeight : PDFVisualSystem.Table.minimumRowHeight, heights.max() ?? 0)
    }

    private func drawTableRow(
        _ values: [String],
        fractions: [CGFloat],
        isHeader: Bool
    ) {
        let height = tableRowHeight(values, fractions: fractions, isHeader: isHeader)
        ensureSpace(height)
        if isHeader {
            drawTableHeaderRow(values, fractions: fractions, height: height)
            currentY += height
            return
        }

        var x = margin
        for (index, value) in values.enumerated() {
            let width = contentWidth * fractions[index]
            let rect = CGRect(x: x, y: currentY, width: width, height: height)
            let statusStyle = index == values.count - 1 ? statusStyle(for: value) : nil
            drawTableCell(
                value,
                rect: rect,
                font: PDFVisualSystem.Typography.tableBody,
                color: statusStyle?.text ?? PDFVisualSystem.Color.textSecondary,
                fill: statusStyle?.fill ?? PDFVisualSystem.Color.surface
            )
            x += width
        }
        currentY += height
    }

    private func drawTableHeaderRow(
        _ values: [String],
        fractions: [CGFloat],
        height: CGFloat
    ) {
        let rowRect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
        drawRoundedRect(
            rowRect,
            radius: PDFVisualSystem.Radius.table,
            fill: PDFVisualSystem.Color.tableHeader,
            stroke: PDFVisualSystem.Color.border,
            lineWidth: PDFVisualSystem.Table.borderWidth
        )

        var x = margin
        for (index, value) in values.enumerated() {
            let width = contentWidth * fractions[index]
            if index > 0 {
                drawRule(
                    from: CGPoint(x: x, y: currentY),
                    to: CGPoint(x: x, y: currentY + height),
                    color: PDFVisualSystem.Color.border,
                    width: PDFVisualSystem.Table.borderWidth
                )
            }
            _ = drawText(
                value,
                in: CGRect(x: x, y: currentY, width: width, height: height)
                    .insetBy(dx: PDFVisualSystem.Table.horizontalPadding, dy: PDFVisualSystem.Table.verticalPadding),
                font: PDFVisualSystem.Typography.tableHeader,
                color: PDFVisualSystem.Color.textPrimary,
                lineSpacing: PDFVisualSystem.Typography.tableSpacing
            )
            x += width
        }
    }

    private func statusStyle(for value: String) -> (text: UIColor, fill: UIColor)? {
        let normalized = value.lowercased()
        if normalized.contains("通过") || normalized.contains("完成") || normalized.contains("validated") {
            return (PDFVisualSystem.Color.statusGreen, PDFVisualSystem.Color.statusGreenBackground)
        }
        if normalized.contains("失败") || normalized.contains("阻塞") || normalized.contains("failed") {
            return (PDFVisualSystem.Color.statusRed, PDFVisualSystem.Color.statusRedBackground)
        }
        if normalized.contains("待") || normalized.contains("pending") {
            return (PDFVisualSystem.Color.statusYellow, PDFVisualSystem.Color.statusYellowBackground)
        }
        return nil
    }

    private func riskStructuredRowHeight(
        risk: String,
        fields: [(String, String)]
    ) -> CGFloat {
        let riskHeight = max(
            34,
            measureText(
                risk,
                width: contentWidth - 88,
                font: PDFVisualSystem.Typography.tableEmphasis,
                lineSpacing: PDFVisualSystem.Typography.tableSpacing
            ) + PDFVisualSystem.Table.verticalPadding * 2
        )
        let cellWidth = contentWidth / CGFloat(fields.count)
        let fieldHeight = fields.map { label, value in
            let labelHeight = measureText(
                label,
                width: cellWidth - PDFVisualSystem.Table.horizontalPadding * 2,
                font: PDFVisualSystem.Typography.tableLabel,
                lineSpacing: PDFVisualSystem.Typography.metadataSpacing
            )
            let valueHeight = measureText(
                value,
                width: cellWidth - PDFVisualSystem.Table.horizontalPadding * 2,
                font: PDFVisualSystem.Typography.tableBody,
                lineSpacing: PDFVisualSystem.Typography.tableSpacing
            )
            return labelHeight + valueHeight + PDFVisualSystem.Space.lg
        }.max() ?? 48
        return riskHeight + max(48, fieldHeight) + PDFVisualSystem.Space.md
    }

    private func drawRiskStructuredRow(
        risk: String,
        fields: [(String, String)]
    ) {
        let totalHeight = riskStructuredRowHeight(risk: risk, fields: fields)
        let contentHeight = totalHeight - PDFVisualSystem.Space.md
        let riskHeight = max(
            34,
            measureText(
                risk,
                width: contentWidth - 88,
                font: PDFVisualSystem.Typography.tableEmphasis,
                lineSpacing: PDFVisualSystem.Typography.tableSpacing
            ) + PDFVisualSystem.Table.verticalPadding * 2
        )

        drawTableCell(
            ReportCopy.Risk.risk,
            rect: CGRect(x: margin, y: currentY, width: 76, height: riskHeight),
            font: PDFVisualSystem.Typography.tableLabel,
            color: PDFVisualSystem.Color.statusRed,
            fill: PDFVisualSystem.Color.statusRedBackground
        )
        drawTableCell(
            risk,
            rect: CGRect(x: margin + 76, y: currentY, width: contentWidth - 76, height: riskHeight),
            font: PDFVisualSystem.Typography.tableEmphasis,
            color: PDFVisualSystem.Color.textPrimary,
            fill: PDFVisualSystem.Color.surface
        )
        currentY += riskHeight

        let fieldHeight = contentHeight - riskHeight
        let fieldWidth = contentWidth / CGFloat(fields.count)
        for (index, field) in fields.enumerated() {
            let rect = CGRect(
                x: margin + CGFloat(index) * fieldWidth,
                y: currentY,
                width: fieldWidth,
                height: fieldHeight
            )
            drawLabeledTableCell(label: field.0, value: field.1, rect: rect)
        }
        currentY += fieldHeight + PDFVisualSystem.Space.md
    }

    private func drawLabeledTableCell(label: String, value: String, rect: CGRect) {
        drawTableBackground(rect, fill: PDFVisualSystem.Color.surface)
        let labelHeight = measureText(
            label,
            width: rect.width - PDFVisualSystem.Table.horizontalPadding * 2,
            font: PDFVisualSystem.Typography.tableLabel,
            lineSpacing: PDFVisualSystem.Typography.metadataSpacing
        )
        _ = drawText(
            label,
            in: CGRect(
                x: rect.minX + PDFVisualSystem.Table.horizontalPadding,
                y: rect.minY + PDFVisualSystem.Table.verticalPadding,
                width: rect.width - PDFVisualSystem.Table.horizontalPadding * 2,
                height: labelHeight + 2
            ),
            font: PDFVisualSystem.Typography.tableLabel,
            color: PDFVisualSystem.Color.textPrimary,
            lineSpacing: PDFVisualSystem.Typography.metadataSpacing
        )
        _ = drawText(
            value,
            in: CGRect(
                x: rect.minX + PDFVisualSystem.Table.horizontalPadding,
                y: rect.minY + labelHeight + PDFVisualSystem.Space.md,
                width: rect.width - PDFVisualSystem.Table.horizontalPadding * 2,
                height: rect.height - labelHeight - PDFVisualSystem.Space.lg
            ),
            font: PDFVisualSystem.Typography.tableBody,
            color: PDFVisualSystem.Color.textSecondary,
            lineSpacing: PDFVisualSystem.Typography.tableSpacing
        )
    }

    private func drawTableCell(
        _ text: String,
        rect: CGRect,
        font: UIFont,
        color: UIColor,
        fill: UIColor
    ) {
        drawTableBackground(rect, fill: fill)
        _ = drawText(
            text,
            in: rect.insetBy(
                dx: PDFVisualSystem.Table.horizontalPadding,
                dy: PDFVisualSystem.Table.verticalPadding
            ),
            font: font,
            color: color,
            lineSpacing: PDFVisualSystem.Typography.tableSpacing
        )
    }

    private func drawTableBackground(_ rect: CGRect, fill: UIColor) {
        let path = UIBezierPath(rect: rect)
        fill.setFill()
        path.fill()
        PDFVisualSystem.Color.border.setStroke()
        path.lineWidth = PDFVisualSystem.Table.borderWidth
        path.stroke()
    }

    private func drawCompactList(title: String, items: [String]) {
        drawSubsectionTitle(
            title,
            keepWithNext: items.first.map { min(96, bulletItemHeight($0, width: contentWidth)) } ?? 0
        )
        for item in items {
            drawBulletItem(item)
        }
    }

    private func bulletItemHeight(_ value: String, width: CGFloat) -> CGFloat {
        measureText(
            value,
            width: width - PDFVisualSystem.Space.lg,
            font: PDFVisualSystem.Typography.body,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        ) + PDFVisualSystem.Space.md
    }

    private func drawBulletText(
        _ value: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        color: UIColor
    ) {
        PDFVisualSystem.Color.primary.withAlphaComponent(0.72).setFill()
        UIBezierPath(
            ovalIn: CGRect(x: x, y: y + 5, width: 3.5, height: 3.5)
        ).fill()
        let textHeight = measureText(
            value,
            width: width - PDFVisualSystem.Space.lg,
            font: PDFVisualSystem.Typography.body,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        )
        _ = drawText(
            value,
            in: CGRect(
                x: x + PDFVisualSystem.Space.lg,
                y: y,
                width: width - PDFVisualSystem.Space.lg,
                height: textHeight + 2
            ),
            font: PDFVisualSystem.Typography.body,
            color: color,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        )
    }

    private func drawBulletItem(_ value: String) {
        let textWidth = contentWidth - PDFVisualSystem.Space.lg
        let totalHeight = bulletItemHeight(value, width: contentWidth)
        let smallBlockLimit = min(180, pageBodyHeight * 0.30)
        if totalHeight <= smallBlockLimit {
            ensureSpace(totalHeight)
            drawBulletText(
                value,
                x: margin,
                y: currentY,
                width: contentWidth,
                color: PDFVisualSystem.Color.textSecondary
            )
            currentY += totalHeight
            drawBulletDivider()
            return
        }

        var remainder = value
        var isFirstFragment = true
        var didSplit = false
        while !remainder.isEmpty {
            let minimumLineHeight = measureText(
                "示例文本",
                width: textWidth,
                font: PDFVisualSystem.Typography.body,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            )
            if remainingHeight < minimumLineHeight + PDFVisualSystem.Space.md {
                beginPage()
            }
            let available = max(minimumLineHeight, remainingHeight - PDFVisualSystem.Space.md)
            let fragment = fittingTextPrefix(
                remainder,
                width: textWidth,
                font: PDFVisualSystem.Typography.body,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing,
                maxHeight: available
            )
            let fragmentHeight = measureText(
                fragment.prefix,
                width: textWidth,
                font: PDFVisualSystem.Typography.body,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            )
            if isFirstFragment {
                drawBulletText(
                    fragment.prefix,
                    x: margin,
                    y: currentY,
                    width: contentWidth,
                    color: PDFVisualSystem.Color.textSecondary
                )
            } else {
                _ = drawText(
                    fragment.prefix,
                    in: CGRect(
                        x: margin + PDFVisualSystem.Space.lg,
                        y: currentY,
                        width: textWidth,
                        height: fragmentHeight + 2
                    ),
                    font: PDFVisualSystem.Typography.body,
                    color: PDFVisualSystem.Color.textSecondary,
                    lineSpacing: PDFVisualSystem.Typography.bodySpacing
                )
            }
            currentY += fragmentHeight
            remainder = fragment.remainder
            isFirstFragment = false
            if !remainder.isEmpty {
                didSplit = true
                beginPage()
            }
        }
        if didSplit {
            splitTextBlockCount += 1
        }
        currentY += min(PDFVisualSystem.Space.md, remainingHeight)
        drawBulletDivider()
    }

    private func drawBulletDivider() {
        drawRule(
            from: CGPoint(x: margin + PDFVisualSystem.Space.lg, y: currentY - PDFVisualSystem.Space.xs),
            to: CGPoint(x: margin + contentWidth, y: currentY - PDFVisualSystem.Space.xs),
            color: PDFVisualSystem.Color.border.withAlphaComponent(0.72),
            width: 0.5
        )
    }

    private func drawCompactEntry(
        label: String,
        value: String,
        trailingKeepHeight: CGFloat = 0
    ) {
        let labelFont = PDFVisualSystem.Typography.keyLabel
        let valueFont = PDFVisualSystem.Typography.body
        let labelHeight = measureText(
            label,
            width: contentWidth,
            font: labelFont,
            lineSpacing: PDFVisualSystem.Typography.labelSpacing
        )
        let valueHeight = measureText(
            value,
            width: contentWidth,
            font: valueFont,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        )
        let totalHeight = labelHeight + valueHeight + PDFVisualSystem.Space.lg
        let smallBlockLimit = min(180, pageBodyHeight * 0.30)

        if trailingKeepHeight > 0,
           totalHeight <= smallBlockLimit,
           totalHeight + trailingKeepHeight <= pageBodyHeight,
           totalHeight + trailingKeepHeight > remainingHeight,
           !isAtPageTop {
            beginPage()
        }

        if totalHeight <= smallBlockLimit {
            ensureSpace(totalHeight)
            drawWholeCompactEntry(
                label: label,
                value: value,
                labelFont: labelFont,
                valueFont: valueFont,
                labelHeight: labelHeight,
                valueHeight: valueHeight
            )
            return
        }

        let minimumFragmentHeight = labelHeight
            + measureText(
                "示例文本",
                width: contentWidth,
                font: valueFont,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            ) * 2
            + PDFVisualSystem.Space.lg
        if totalHeight <= pageBodyHeight,
           totalHeight > remainingHeight,
           remainingHeight < minimumFragmentHeight {
            beginPage()
        }
        if totalHeight <= remainingHeight,
           trailingKeepHeight == 0 || totalHeight + trailingKeepHeight <= remainingHeight {
            drawWholeCompactEntry(
                label: label,
                value: value,
                labelFont: labelFont,
                valueFont: valueFont,
                labelHeight: labelHeight,
                valueHeight: valueHeight
            )
            return
        }

        drawSplitCompactEntry(
            label: label,
            value: value,
            labelFont: labelFont,
            valueFont: valueFont,
            trailingKeepHeight: trailingKeepHeight
        )
    }

    private func compactEntryMeasuredHeight(label: String, value: String, width: CGFloat) -> CGFloat {
        measureText(
            label,
            width: width,
            font: PDFVisualSystem.Typography.keyLabel,
            lineSpacing: PDFVisualSystem.Typography.labelSpacing
        ) + measureText(
            value,
            width: width,
            font: PDFVisualSystem.Typography.body,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        ) + PDFVisualSystem.Space.lg
    }

    private func compactEntryLeadingHeight(label: String, value: String) -> CGFloat {
        let labelHeight = measureText(
            label,
            width: contentWidth,
            font: PDFVisualSystem.Typography.keyLabel,
            lineSpacing: PDFVisualSystem.Typography.labelSpacing
        )
        let valueLineHeight = measureText(
            String(value.prefix(24)),
            width: contentWidth,
            font: PDFVisualSystem.Typography.body,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        )
        return min(120, labelHeight + max(16, valueLineHeight) + PDFVisualSystem.Space.lg)
    }

    private func drawWholeCompactEntry(
        label: String,
        value: String,
        labelFont: UIFont,
        valueFont: UIFont,
        labelHeight: CGFloat,
        valueHeight: CGFloat
    ) {
        _ = drawText(
            label,
            in: CGRect(x: margin, y: currentY, width: contentWidth, height: labelHeight + 2),
            font: labelFont,
            color: PDFVisualSystem.Color.textPrimary,
            lineSpacing: PDFVisualSystem.Typography.labelSpacing
        )
        currentY += labelHeight + PDFVisualSystem.Space.xs
        _ = drawText(
            value,
            in: CGRect(x: margin, y: currentY, width: contentWidth, height: valueHeight + 2),
            font: valueFont,
            color: PDFVisualSystem.Color.textSecondary,
            lineSpacing: PDFVisualSystem.Typography.bodySpacing
        )
        currentY += valueHeight + PDFVisualSystem.Space.md
        drawEntryDivider()
    }

    private func drawSplitCompactEntry(
        label: String,
        value: String,
        labelFont: UIFont,
        valueFont: UIFont,
        trailingKeepHeight: CGFloat = 0
    ) {
        var remainder = value
        var isFirstFragment = true
        var didSplit = false

        while !remainder.isEmpty {
            let fragmentLabel = isFirstFragment ? label : "\(label)（续）"
            let labelHeight = measureText(
                fragmentLabel,
                width: contentWidth,
                font: labelFont,
                lineSpacing: PDFVisualSystem.Typography.labelSpacing
            )
            let minimumValueHeight = measureText(
                "示例文本",
                width: contentWidth,
                font: valueFont,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            ) + 2
            if remainingHeight < labelHeight + minimumValueHeight + PDFVisualSystem.Space.lg {
                beginPage()
            }

            _ = drawText(
                fragmentLabel,
                in: CGRect(x: margin, y: currentY, width: contentWidth, height: labelHeight + 2),
                font: labelFont,
                color: PDFVisualSystem.Color.textPrimary,
                lineSpacing: PDFVisualSystem.Typography.labelSpacing
            )
            currentY += labelHeight + PDFVisualSystem.Space.xs

            let available = max(minimumValueHeight, remainingHeight - PDFVisualSystem.Space.md)
            let remainderHeight = measureText(
                remainder,
                width: contentWidth,
                font: valueFont,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            )
            var fragmentMaxHeight = available
            if trailingKeepHeight > 0,
               remainderHeight <= available,
               remainderHeight + trailingKeepHeight > available {
                // Leave a useful tail of the penultimate field with the final short
                // field instead of creating a last page containing only its label/value.
                let usefulTailHeight = max(
                    minimumValueHeight * 4,
                    pageBodyHeight * 0.40 - trailingKeepHeight
                )
                fragmentMaxHeight = max(minimumValueHeight, available - usefulTailHeight)
            }
            let fragment = fittingTextPrefix(
                remainder,
                width: contentWidth,
                font: valueFont,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing,
                maxHeight: fragmentMaxHeight
            )
            let fragmentHeight = measureText(
                fragment.prefix,
                width: contentWidth,
                font: valueFont,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            )
            _ = drawText(
                fragment.prefix,
                in: CGRect(x: margin, y: currentY, width: contentWidth, height: fragmentHeight + 2),
                font: valueFont,
                color: PDFVisualSystem.Color.textSecondary,
                lineSpacing: PDFVisualSystem.Typography.bodySpacing
            )
            currentY += fragmentHeight
            remainder = fragment.remainder
            isFirstFragment = false

            if !remainder.isEmpty {
                didSplit = true
                beginPage()
            }
        }

        if didSplit {
            splitTextBlockCount += 1
        }
        currentY += min(PDFVisualSystem.Space.md, remainingHeight)
        drawEntryDivider()
    }

    private func drawStandaloneText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        lineSpacing: CGFloat,
        bottomSpacing: CGFloat
    ) {
        var remainder = text
        var didSplit = false
        while !remainder.isEmpty {
            let minimumLineHeight = measureText("示例文本", width: contentWidth, font: font, lineSpacing: lineSpacing)
            if remainingHeight < minimumLineHeight {
                beginPage()
            }
            let fragment = fittingTextPrefix(
                remainder,
                width: contentWidth,
                font: font,
                lineSpacing: lineSpacing,
                maxHeight: remainingHeight
            )
            let height = measureText(fragment.prefix, width: contentWidth, font: font, lineSpacing: lineSpacing)
            _ = drawText(
                fragment.prefix,
                in: CGRect(x: margin, y: currentY, width: contentWidth, height: height + 2),
                font: font,
                color: color,
                lineSpacing: lineSpacing
            )
            currentY += height
            remainder = fragment.remainder
            if !remainder.isEmpty {
                didSplit = true
                beginPage()
            }
        }
        if didSplit {
            splitTextBlockCount += 1
        }
        currentY += min(bottomSpacing, remainingHeight)
    }

    private func fittingTextPrefix(
        _ text: String,
        width: CGFloat,
        font: UIFont,
        lineSpacing: CGFloat,
        maxHeight: CGFloat
    ) -> (prefix: String, remainder: String) {
        paginationEngine.splitText(
            text,
            maxHeight: maxHeight,
            measure: { candidate in
                textMeasurer.height(
                    candidate,
                    width: width,
                    font: font,
                    lineSpacing: lineSpacing
                )
            }
        )
    }

    private func drawEntryDivider() {
        drawRule(
            from: CGPoint(x: margin, y: currentY - PDFVisualSystem.Space.xs),
            to: CGPoint(x: margin + contentWidth, y: currentY - PDFVisualSystem.Space.xs),
            color: PDFVisualSystem.Color.border.withAlphaComponent(0.72),
            width: 0.5
        )
    }

    // MARK: - Page Chrome

    private func beginPage() {
        if pageNumber > 0 {
            finalizeCurrentPageUsage()
        }
        context?.beginPage()
        pageNumber += 1
        currentY = contentTop
        drawPageBackground()
        if pageNumber > 1 {
            drawHeader()
        }
        drawFooter()
    }

    private func drawPageBackground() {
        PDFVisualSystem.Color.pageBackground.setFill()
        UIBezierPath(rect: pageRect).fill()
    }

    private func drawHeader() {
        _ = drawText(
            "CoDesign Agent · \(document.projectName)",
            in: CGRect(
                x: margin,
                y: PDFVisualSystem.Page.headerTextY,
                width: contentWidth,
                height: 12
            ),
            font: PDFVisualSystem.Typography.metadata,
            color: PDFVisualSystem.Color.metadata,
            lineSpacing: PDFVisualSystem.Typography.metadataSpacing
        )
        drawRule(
            from: CGPoint(x: margin, y: PDFVisualSystem.Page.headerRuleY),
            to: CGPoint(x: margin + contentWidth, y: PDFVisualSystem.Page.headerRuleY),
            color: PDFVisualSystem.Color.border.withAlphaComponent(0.7),
            width: 0.5
        )
    }

    private func drawFooter() {
        drawRule(
            from: CGPoint(x: margin, y: PDFVisualSystem.Page.footerRuleY),
            to: CGPoint(x: margin + contentWidth, y: PDFVisualSystem.Page.footerRuleY),
            color: PDFVisualSystem.Color.border.withAlphaComponent(0.7),
            width: 0.5
        )
        _ = drawText(
            ReportCopy.documentTitle,
            in: CGRect(
                x: margin,
                y: PDFVisualSystem.Page.footerTextY,
                width: contentWidth * 0.7,
                height: 10
            ),
            font: PDFVisualSystem.Typography.metadata,
            color: PDFVisualSystem.Color.metadata,
            lineSpacing: PDFVisualSystem.Typography.metadataSpacing
        )
        _ = drawText(
            "\(pageNumber)",
            in: CGRect(
                x: pageRect.width - margin - 40,
                y: PDFVisualSystem.Page.footerTextY,
                width: 40,
                height: 10
            ),
            font: PDFVisualSystem.Typography.metadata,
            color: PDFVisualSystem.Color.metadata,
            alignment: .right
        )
    }

    private func finalizeCurrentPageUsage() {
        guard pageContentHeights.count < pageNumber else { return }
        pageContentHeights.append(max(0, min(currentY, contentBottom) - contentTop))
    }

    @discardableResult
    private func ensureSpace(_ height: CGFloat) -> Bool {
        guard paginationEngine.shouldBeginNewPage(
            requiredHeight: height,
            remainingHeight: remainingHeight,
            isAtPageTop: isAtPageTop,
            pageBodyHeight: pageBodyHeight
        ) else { return false }
        if height <= pageBodyHeight {
            beginPage()
            return true
        }
        return false
    }

    private func drawSectionHeader(
        title: String,
        englishTitle: String? = nil,
        subtitle: String? = nil,
        keepWithNext nextHeight: CGFloat = 0
    ) {
        let titleHeight = measureText(
            title,
            width: contentWidth - 14,
            font: PDFVisualSystem.Typography.h1,
            lineSpacing: PDFVisualSystem.Typography.h1Spacing
        )
        let subtitleHeight = subtitle.map {
            measureText(
                $0,
                width: contentWidth,
                font: PDFVisualSystem.Typography.caption,
                lineSpacing: PDFVisualSystem.Typography.captionSpacing
            )
        } ?? 0
        let englishTitleHeight = englishTitle.map {
            measureText(
                $0,
                width: contentWidth - 14,
                font: PDFVisualSystem.Typography.caption,
                lineSpacing: PDFVisualSystem.Typography.captionSpacing
            )
        } ?? 0
        let height = titleHeight + PDFVisualSystem.Space.sm
            + englishTitleHeight + (englishTitle == nil ? 0 : PDFVisualSystem.Space.xs)
            + subtitleHeight + PDFVisualSystem.Space.lg
        ensureSpace(min(pageBodyHeight, height + nextHeight))

        PDFVisualSystem.Color.primary.setFill()
        UIBezierPath(
            roundedRect: CGRect(x: margin, y: currentY + 2, width: 3, height: min(20, titleHeight)),
            cornerRadius: 1.5
        ).fill()
        _ = drawText(
            title,
            in: CGRect(x: margin + 14, y: currentY, width: contentWidth - 14, height: titleHeight + 2),
            font: PDFVisualSystem.Typography.h1,
            color: PDFVisualSystem.Color.textPrimary,
            lineSpacing: PDFVisualSystem.Typography.h1Spacing
        )
        currentY += titleHeight + PDFVisualSystem.Space.sm

        if let englishTitle {
            _ = drawText(
                englishTitle,
                in: CGRect(x: margin + 14, y: currentY, width: contentWidth - 14, height: englishTitleHeight + 2),
                font: PDFVisualSystem.Typography.caption,
                color: PDFVisualSystem.Color.caption,
                lineSpacing: PDFVisualSystem.Typography.captionSpacing
            )
            currentY += englishTitleHeight + PDFVisualSystem.Space.xs
        }

        if let subtitle {
            _ = drawText(
                subtitle,
                in: CGRect(x: margin + 14, y: currentY, width: contentWidth - 14, height: subtitleHeight + 2),
                font: PDFVisualSystem.Typography.caption,
                color: PDFVisualSystem.Color.caption,
                lineSpacing: PDFVisualSystem.Typography.captionSpacing
            )
            currentY += subtitleHeight
        }
        currentY += PDFVisualSystem.Space.lg
        if nextHeight > 0, remainingHeight + 0.5 < min(nextHeight, pageBodyHeight - height) {
            orphanHeadingCount += 1
        }
    }

    private func drawSubsectionTitle(_ title: String, keepWithNext nextHeight: CGFloat = 0) {
        let titleHeight = measureText(
            title,
            width: contentWidth,
            font: PDFVisualSystem.Typography.h2,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )
        let height = titleHeight + PDFVisualSystem.Space.md
        ensureSpace(min(pageBodyHeight, height + nextHeight))
        _ = drawText(
            title,
            in: CGRect(x: margin, y: currentY, width: contentWidth, height: titleHeight + 2),
            font: PDFVisualSystem.Typography.h2,
            color: PDFVisualSystem.Color.textPrimary,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )
        currentY += height
        if nextHeight > 0, remainingHeight + 0.5 < min(nextHeight, pageBodyHeight - height) {
            orphanHeadingCount += 1
        }
    }

    // MARK: - Primitive Drawing

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineSpacing: CGFloat = 2
    ) -> CGFloat {
        let attributed = attributedString(
            text,
            font: font,
            color: color,
            alignment: alignment,
            lineSpacing: lineSpacing
        )
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return min(rect.height, ceil(attributed.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height))
    }

    private func measureText(_ text: String, width: CGFloat, font: UIFont, lineSpacing: CGFloat = 2) -> CGFloat {
        textMeasurer.height(text, width: width, font: font, lineSpacing: lineSpacing)
    }

    private func attributedString(
        _ text: String,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineSpacing: CGFloat = 2
    ) -> NSAttributedString {
        textMeasurer.attributedString(
            text,
            font: font,
            color: color,
            alignment: alignment,
            lineSpacing: lineSpacing
        )
    }

    private func drawDocumentHeader() {
        PDFVisualSystem.Color.primary.setFill()
        UIBezierPath(
            roundedRect: CGRect(x: margin, y: currentY + 2, width: 3, height: 20),
            cornerRadius: 1.25
        ).fill()
        let titleHeight = measureText(
            document.title,
            width: contentWidth * 0.72,
            font: PDFVisualSystem.Typography.documentTitle,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )
        _ = drawText(
            document.title,
            in: CGRect(x: margin + 12, y: currentY, width: contentWidth * 0.72, height: titleHeight + 2),
            font: PDFVisualSystem.Typography.documentTitle,
            color: PDFVisualSystem.Color.textPrimary,
            lineSpacing: PDFVisualSystem.Typography.h2Spacing
        )
        let subtitleHeight = measureText(
            document.subtitle,
            width: contentWidth * 0.72,
            font: PDFVisualSystem.Typography.metadata,
            lineSpacing: PDFVisualSystem.Typography.metadataSpacing
        )
        _ = drawText(
            document.subtitle,
            in: CGRect(
                x: margin + 12,
                y: currentY + titleHeight + PDFVisualSystem.Space.xs,
                width: contentWidth * 0.72,
                height: subtitleHeight + 2
            ),
            font: PDFVisualSystem.Typography.metadata,
            color: PDFVisualSystem.Color.caption,
            lineSpacing: PDFVisualSystem.Typography.metadataSpacing
        )
        if let metadata = document.metadata.first {
            _ = drawText(
                "\(metadata.label) · \(metadata.value)",
                in: CGRect(
                    x: margin + contentWidth * 0.70,
                    y: currentY + 2,
                    width: contentWidth * 0.30,
                    height: 24
                ),
                font: PDFVisualSystem.Typography.metadata,
                color: PDFVisualSystem.Color.metadata,
                alignment: .right,
                lineSpacing: PDFVisualSystem.Typography.metadataSpacing
            )
        }
        currentY += titleHeight + subtitleHeight + PDFVisualSystem.Space.xl
    }

    private func drawRoundedRect(
        _ rect: CGRect,
        radius: CGFloat,
        fill: UIColor,
        stroke: UIColor?,
        lineWidth: CGFloat = 0.5
    ) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        fill.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
    }

    private func drawRule(
        from start: CGPoint,
        to end: CGPoint,
        color: UIColor,
        width: CGFloat
    ) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        color.setStroke()
        path.lineWidth = width
        path.stroke()
    }

}

/// PDF 的统一视觉令牌。页面、字体、颜色、间距、表格和状态样式均由此处管理。
private enum PDFDesignTokens {
    enum Page {
        static let rect = CGRect(x: 0, y: 0, width: 595, height: 842)
        static let horizontalMargin: CGFloat = 60
        static let contentTop: CGFloat = 58
        static let contentBottomInset: CGFloat = 62
        static let headerTextY: CGFloat = 24
        static let headerRuleY: CGFloat = 45
        static let footerRuleY: CGFloat = 805
        static let footerTextY: CGFloat = 814
    }

    enum Typography {
        static let projectTitle = semibold(26)
        static let documentTitle = semibold(14)
        static let h1 = semibold(19)
        static let h2 = semibold(13.5)
        static let keyLabel = semibold(10.2)
        static let body = regular(10.6)
        static let caption = regular(8.8)
        static let metadata = medium(8.5)
        static let metadataEmphasis = semibold(8.5)
        static let tableHeader = semibold(9.5)
        static let tableBody = regular(9.6)
        static let tableLabel = semibold(9)
        static let tableEmphasis = semibold(10)

        private static func regular(_ size: CGFloat) -> UIFont {
            UIFont(name: "HelveticaNeue", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .regular)
        }

        private static func medium(_ size: CGFloat) -> UIFont {
            UIFont(name: "HelveticaNeue-Medium", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .medium)
        }

        private static func semibold(_ size: CGFloat) -> UIFont {
            UIFont(name: "HelveticaNeue-Bold", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .semibold)
        }

        static let projectTitleSpacing: CGFloat = 5
        static let h1Spacing: CGFloat = 4
        static let h2Spacing: CGFloat = 2
        static let labelSpacing: CGFloat = 2
        static let bodySpacing: CGFloat = 3
        static let captionSpacing: CGFloat = 2
        static let metadataSpacing: CGFloat = 1
        static let tableSpacing: CGFloat = 2
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let table: CGFloat = 6
        static let callout: CGFloat = 8
        static let tag: CGFloat = 12
    }

    enum Table {
        static let horizontalPadding: CGFloat = 7
        static let verticalPadding: CGFloat = 8
        static let minimumHeaderHeight: CGFloat = 30
        static let minimumRowHeight: CGFloat = 34
        static let borderWidth: CGFloat = 0.5
    }

    enum Color {
        static let pageBackground = UIColor(red: 250 / 255, green: 250 / 255, blue: 252 / 255, alpha: 1)
        static let secondaryBackground = UIColor(red: 245 / 255, green: 247 / 255, blue: 252 / 255, alpha: 1)
        static let surface = UIColor.white
        static let tableHeader = UIColor(red: 241 / 255, green: 243 / 255, blue: 249 / 255, alpha: 1)
        static let border = UIColor(red: 215 / 255, green: 219 / 255, blue: 230 / 255, alpha: 1)
        static let textPrimary = UIColor(red: 31 / 255, green: 36 / 255, blue: 51 / 255, alpha: 1)
        static let textSecondary = UIColor(red: 96 / 255, green: 103 / 255, blue: 121 / 255, alpha: 1)
        static let caption = UIColor(red: 141 / 255, green: 147 / 255, blue: 166 / 255, alpha: 1)
        static let metadata = UIColor(red: 141 / 255, green: 147 / 255, blue: 166 / 255, alpha: 1)
        static let primary = UIColor(red: 100 / 255, green: 118 / 255, blue: 233 / 255, alpha: 1)
        static let primarySoft = UIColor(red: 232 / 255, green: 236 / 255, blue: 255 / 255, alpha: 1)
        static let secondaryAccent = UIColor(red: 117 / 255, green: 104 / 255, blue: 216 / 255, alpha: 1)

        static let statusGreen = UIColor(red: 123 / 255, green: 203 / 255, blue: 149 / 255, alpha: 1)
        static let statusGreenBackground = UIColor(red: 237 / 255, green: 247 / 255, blue: 240 / 255, alpha: 1)
        static let statusYellow = UIColor(red: 160 / 255, green: 119 / 255, blue: 42 / 255, alpha: 1)
        static let statusYellowBackground = UIColor(red: 252 / 255, green: 245 / 255, blue: 232 / 255, alpha: 1)
        static let statusRed = UIColor(red: 175 / 255, green: 87 / 255, blue: 91 / 255, alpha: 1)
        static let statusRedBackground = UIColor(red: 251 / 255, green: 237 / 255, blue: 238 / 255, alpha: 1)
    }
}

private typealias PDFVisualSystem = PDFDesignTokens
#endif
