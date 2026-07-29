import Foundation
import Testing
@testable import CoDesign_Agent

struct StreamingMarkdownRenderTests {
    @Test func chunkedBoldFallsBackWithoutExposingDelimiter() {
        let assembly = MarkdownBlockAssembler.assemble("一段 **正在生成")
        #expect(assembly.draftRequiresPlainText)
        #expect(!assembly.readableDraftText.contains("**"))
        #expect(assembly.readableDraftText.contains("正在生成"))
    }

    @Test func completedBoldRendersStrongElement() {
        let html = MarkdownHTMLRenderer.render("一段 **重要内容**。")
        #expect(html.contains("<strong>重要内容</strong>"))
        #expect(!html.contains("**"))
    }

    @Test func headingRendersAsSemanticHeading() {
        let html = MarkdownHTMLRenderer.render("## 阶段判断")
        #expect(html.contains("<h2>阶段判断</h2>"))
    }

    @Test func headingCanBecomeStableAfterMarkerAndTextArriveSeparately() {
        let markerOnly = MarkdownBlockAssembler.assemble("##")
        let completed = MarkdownBlockAssembler.assemble("## 阶段判断\n")
        #expect(markerOnly.stableMarkdown.isEmpty)
        #expect(completed.stableMarkdown == "## 阶段判断\n")
        #expect(MarkdownHTMLRenderer.render(completed.stableMarkdown).contains("<h2>阶段判断</h2>"))
    }

    @Test func paragraphsRemainSeparate() {
        let html = MarkdownHTMLRenderer.render("第一段。\n\n第二段。")
        #expect(html.contains("<p>第一段。</p>"))
        #expect(html.contains("<p>第二段。</p>"))
    }

    @Test func unorderedListRendersSemanticItems() {
        let html = MarkdownHTMLRenderer.render("- 第一项\n- 第二项")
        #expect(html.contains("<ul>"))
        #expect(html.components(separatedBy: "<li>").count == 3)
    }

    @Test func orderedListKeepsStartIndex() {
        let html = MarkdownHTMLRenderer.render("3. 第三项\n4. 第四项")
        #expect(html.contains("<ol start=\"3\">"))
    }

    @Test func progressivelyArrivingListStaysDraftUntilBlankLine() {
        let firstLine = MarkdownBlockAssembler.assemble("- 第一项\n")
        let completed = MarkdownBlockAssembler.assemble("- 第一项\n- 第二项\n\n")
        #expect(firstLine.stableMarkdown.isEmpty)
        #expect(completed.stableMarkdown == "- 第一项\n- 第二项\n\n")
    }

