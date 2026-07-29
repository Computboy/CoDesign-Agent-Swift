import Foundation

nonisolated enum StreamingMarkdownPhase: String, Sendable, Equatable {
    case idle
    case preparing
    case streaming
    case finalizing
    case completed
    case failed
    case cancelled
}

nonisolated struct StreamingMarkdownSnapshot: Sendable, Equatable {
    let generationID: UUID
    let revision: Int
    let phase: StreamingMarkdownPhase
    let markdown: String
    let stableMarkdown: String
    let draftMarkdown: String
    let stableBlocks: [RenderedMarkdownBlock]
    let stableHTML: String
    let draftHTML: String
    let draftPlainText: String?
    let finalHTML: String?

    static let idle = StreamingMarkdownSnapshot(
        generationID: UUID(),
        revision: 0,
        phase: .idle,
        markdown: "",
        stableMarkdown: "",
        draftMarkdown: "",
        stableBlocks: [],
        stableHTML: "",
        draftHTML: "",
        draftPlainText: nil,
        finalHTML: nil
    )

    var hasVisibleContent: Bool {
        !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Markdown-safe text for compact native views that do not host the WebView.
    var compactDisplayMarkdown: String {
        stableMarkdown + (draftPlainText ?? draftMarkdown)
    }
}

nonisolated struct RenderedMarkdownBlock: Sendable, Equatable {
    let id: String
    let html: String
}

nonisolated struct MarkdownBlockAssembly: Sendable, Equatable {
    let source: String
    let stableMarkdown: String
    let draftMarkdown: String
    let draftRequiresPlainText: Bool
    let readableDraftText: String
}
