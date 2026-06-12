import CoreGraphics
import CoreText
import Foundation

struct PDFReportRenderer {
    func render(snapshot: ProjectReportSnapshot) throws -> Data {
        let markdown = MarkdownReportRenderer().render(snapshot: snapshot)
        return try renderPDF(text: markdown)
    }

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
}