    @Test func quoteRendersSemantically() {
        let html = MarkdownHTMLRenderer.render("> 一条设计线索")
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("一条设计线索"))
    }

    @Test func fencedCodeIsEscaped() {
        let html = MarkdownHTMLRenderer.render("```swift\nlet x = \"<tag>\"\n```")
        #expect(html.contains("language-swift"))
        #expect(html.contains("&lt;tag&gt;"))
        #expect(!html.contains("<tag>"))
    }

    @Test func tableRendersInsideHorizontalContainer() {
        let html = MarkdownHTMLRenderer.render("| A | B |\n| --- | --- |\n| 1 | 2 |")
        #expect(html.contains("<div class=\"table-scroll\"><table>"))
        #expect(html.contains("<th>A</th>"))
        #expect(html.contains("<td>1</td>"))
    }

    @Test func httpLinkIsAllowed() {
        let html = MarkdownHTMLRenderer.render("[Swift](https://swift.org)")
        #expect(html.contains("href=\"https://swift.org\""))
        #expect(html.contains("rel=\"noreferrer noopener\""))
    }

    @Test func javascriptLinkIsRejected() {
        let html = MarkdownHTMLRenderer.render("[危险](javascript:alert(1))")
        #expect(!html.contains("href="))
        #expect(html.contains("危险"))
    }

    @Test func rawHTMLIsEscaped() {
        let html = MarkdownHTMLRenderer.render("<script>alert('x')</script>")
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
    }

    @Test func remoteImageIsNotLoaded() {
        let html = MarkdownHTMLRenderer.render("![说明](https://example.com/a.png)")
        #expect(!html.contains("<img"))
        #expect(!html.contains("src="))
        #expect(html.contains("说明"))
    }

    @Test func stableAndDraftRegionsUseBlankLineBoundary() {
        let assembly = MarkdownBlockAssembler.assemble("稳定段落。\n\n正在生成")
        #expect(assembly.stableMarkdown == "稳定段落。\n\n")
        #expect(assembly.draftMarkdown == "正在生成")
    }

    @Test func unclosedFenceRemainsInDraftPlainText() {
        let assembly = MarkdownBlockAssembler.assemble("前文。\n\n```swift\nlet value = 1")
        #expect(assembly.stableMarkdown == "前文。\n\n")
        #expect(assembly.draftRequiresPlainText)
        #expect(!assembly.readableDraftText.contains("```"))
        #expect(assembly.readableDraftText.contains("let value = 1"))
    }

    @Test func fencedCodeAcrossChunksMovesToStableOnlyWhenClosed() {
        let open = MarkdownBlockAssembler.assemble("```swift\nlet value = 1\n")
        let closed = MarkdownBlockAssembler.assemble("```swift\nlet value = 1\n```\n")
        #expect(open.stableMarkdown.isEmpty)
        #expect(open.draftRequiresPlainText)
        #expect(closed.stableMarkdown == "```swift\nlet value = 1\n```\n")
    }

    @Test func tableRowsRemainAUnifiedDraftUntilBlankLine() {
        let partial = MarkdownBlockAssembler.assemble("| A | B |\n| --- | --- |\n")
        let completed = MarkdownBlockAssembler.assemble("| A | B |\n| --- | --- |\n| 1 | 2 |\n\n")
        #expect(partial.stableMarkdown.isEmpty)
        #expect(completed.stableMarkdown.hasSuffix("\n\n"))
        #expect(MarkdownHTMLRenderer.render(completed.stableMarkdown).contains("<table>"))
    }

    @Test func halfLinkUsesReadablePlainTextFallback() {
        let assembly = MarkdownBlockAssembler.assemble("查看 [Swift](https://swift")
        #expect(assembly.draftRequiresPlainText)
        #expect(assembly.readableDraftText == "查看 Swift")
        #expect(!assembly.readableDraftText.contains("]("))
    }

    @Test func unclosedItalicMarkerDoesNotLeakIntoDraft() {
        let assembly = MarkdownBlockAssembler.assemble("这是 *正在生成的强调")
        #expect(assembly.draftRequiresPlainText)
        #expect(!assembly.readableDraftText.contains("*"))
    }

    @Test @MainActor func finishPerformsFullDocumentRender() async {
        var snapshots: [StreamingMarkdownSnapshot] = []
        let buffer = StreamingMarkdownBuffer(throttleDuration: .milliseconds(5))
        let id = UUID()
        await buffer.start(generationID: id) { snapshots.append($0) }
        await buffer.append("**完成**", generationID: id)
        let completed = await buffer.finish(generationID: id)

        #expect(completed?.phase == .completed)
        #expect(completed?.finalHTML?.contains("<strong>完成</strong>") == true)
        #expect(snapshots.last?.phase == .completed)
    }

    @Test @MainActor func compactStreamingDisplayDoesNotExposeUnclosedBoldMarker() async {
        var latest: StreamingMarkdownSnapshot?
        let buffer = StreamingMarkdownBuffer(throttleDuration: .milliseconds(5))
        let id = UUID()
        await buffer.start(generationID: id) { latest = $0 }
        await buffer.append("稳定。\n\n**正在生成", generationID: id)
        try? await Task.sleep(for: .milliseconds(12))
        #expect(latest?.compactDisplayMarkdown.contains("**") == false)
        #expect(latest?.compactDisplayMarkdown.contains("正在生成") == true)
    }

    @Test @MainActor func throttleCoalescesRapidTokens() async {
        var snapshots: [StreamingMarkdownSnapshot] = []
        let buffer = StreamingMarkdownBuffer(throttleDuration: .milliseconds(80))
        let id = UUID()
        await buffer.start(generationID: id) { snapshots.append($0) }
        for token in ["一", "二", "三", "四", "五"] {
            await buffer.append(token, generationID: id)
        }
        try? await Task.sleep(for: .milliseconds(110))

        let streamingEmissions = snapshots.filter { $0.phase == .streaming }
        #expect(streamingEmissions.count == 1)
        #expect(streamingEmissions.last?.markdown == "一二三四五")
    }

    @Test @MainActor func stableHTMLIsNotRepeatedForDraftOnlyChanges() async {
        var snapshots: [StreamingMarkdownSnapshot] = []
        let buffer = StreamingMarkdownBuffer(throttleDuration: .milliseconds(8))
        let id = UUID()
        await buffer.start(generationID: id) { snapshots.append($0) }
        await buffer.append("稳定。\n\n草", generationID: id)
        try? await Task.sleep(for: .milliseconds(16))
        await buffer.append("稿", generationID: id)
        try? await Task.sleep(for: .milliseconds(16))

        let stableValues = snapshots
            .filter { $0.phase == .streaming }
            .map(\.stableHTML)
        #expect(stableValues.count == 2)
        #expect(Set(stableValues).count == 1)
    }

    @Test @MainActor func failurePreservesGeneratedMarkdown() async {
        let buffer = StreamingMarkdownBuffer(throttleDuration: .milliseconds(5))
        let id = UUID()
        await buffer.start(generationID: id) { _ in }
        await buffer.append("已经生成的内容", generationID: id)
        let failed = await buffer.fail(generationID: id)

        #expect(failed?.phase == .failed)
        #expect(failed?.markdown == "已经生成的内容")
    }

    @Test @MainActor func cancellationPreservesGeneratedMarkdown() async {
        let buffer = StreamingMarkdownBuffer(throttleDuration: .milliseconds(5))
        let id = UUID()
        await buffer.start(generationID: id) { _ in }
        await buffer.append("保留草稿", generationID: id)
        let cancelled = await buffer.cancel(generationID: id)

        #expect(cancelled?.phase == .cancelled)
        #expect(cancelled?.markdown == "保留草稿")
    }

    @Test @MainActor func lateTokenFromOldGenerationIsIgnored() async {
        let buffer = StreamingMarkdownBuffer(throttleDuration: .milliseconds(5))
        let oldID = UUID()
        let newID = UUID()
        await buffer.start(generationID: oldID) { _ in }
        await buffer.append("旧", generationID: oldID)
        await buffer.start(generationID: newID) { _ in }
        await buffer.append("错误旧 token", generationID: oldID)
        await buffer.append("新", generationID: newID)
        let completed = await buffer.finish(generationID: newID)

        #expect(completed?.markdown == "新")
    }

    @Test @MainActor func repeatedSequenceIsNotAppendedTwice() async {
        let buffer = StreamingMarkdownBuffer(throttleDuration: .milliseconds(5))
        let id = UUID()
        await buffer.start(generationID: id) { _ in }
        await buffer.append("只出现一次", generationID: id, sequence: 0)
        await buffer.append("只出现一次", generationID: id, sequence: 0)
        let completed = await buffer.finish(generationID: id)
        #expect(completed?.markdown == "只出现一次")
    }

    @Test func themeContainsDarkModeReducedMotionAndDOMPatchAPI() {
        let shell = MarkdownRenderTheme.shell
        #expect(shell.contains("prefers-color-scheme: dark"))
        #expect(shell.contains("prefers-reduced-motion: reduce"))
        #expect(shell.contains("replaceStableContent"))
        #expect(shell.contains("updateDraftPlainText"))
        #expect(shell.contains("ResizeObserver"))
        #expect(shell.contains("scrollToBottomIfNeeded"))
    }

    @Test func renderedStableBlockIDsAreDeterministicAndPrefixPreserving() {
        let first = MarkdownHTMLRenderer.renderBlocks("第一段。\n\n")
        let expanded = MarkdownHTMLRenderer.renderBlocks("第一段。\n\n第二段。\n\n")
        #expect(first.count == 1)
        #expect(expanded.count == 2)
        #expect(first[0] == expanded[0])
    }

    @Test @MainActor func coordinatorKeepsLatestMarkdownForWebProcessRecovery() {
        let coordinator = StreamingMarkdownWebCoordinator()
        coordinator.update(
            markdown: "恢复 **内容**",
            streamingSnapshot: nil,
            baseFontSize: 17
        )
        #expect(coordinator.latestMarkdownForRecovery == "恢复 **内容**")
    }

    @Test func systemPromptDefinesClosedMarkdownProtocol() {
        let prompt = SocraticPromptTemplates.systemPrompt()
        #expect(prompt.contains("Markdown 输出协议"))
        #expect(prompt.contains("禁止输出 HTML"))
        #expect(prompt.contains("语法必须成对、闭合"))
    }
}
