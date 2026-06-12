import Foundation
#if canImport(UIKit)
import UIKit
#else
import CoreGraphics
import CoreText
#endif

struct PDFReportRenderer {
    func render(snapshot: ProjectReportSnapshot) throws -> Data {
        #if canImport(UIKit)
        return StyledProjectPDFRenderer(snapshot: snapshot).render()
        #else
        let markdown = MarkdownReportRenderer().render(snapshot: snapshot)
        return try renderPDF(text: markdown)
        #endif
    }

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
private final class StyledProjectPDFRenderer {
    private struct InfoItem {
        var title: String
        var value: String
        var tint: UIColor
    }

    private let snapshot: ProjectReportSnapshot
    private let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    private let margin: CGFloat = 42
    private let gap: CGFloat = 12
    private var currentY: CGFloat = 42
    private var pageNumber = 0
    private var context: UIGraphicsPDFRendererContext?

    private var contentWidth: CGFloat {
        pageRect.width - margin * 2
    }

    private var contentBottom: CGFloat {
        pageRect.height - margin - 30
    }

    private var brief: DesignBriefSnapshot {
        snapshot.brief
    }

    init(snapshot: ProjectReportSnapshot) {
        self.snapshot = snapshot
    }

    func render() -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(snapshot.project.name)-AI 产品设计报告",
            kCGPDFContextAuthor as String: "CoDesign Agent",
            kCGPDFContextCreator as String: "CoDesign Agent"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { rendererContext in
            context = rendererContext
            beginPage()
            drawCover()

            beginPage()
            drawVisualBoard()
            drawPortfolioArchive()
            drawCoreReport()
            drawDecisionTrace()
            drawResources()
            drawMindTreeAppendix()
        }
    }

    // MARK: - Main Sections

    private func drawCover() {
        currentY += 34
        drawPill("CoDesign Agent · AI 产品设计报告", tint: ColorPalette.primary, at: CGPoint(x: margin, y: currentY))
        currentY += 54

        let titleHeight = drawText(
            snapshot.project.name,
            in: CGRect(x: margin, y: currentY, width: contentWidth, height: 120),
            font: .systemFont(ofSize: 30, weight: .bold),
            color: ColorPalette.textPrimary,
            lineSpacing: 6
        )
        currentY += titleHeight + 12

        if let description = meaningfulValue(snapshot.project.briefDescription) {
            let descriptionHeight = drawText(
                description,
                in: CGRect(x: margin, y: currentY, width: contentWidth * 0.82, height: 96),
                font: .systemFont(ofSize: 13, weight: .regular),
                color: ColorPalette.textSecondary,
                lineSpacing: 5
            )
            currentY += descriptionHeight + 30
        } else {
            currentY += 16
        }

        drawProgressCard()
        currentY += 26

        let metaItems = [
            InfoItem(title: "当前阶段", value: "Stage \(snapshot.project.currentStageOrder) · \(snapshot.project.currentStageName)", tint: ColorPalette.primary),
            InfoItem(title: "完成度", value: "\(Int(snapshot.project.completionRate * 100))%", tint: ColorPalette.success),
            InfoItem(title: "创建时间", value: formatDate(snapshot.project.createdAt), tint: ColorPalette.info),
            InfoItem(title: "导出时间", value: formatDate(snapshot.exportedAt), tint: ColorPalette.secondary)
        ]
        drawInfoGrid(metaItems, columns: 2)
    }

    private func drawVisualBoard() {
        drawSectionHeader(
            title: "成果看板",
            subtitle: "继承应用内可视化看板的结构，用图谱、进度与关键字段呈现当前方案状态。"
        )
        drawDashboardGraph()

        let cards = [
            InfoItem(title: "目标用户", value: displayValue(brief.targetUser), tint: ColorPalette.info),
            InfoItem(title: "核心痛点", value: displayValue(brief.painPoint), tint: ColorPalette.danger),
            InfoItem(title: "使用场景", value: displayValue(brief.useScenario), tint: ColorPalette.primary),
            InfoItem(title: "设计目标", value: displayValue(brief.coreValue), tint: ColorPalette.secondary),
            InfoItem(title: "关键约束", value: displayValue(brief.hardConstraints), tint: ColorPalette.warning),
            InfoItem(title: "评价标准", value: metricsSummary(), tint: ColorPalette.success),
            InfoItem(title: "下一步 / 风险", value: riskSummary(), tint: ColorPalette.danger)
        ]
        drawInfoGrid(cards, columns: 2)
    }

