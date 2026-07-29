import SwiftUI
import WebKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct StreamingMarkdownWebView: View {
    let markdown: String
    var streamingSnapshot: StreamingMarkdownSnapshot?
    var baseFontSize: CGFloat = 17
    var minimumHeight: CGFloat = 28

    @State private var measuredHeight: CGFloat = 28

    var body: some View {
        StreamingMarkdownPlatformView(
            markdown: markdown,
            streamingSnapshot: streamingSnapshot,
            baseFontSize: baseFontSize,
            measuredHeight: $measuredHeight
        )
        .frame(height: max(minimumHeight, measuredHeight))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }
}

@MainActor
final class StreamingMarkdownWebCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private weak var webView: WKWebView?
    private var isReady = false
    private var pendingSnapshot: StreamingMarkdownSnapshot?
    private var lastStableHTML: String?
    private var lastDraftHTML: String?
    private var lastDraftPlainText: String?
    private var lastFinalHTML: String?
    private var lastStaticMarkdown: String?
    private var appendedStableBlockIDs: [String] = []
    private var consecutiveJavaScriptFailures = 0
    private var currentFontSize: CGFloat = 17
    var onHeightChange: ((CGFloat) -> Void)?
    var latestMarkdownForRecovery: String? {
        pendingSnapshot?.markdown
    }

    func attach(to webView: WKWebView) {
        self.webView = webView
        isReady = false
        webView.navigationDelegate = self
        webView.loadHTMLString(MarkdownRenderTheme.shell, baseURL: nil)
    }

    func update(
        markdown: String,
        streamingSnapshot: StreamingMarkdownSnapshot?,
        baseFontSize: CGFloat
    ) {
        currentFontSize = baseFontSize

        if let streamingSnapshot {
            pendingSnapshot = streamingSnapshot
        } else if lastStaticMarkdown != markdown || pendingSnapshot == nil {
            lastStaticMarkdown = markdown
            let html = MarkdownHTMLRenderer.render(markdown)
            pendingSnapshot = StreamingMarkdownSnapshot(
                generationID: UUID(),
                revision: 0,
                phase: .completed,
                markdown: markdown,
                stableMarkdown: markdown,
                draftMarkdown: "",
                stableBlocks: MarkdownHTMLRenderer.renderBlocks(markdown),
                stableHTML: html,
                draftHTML: "",
                draftPlainText: nil,
                finalHTML: html
            )
        }

        applyPendingSnapshotIfPossible()
    }

    func invalidate() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "contentHeight")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "rendererReady")
        webView?.navigationDelegate = nil
        webView = nil
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "rendererReady":
            isReady = true
            resetPatchCache()
            applyPendingSnapshotIfPossible()
        case "contentHeight":
            guard let number = message.body as? NSNumber else { return }
            let height = CGFloat(truncating: number)
            guard height.isFinite, height >= 1 else { return }
            onHeightChange?(min(height, 12_000))
        default:
            break
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
        resetPatchCache()
        applyPendingSnapshotIfPossible()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isReady = false
        resetPatchCache()
        webView.loadHTMLString(MarkdownRenderTheme.shell, baseURL: nil)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            decisionHandler(navigationAction.navigationType == .other ? .allow : .cancel)
            return
        }

        openExternalURL(url)
        decisionHandler(.cancel)
    }

    private func applyPendingSnapshotIfPossible() {
        guard isReady, let webView, let snapshot = pendingSnapshot else { return }

        evaluate("window.codesignRenderer.setFontSize(\(Self.numberLiteral(currentFontSize)));", in: webView)

        if let finalHTML = snapshot.finalHTML {
            guard finalHTML != lastFinalHTML else { return }
            evaluate(
                "window.codesignRenderer.finalize(\(Self.jsonLiteral(finalHTML)));",
                in: webView
            )
            lastFinalHTML = finalHTML
            lastStableHTML = finalHTML
            lastDraftHTML = ""
            lastDraftPlainText = nil
            return
        }

        applyStableBlocks(from: snapshot, in: webView)

        if let draftPlainText = snapshot.draftPlainText {
            if draftPlainText != lastDraftPlainText {
                evaluate(
                    "window.codesignRenderer.updateDraftPlainText(\(Self.jsonLiteral(draftPlainText)));",
                    in: webView
                )
                lastDraftPlainText = draftPlainText
                lastDraftHTML = nil
            }
        } else if snapshot.draftHTML != lastDraftHTML {
            evaluate(
                "window.codesignRenderer.updateDraft(\(Self.jsonLiteral(snapshot.draftHTML)));",
                in: webView
            )
            lastDraftHTML = snapshot.draftHTML
            lastDraftPlainText = nil
        }

        let isActivelyStreaming = snapshot.phase == .preparing
            || snapshot.phase == .streaming
            || snapshot.phase == .finalizing
        evaluate(
            "window.codesignRenderer.setStreaming(\(isActivelyStreaming ? "true" : "false"));",
            in: webView
        )
    }

    private func resetPatchCache() {
        lastStableHTML = nil
        lastDraftHTML = nil
        lastDraftPlainText = nil
        lastFinalHTML = nil
        appendedStableBlockIDs = []
        consecutiveJavaScriptFailures = 0
    }

    private func applyStableBlocks(from snapshot: StreamingMarkdownSnapshot, in webView: WKWebView) {
        let incomingIDs = snapshot.stableBlocks.map(\.id)
        let existingCount = appendedStableBlockIDs.count
        let preservesPrefix = incomingIDs.count >= existingCount
            && Array(incomingIDs.prefix(existingCount)) == appendedStableBlockIDs

        if preservesPrefix, incomingIDs.count > existingCount {
            for block in snapshot.stableBlocks.dropFirst(existingCount) {
                evaluate(
                    "window.codesignRenderer.appendStableBlock(\(Self.jsonLiteral(block.id)), \(Self.jsonLiteral(block.html)));",
                    in: webView
                )
            }
            appendedStableBlockIDs = incomingIDs
            lastStableHTML = snapshot.stableHTML
        } else if !preservesPrefix || (snapshot.stableBlocks.isEmpty && lastStableHTML != "") {
            evaluate(
                "window.codesignRenderer.replaceStableContent(\(Self.jsonLiteral(snapshot.stableHTML)));",
                in: webView
            )
            appendedStableBlockIDs = incomingIDs
            lastStableHTML = snapshot.stableHTML
        }
    }

    private func evaluate(_ script: String, in webView: WKWebView) {
        webView.evaluateJavaScript(script) { [weak self, weak webView] _, error in
            guard let self else { return }
            guard error != nil else {
                self.consecutiveJavaScriptFailures = 0
                return
            }
            self.consecutiveJavaScriptFailures += 1
            guard self.consecutiveJavaScriptFailures == 2, let webView else { return }
            self.isReady = false
            self.resetPatchCache()
            webView.loadHTMLString(MarkdownRenderTheme.shell, baseURL: nil)
        }
    }

    private func openExternalURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    nonisolated private static func jsonLiteral(_ value: String) -> String {
        guard JSONSerialization.isValidJSONObject([value]),
              let data = try? JSONSerialization.data(withJSONObject: [value]),
              var json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        json.removeFirst()
        json.removeLast()
        return json
    }

    nonisolated private static func numberLiteral(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }
}

