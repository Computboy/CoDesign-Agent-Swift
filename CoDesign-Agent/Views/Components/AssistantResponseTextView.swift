import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Semantic AI-response renderer shared by live and persisted assistant messages.
///
/// Static messages are parsed once by the web coordinator. Streaming messages receive
/// already parsed stable/draft HTML snapshots from `StreamingMarkdownBuffer`.
struct AssistantResponseTextView: View {
    let text: String
    var streamingSnapshot: StreamingMarkdownSnapshot?
    var baseFontSize: CGFloat = 17

    var body: some View {
        StreamingMarkdownWebView(
            markdown: text,
            streamingSnapshot: streamingSnapshot,
            baseFontSize: scaledBaseFontSize
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .layoutPriority(1)
    }

    private var scaledBaseFontSize: CGFloat {
        #if os(macOS)
        baseFontSize
        #else
        UIFontMetrics(forTextStyle: .body).scaledValue(for: baseFontSize)
        #endif
    }
}