    private func drawPortfolioArchive() {
        drawSectionHeader(
            title: "作品档案",
            subtitle: "记录本项目的设计思考轨迹、结构化 Brief、边界、风险与学习反思，可用于课程汇报和后续复盘。"
        )

        let briefItems = [
            InfoItem(title: "差异化价值", value: displayValue(brief.differentiation), tint: ColorPalette.success),
            InfoItem(title: "MVP 功能", value: displayValue(brief.mvpFeatures), tint: ColorPalette.primary),
            InfoItem(title: "技术模块", value: displayValue(brief.technicalModules), tint: ColorPalette.info),
            InfoItem(title: "交互流程", value: displayValue(brief.interactionFlow), tint: ColorPalette.secondary),
            InfoItem(title: "运行逻辑", value: displayValue(brief.operationLogic), tint: ColorPalette.primary),
            InfoItem(title: "里程碑", value: displayValue(brief.milestones), tint: ColorPalette.warning)
        ]
        drawInfoGrid(briefItems, columns: 2)

        drawBoundarySection()
        drawLearningTraceCards()
    }

    private func drawCoreReport() {
        drawSectionHeader(title: "设计报告", subtitle: "以下内容来自已结构化的 Design Brief 与过程证据。")
        drawDictionarySection("项目摘要", snapshot.reportSections.projectSummary)
        drawDictionarySection("AI 价值假设", snapshot.reportSections.aiValueHypothesis)
        drawBehaviorSpec()
        drawMetricsSection()
        drawRiskSection()
        drawDictionarySection("干预设计", snapshot.reportSections.interventionSpec)
    }