#if os(macOS)
private struct StreamingMarkdownPlatformView: NSViewRepresentable {
    let markdown: String
    let streamingSnapshot: StreamingMarkdownSnapshot?
    let baseFontSize: CGFloat
    @Binding var measuredHeight: CGFloat

    func makeCoordinator() -> StreamingMarkdownWebCoordinator {
        StreamingMarkdownWebCoordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        update(webView: webView, coordinator: context.coordinator)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: StreamingMarkdownWebCoordinator) {
        coordinator.invalidate()
    }

    private func makeWebView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration(context: context))
        webView.underPageBackgroundColor = .clear
        webView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.attach(to: webView)
        return webView
    }

    private func makeConfiguration(context: Context) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "contentHeight")
        configuration.userContentController.add(context.coordinator, name: "rendererReady")
        return configuration
    }

    private func update(webView: WKWebView, coordinator: StreamingMarkdownWebCoordinator) {
        coordinator.onHeightChange = { height in
            if abs(measuredHeight - height) > 0.5 {
                measuredHeight = height
            }
        }
        coordinator.update(
            markdown: markdown,
            streamingSnapshot: streamingSnapshot,
            baseFontSize: baseFontSize
        )
    }
}
#else
private struct StreamingMarkdownPlatformView: UIViewRepresentable {
    let markdown: String
    let streamingSnapshot: StreamingMarkdownSnapshot?
    let baseFontSize: CGFloat
    @Binding var measuredHeight: CGFloat

    func makeCoordinator() -> StreamingMarkdownWebCoordinator {
        StreamingMarkdownWebCoordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        update(webView: webView, coordinator: context.coordinator)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: StreamingMarkdownWebCoordinator) {
        coordinator.invalidate()
    }

    private func makeWebView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration(context: context))
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.underPageBackgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.backgroundColor = .clear
        context.coordinator.attach(to: webView)
        return webView
    }

    private func makeConfiguration(context: Context) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "contentHeight")
        configuration.userContentController.add(context.coordinator, name: "rendererReady")
        return configuration
    }

    private func update(webView: WKWebView, coordinator: StreamingMarkdownWebCoordinator) {
        coordinator.onHeightChange = { height in
            if abs(measuredHeight - height) > 0.5 {
                measuredHeight = height
            }
        }
        coordinator.update(
            markdown: markdown,
            streamingSnapshot: streamingSnapshot,
            baseFontSize: baseFontSize
        )
    }
}
#endif