    private func drawDecisionTrace() {
        guard snapshot.exportOptions.includeDecisionTrace else { return }
        drawSectionHeader(title: "设计决策路径", subtitle: "按阶段整理关键问题、回答、判断和学习轨迹。")

        let items = snapshot.processEvidence.decisionTrace
        guard !items.isEmpty else {
            drawNoticeCard("暂无设计决策路径。")
            return
        }

        for item in items {
            let title = "Stage \(item.stageOrder) · \(item.stageTitle)"
            let body = [
                item.title,
                item.content,
                item.relatedField.map { "关联字段：\($0)" },
                item.isActiveBranch ? nil : "旧分支 v\(item.branchVersion)"
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
            drawTimelineCard(title: title, badge: item.type, body: body, tint: item.isActiveBranch ? ColorPalette.primary : ColorPalette.warning)
        }
    }

    private func drawResources() {
        guard snapshot.exportOptions.includeResources else { return }
        drawSectionHeader(title: "资源线索与引用", subtitle: "导出本项目当前推荐/采纳的设计依据。")

        guard !snapshot.processEvidence.resources.isEmpty else {
            drawNoticeCard("暂无可导出的资源线索。")
            return
        }

        for resource in snapshot.processEvidence.resources {
            let body = [
                resource.summary,
                "为什么相关：\(resource.whyRelevant)",
                "如何使用：\(resource.howToUse)",
                resource.citation.map { "引用：\($0)" },
                resource.sourceURL.map { "来源：\($0)" }
            ]
            .compactMap { meaningfulValue($0) }
            .joined(separator: "\n")
            drawTimelineCard(title: resource.title, badge: resource.type, body: body, tint: ColorPalette.secondary)
        }
    }

    private func drawMindTreeAppendix() {
        guard snapshot.exportOptions.includeFullMindTree else { return }
        drawSectionHeader(title: "附录：完整思维树", subtitle: "以结构化 outline 形式导出当前分支和可选回溯分支。")

        guard !snapshot.processEvidence.thinkingMoments.isEmpty else {
            drawNoticeCard("暂无完整思维树节点。")
            return
        }

        for moment in snapshot.processEvidence.thinkingMoments {
            let status = moment.isActiveBranch ? "当前分支" : "旧分支 v\(moment.branchVersion)"
            let body = [
                moment.content,
                moment.relatedField.map { "关联字段：\($0)" },
                "时间：\(formatDate(moment.timestamp))"
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
            drawTimelineCard(
                title: "Stage \(moment.stageOrder) · \(moment.stageTitle)",
                badge: "\(moment.kind) · \(status)",
                body: body,
                tint: moment.isActiveBranch ? ColorPalette.primary : ColorPalette.warning
            )
        }
    }

    // MARK: - Visual Board Drawing

    private func drawProgressCard() {
        let height: CGFloat = 104
        ensureSpace(height)
        let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
        drawRoundedRect(rect, radius: 22, fill: ColorPalette.panel, stroke: ColorPalette.border)

        let percent = Int(snapshot.project.completionRate * 100)
        _ = drawText(
            "\(snapshot.project.currentStageName)",
            in: CGRect(x: rect.minX + 24, y: rect.minY + 20, width: rect.width - 48, height: 26),
            font: .systemFont(ofSize: 16, weight: .bold),
            color: ColorPalette.textPrimary
        )
        _ = drawText(
            "当前阶段 \(snapshot.project.currentStageOrder) · 完成度 \(percent)%",
            in: CGRect(x: rect.minX + 24, y: rect.minY + 48, width: rect.width - 48, height: 22),
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: ColorPalette.textSecondary
        )

        let trackRect = CGRect(x: rect.minX + 24, y: rect.maxY - 26, width: rect.width - 48, height: 8)
        drawRoundedRect(trackRect, radius: 4, fill: ColorPalette.border.withAlphaComponent(0.65), stroke: nil)
        let progressWidth = max(10, trackRect.width * CGFloat(snapshot.project.completionRate))
        drawRoundedRect(
            CGRect(x: trackRect.minX, y: trackRect.minY, width: progressWidth, height: trackRect.height),
            radius: 4,
            fill: ColorPalette.primary,
            stroke: nil
        )

        currentY += height + 14
    }

    private func drawDashboardGraph() {
        let height: CGFloat = 322
        ensureSpace(height)
        let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
        drawRoundedRect(rect, radius: 18, fill: ColorPalette.panel, stroke: ColorPalette.border)

        _ = drawText(
            "设计过程图谱",
            in: CGRect(x: rect.minX + 18, y: rect.minY + 16, width: rect.width - 36, height: 20),
            font: .systemFont(ofSize: 13, weight: .bold),
            color: ColorPalette.textPrimary
        )
        _ = drawText(
            "把项目从模糊想法到方案证据的推进关系可视化",
            in: CGRect(x: rect.minX + 18, y: rect.minY + 36, width: rect.width - 36, height: 18),
            font: .systemFont(ofSize: 9.5, weight: .regular),
            color: ColorPalette.textTertiary
        )

        let center = CGPoint(x: rect.midX, y: rect.minY + 168)
        let nodes: [(String, String, UIColor, CGPoint)] = [
            ("用户证据", displayValue(brief.targetUser), ColorPalette.success, CGPoint(x: rect.minX + 120, y: rect.minY + 108)),
            ("痛点场景", displayValue(brief.painPoint ?? brief.useScenario), ColorPalette.warning, CGPoint(x: rect.maxX - 120, y: rect.minY + 108)),
            ("核心价值", displayValue(brief.coreValue), ColorPalette.primary, CGPoint(x: rect.minX + 120, y: rect.minY + 230)),
            ("风险假设", riskSummary(), ColorPalette.danger, CGPoint(x: rect.maxX - 120, y: rect.minY + 230))
        ]

        for node in nodes {
            drawLine(from: center, to: node.3, color: node.2.withAlphaComponent(0.42), width: 2)
        }

        drawCentralNode(center: center)
        for node in nodes {
            drawMiniNode(title: node.0, value: node.1, tint: node.2, center: node.3)
        }

        drawStageTrack(in: CGRect(x: rect.minX + 22, y: rect.maxY - 34, width: rect.width - 44, height: 18))
        currentY += height + 18
    }

    private func drawCentralNode(center: CGPoint) {
        let rect = CGRect(x: center.x - 74, y: center.y - 48, width: 148, height: 96)
        drawRoundedRect(rect, radius: 20, fill: ColorPalette.primary, stroke: nil)
        _ = drawText(
            snapshot.project.name,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 24, width: rect.width - 28, height: 36),
            font: .systemFont(ofSize: 12, weight: .bold),
            color: .white,
            alignment: .center,
            lineSpacing: 2
        )
        _ = drawText(
            "当前阶段 \(snapshot.project.currentStageOrder)",
            in: CGRect(x: rect.minX + 14, y: rect.maxY - 28, width: rect.width - 28, height: 16),
            font: .systemFont(ofSize: 9, weight: .semibold),
            color: UIColor.white.withAlphaComponent(0.82),
            alignment: .center
        )
    }

    private func drawMiniNode(title: String, value: String, tint: UIColor, center: CGPoint) {
        let rect = CGRect(x: center.x - 70, y: center.y - 42, width: 140, height: 84)
        drawRoundedRect(rect, radius: 14, fill: .white, stroke: tint.withAlphaComponent(0.25))
        drawCircle(center: CGPoint(x: rect.midX, y: rect.minY + 20), radius: 13, fill: tint.withAlphaComponent(0.12))
        drawCircle(center: CGPoint(x: rect.midX, y: rect.minY + 20), radius: 4, fill: tint)
        _ = drawText(
            title,
            in: CGRect(x: rect.minX + 10, y: rect.minY + 36, width: rect.width - 20, height: 16),
            font: .systemFont(ofSize: 9.5, weight: .bold),
            color: ColorPalette.textPrimary,
            alignment: .center
        )
        _ = drawText(
            value,
            in: CGRect(x: rect.minX + 10, y: rect.minY + 53, width: rect.width - 20, height: 26),
            font: .systemFont(ofSize: 7.8, weight: .regular),
            color: ColorPalette.textSecondary,
            alignment: .center,
            lineSpacing: 1
        )
    }

    private func drawStageTrack(in rect: CGRect) {
        let stageGap: CGFloat = 5
        let segmentWidth = (rect.width - stageGap * 8) / 9
        for index in 0..<9 {
            let stageOrder = index + 1
            let stage = snapshot.stages.first { $0.order == stageOrder }
            let ratio = stage?.completionRatio ?? (stageOrder < snapshot.project.currentStageOrder ? 1 : 0)
            let color = ratio > 0
                ? ColorPalette.primary.withAlphaComponent(0.35 + min(0.55, ratio * 0.55))
                : ColorPalette.border
            let segmentRect = CGRect(
                x: rect.minX + CGFloat(index) * (segmentWidth + stageGap),
                y: rect.minY,
                width: segmentWidth,
                height: 7
            )
            drawRoundedRect(segmentRect, radius: 3.5, fill: color, stroke: nil)
            _ = drawText(
                "\(stageOrder)",
                in: CGRect(x: segmentRect.minX, y: segmentRect.maxY + 2, width: segmentRect.width, height: 9),
                font: .systemFont(ofSize: 6.5, weight: .semibold),
                color: stageOrder == snapshot.project.currentStageOrder ? ColorPalette.primary : ColorPalette.textTertiary,
                alignment: .center
            )
        }
    }

    // MARK: - Report Components

    private func drawDictionarySection(_ title: String, _ dictionary: [String: String]) {
        let items = dictionary.keys.sorted().compactMap { key -> InfoItem? in
            guard let value = meaningfulValue(dictionary[key]) else { return nil }
            return InfoItem(title: key, value: value, tint: ColorPalette.primary)
        }

        guard !items.isEmpty else { return }
        drawSubsectionTitle(title)
        drawInfoGrid(items, columns: 2)
    }

    private func drawBehaviorSpec() {
        guard !snapshot.reportSections.behaviorSpec.isEmpty else { return }
        drawSubsectionTitle("Behavior Spec")
        for key in ["UNDERSTAND", "CAPABILITY", "BOUNDARY"] {
            guard let section = snapshot.reportSections.behaviorSpec[key] else { continue }
            let items = section.keys.sorted().compactMap { field -> InfoItem? in
                guard let value = meaningfulValue(section[field]) else { return nil }
                return InfoItem(title: field, value: value, tint: ColorPalette.secondary)
            }
            guard !items.isEmpty else { continue }
            drawPill(key, tint: ColorPalette.secondary, at: CGPoint(x: margin, y: currentY))
            currentY += 28
            drawInfoGrid(items, columns: 2)
        }
    }

    private func drawMetricsSection() {
        drawSubsectionTitle("Reward Function")
        guard !brief.successMetrics.isEmpty else {
            drawNoticeCard("暂无已确认的量化指标。")
            return
        }

        for metric in brief.successMetrics {
            let body = [
                "测量方式：\(displayValue(metric.measurement))",
                "阈值：\(metric.target)"
            ]
            .joined(separator: "\n")
            drawTimelineCard(title: metric.metric, badge: "指标", body: body, tint: ColorPalette.success)
        }
    }

    private func drawRiskSection() {
        drawSubsectionTitle("Failure & Recovery")
        guard !brief.risks.isEmpty else {
            drawNoticeCard("暂无已确认风险。")
            return
        }

        for risk in brief.risks {
            let body = [
                "概率 \(risk.probability)/5 · 影响 \(risk.impact)/5",
                "应对措施：\(displayValue(risk.mitigation))"
            ]
            .joined(separator: "\n")
            drawTimelineCard(title: risk.desc, badge: "风险", body: body, tint: ColorPalette.danger)
        }
    }

    private func drawBoundarySection() {
        let included = brief.boundaryItems.filter(\.isIncluded)
        let excluded = brief.boundaryItems.filter { !$0.isIncluded }
        guard !included.isEmpty || !excluded.isEmpty else { return }

        drawSubsectionTitle("边界定义")
        let includeText = included.map(\.content).joined(separator: "\n")
        let excludeText = excluded.map(\.content).joined(separator: "\n")
        let items = [
            meaningfulValue(includeText).map { InfoItem(title: "做的范围", value: $0, tint: ColorPalette.success) },
            meaningfulValue(excludeText).map { InfoItem(title: "不做的范围", value: $0, tint: ColorPalette.danger) }
        ]
        .compactMap { $0 }
        drawInfoGrid(items, columns: 2)
    }

    private func drawLearningTraceCards() {
        guard !snapshot.processEvidence.learningTraces.isEmpty else { return }
        drawSubsectionTitle("Thinking Action Cards")
        for trace in snapshot.processEvidence.learningTraces {
            drawTimelineCard(
                title: trace.title,
                badge: "Stage \(trace.stageOrder) · \(trace.actionType)",
                body: trace.detail,
                tint: ColorPalette.secondary
            )
        }
    }

    private func drawInfoGrid(_ items: [InfoItem], columns: Int) {
        guard !items.isEmpty else { return }
        let columnCount = max(1, columns)
        let cellWidth = (contentWidth - gap * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        var index = 0

        while index < items.count {
            let rowItems = Array(items[index..<min(index + columnCount, items.count)])
            let rowHeights = rowItems.map { infoCardHeight(for: $0, width: cellWidth) }
            let rowHeight = rowHeights.max() ?? 84
            ensureSpace(rowHeight)

            for (column, item) in rowItems.enumerated() {
                let rect = CGRect(
                    x: margin + CGFloat(column) * (cellWidth + gap),
                    y: currentY,
                    width: cellWidth,
                    height: rowHeight
                )
                drawInfoCard(item, in: rect)
            }

            currentY += rowHeight + gap
            index += columnCount
        }
    }

    private func infoCardHeight(for item: InfoItem, width: CGFloat) -> CGFloat {
        let valueHeight = measureText(
            item.value,
            width: width - 28,
            font: .systemFont(ofSize: 9.5, weight: .regular),
            lineSpacing: 3
        )
        return min(max(78, valueHeight + 48), 150)
    }

    private func drawInfoCard(_ item: InfoItem, in rect: CGRect) {
        drawRoundedRect(rect, radius: 13, fill: .white, stroke: ColorPalette.border)
        drawCircle(center: CGPoint(x: rect.minX + 18, y: rect.minY + 19), radius: 5, fill: item.tint)
        _ = drawText(
            item.title,
            in: CGRect(x: rect.minX + 30, y: rect.minY + 12, width: rect.width - 44, height: 18),
            font: .systemFont(ofSize: 10, weight: .bold),
            color: ColorPalette.textPrimary
        )
        _ = drawText(
            item.value,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 38, width: rect.width - 28, height: rect.height - 48),
            font: .systemFont(ofSize: 9.5, weight: .regular),
            color: ColorPalette.textSecondary,
            lineSpacing: 3
        )
    }

    private func drawTimelineCard(title: String, badge: String, body: String, tint: UIColor) {
        let cleanBody = meaningfulValue(body) ?? "未记录"
        let bodyHeight = measureText(cleanBody, width: contentWidth - 32, font: .systemFont(ofSize: 9.5), lineSpacing: 3)
        let height = max(86, min(210, bodyHeight + 58))
        ensureSpace(height)

        let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
        drawRoundedRect(rect, radius: 14, fill: .white, stroke: ColorPalette.border)
        drawPill(badge, tint: tint, at: CGPoint(x: rect.minX + 16, y: rect.minY + 14), compact: true)
        _ = drawText(
            title,
            in: CGRect(x: rect.minX + 16, y: rect.minY + 38, width: rect.width - 32, height: 24),
            font: .systemFont(ofSize: 11, weight: .bold),
            color: ColorPalette.textPrimary
        )
        _ = drawText(
            cleanBody,
            in: CGRect(x: rect.minX + 16, y: rect.minY + 62, width: rect.width - 32, height: rect.height - 72),
            font: .systemFont(ofSize: 9.5, weight: .regular),
            color: ColorPalette.textSecondary,
            lineSpacing: 3
        )
        currentY += height + gap
    }

    private func drawNoticeCard(_ text: String) {
        let height: CGFloat = 56
        ensureSpace(height)
        let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
        drawRoundedRect(rect, radius: 14, fill: ColorPalette.panel, stroke: ColorPalette.border)
        _ = drawText(
            text,
            in: CGRect(x: rect.minX + 16, y: rect.minY + 19, width: rect.width - 32, height: 18),
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: ColorPalette.textTertiary
        )
        currentY += height + gap
    }

    // MARK: - Page Chrome

    private func beginPage() {
        context?.beginPage()
        pageNumber += 1
        currentY = margin
        drawPageBackground()
        drawFooter()
    }

    private func drawPageBackground() {
        ColorPalette.background.setFill()
        UIBezierPath(rect: pageRect).fill()
    }

    private func drawFooter() {
        let footerY = pageRect.height - 32
        _ = drawText(
            "CoDesign Agent · \(snapshot.project.name)",
            in: CGRect(x: margin, y: footerY, width: contentWidth * 0.7, height: 14),
            font: .systemFont(ofSize: 7.5, weight: .regular),
            color: ColorPalette.textTertiary
        )
        _ = drawText(
            "\(pageNumber)",
            in: CGRect(x: pageRect.width - margin - 40, y: footerY, width: 40, height: 14),
            font: .systemFont(ofSize: 7.5, weight: .semibold),
            color: ColorPalette.textTertiary,
            alignment: .right
        )
    }

    private func ensureSpace(_ height: CGFloat) {
        if currentY + height > contentBottom {
            beginPage()
        }
    }

    private func drawSectionHeader(title: String, subtitle: String? = nil) {
        let subtitleHeight = subtitle.map {
            measureText($0, width: contentWidth, font: .systemFont(ofSize: 10.5), lineSpacing: 3)
        } ?? 0
        let height = 48 + subtitleHeight
        ensureSpace(height)

        _ = drawText(
            title,
            in: CGRect(x: margin, y: currentY, width: contentWidth, height: 24),
            font: .systemFont(ofSize: 19, weight: .bold),
            color: ColorPalette.textPrimary
        )
        currentY += 28

        if let subtitle {
            let drawn = drawText(
                subtitle,
                in: CGRect(x: margin, y: currentY, width: contentWidth * 0.86, height: subtitleHeight + 4),
                font: .systemFont(ofSize: 10.5, weight: .regular),
                color: ColorPalette.textTertiary,
                lineSpacing: 3
            )
            currentY += drawn + 14
        } else {
            currentY += 10
        }
    }

    private func drawSubsectionTitle(_ title: String) {
        ensureSpace(32)
        _ = drawText(
            title,
            in: CGRect(x: margin, y: currentY, width: contentWidth, height: 20),
            font: .systemFont(ofSize: 13, weight: .bold),
            color: ColorPalette.textPrimary
        )
        currentY += 28
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
        let attributed = attributedString(text, font: font, color: ColorPalette.textPrimary, lineSpacing: lineSpacing)
        return ceil(attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height)
    }

    private func attributedString(
        _ text: String,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineSpacing: CGFloat = 2
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
                .paragraphStyle: paragraph
            ]
        )
    }

    private func drawPill(_ text: String, tint: UIColor, at point: CGPoint, compact: Bool = false) {
        let font = UIFont.systemFont(ofSize: compact ? 7.5 : 9, weight: .bold)
        let textWidth = measureSingleLineWidth(text, font: font)
        let width = min(max(textWidth + (compact ? 18 : 22), compact ? 42 : 76), 260)
        let height: CGFloat = compact ? 18 : 24
        let rect = CGRect(x: point.x, y: point.y, width: width, height: height)
        drawRoundedRect(rect, radius: height / 2, fill: tint.withAlphaComponent(0.10), stroke: nil)
        _ = drawText(
            text,
            in: CGRect(x: rect.minX + 9, y: rect.minY + (compact ? 4 : 5), width: rect.width - 18, height: height - 4),
            font: font,
            color: tint,
            alignment: .center,
            lineSpacing: 0
        )
    }

    private func measureSingleLineWidth(_ text: String, font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func drawRoundedRect(_ rect: CGRect, radius: CGFloat, fill: UIColor, stroke: UIColor?) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        fill.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawCircle(center: CGPoint, radius: CGFloat, fill: UIColor) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        fill.setFill()
        UIBezierPath(ovalIn: rect).fill()
    }

    private func drawLine(from start: CGPoint, to end: CGPoint, color: UIColor, width: CGFloat) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        color.setStroke()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.stroke()
    }

    // MARK: - Content Helpers

    private func displayValue(_ value: String?) -> String {
        meaningfulValue(value) ?? "未记录"
    }

    private func meaningfulValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let disallowedFragments = [
            ReportSnapshotValue.missing,
            "需要补充",
            "待人工确认",
            "______"
        ]
        guard !disallowedFragments.contains(where: { trimmed.contains($0) }) else {
            return nil
        }
        return trimmed
    }

    private func metricsSummary() -> String {
        guard !brief.successMetrics.isEmpty else { return "未记录" }
        return brief.successMetrics
            .prefix(3)
            .map { "\($0.metric)：\($0.target)" }
            .joined(separator: "\n")
    }

    private func riskSummary() -> String {
        guard let risk = brief.risks.first else { return "未记录" }
        return risk.desc
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private enum ColorPalette {
    static let background = UIColor(red: 0.97, green: 0.975, blue: 0.99, alpha: 1)
    static let panel = UIColor(red: 0.94, green: 0.95, blue: 0.975, alpha: 1)
    static let border = UIColor(red: 0.84, green: 0.86, blue: 0.91, alpha: 1)
    static let textPrimary = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    static let textSecondary = UIColor(red: 0.38, green: 0.39, blue: 0.44, alpha: 1)
    static let textTertiary = UIColor(red: 0.58, green: 0.60, blue: 0.67, alpha: 1)
    static let primary = UIColor(red: 0.36, green: 0.45, blue: 0.84, alpha: 1)
    static let secondary = UIColor(red: 0.52, green: 0.44, blue: 0.76, alpha: 1)
    static let success = UIColor(red: 0.27, green: 0.69, blue: 0.42, alpha: 1)
    static let warning = UIColor(red: 0.86, green: 0.68, blue: 0.22, alpha: 1)
    static let danger = UIColor(red: 0.82, green: 0.33, blue: 0.33, alpha: 1)
    static let info = UIColor(red: 0.32, green: 0.58, blue: 0.82, alpha: 1)
}
#endif
