import Foundation

actor StreamingMarkdownBuffer {
    typealias SnapshotSink = @MainActor @Sendable (StreamingMarkdownSnapshot) -> Void

    private let throttleDuration: Duration
    private var generationID = UUID()
    private var markdown = ""
    private var revision = 0
    private var lastSequence = -1
    private var phase: StreamingMarkdownPhase = .idle
    private var pendingFlush: Task<Void, Never>?
    private var sink: SnapshotSink?

    init(throttleDuration: Duration = .milliseconds(80)) {
        self.throttleDuration = throttleDuration
    }

    func start(generationID: UUID, sink: @escaping SnapshotSink) async {
        pendingFlush?.cancel()
        self.generationID = generationID
        self.sink = sink
        markdown = ""
        revision = 0
        lastSequence = -1
        phase = .preparing
        await emit(renderSnapshot())
    }

    func append(_ delta: String, generationID: UUID, sequence: Int? = nil) {
        guard generationID == self.generationID,
              phase == .preparing || phase == .streaming,
              !delta.isEmpty else {
            return
        }
        if let sequence {
            guard sequence > lastSequence else { return }
            lastSequence = sequence
        }

        markdown += delta
        phase = .streaming
        scheduleFlush(forceSoon: delta.contains("\n\n") || delta.contains("```"))
    }

    func finish(generationID: UUID) async -> StreamingMarkdownSnapshot? {
        guard generationID == self.generationID,
              phase == .preparing || phase == .streaming else {
            return nil
        }

        pendingFlush?.cancel()
        pendingFlush = nil
        phase = .finalizing
        await emit(renderSnapshot())
        phase = .completed
        let snapshot = renderSnapshot(final: true)
        await emit(snapshot)
        return snapshot
    }

    func fail(generationID: UUID) async -> StreamingMarkdownSnapshot? {
        await terminate(generationID: generationID, as: .failed)
    }

    func cancel(generationID: UUID) async -> StreamingMarkdownSnapshot? {
        await terminate(generationID: generationID, as: .cancelled)
    }

    func currentSnapshot() -> StreamingMarkdownSnapshot {
        renderSnapshot(final: phase == .completed)
    }

    private func terminate(
        generationID: UUID,
        as terminalPhase: StreamingMarkdownPhase
    ) async -> StreamingMarkdownSnapshot? {
        guard generationID == self.generationID,
              phase != .completed,
              phase != .failed,
              phase != .cancelled else {
            return nil
        }
        pendingFlush?.cancel()
        pendingFlush = nil
        phase = terminalPhase
        let snapshot = renderSnapshot()
        await emit(snapshot)
        return snapshot
    }

    private func scheduleFlush(forceSoon: Bool) {
        guard pendingFlush == nil else { return }
        let expectedGeneration = generationID
        let delay = forceSoon ? min(throttleDuration, .milliseconds(24)) : throttleDuration

        pendingFlush = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self.flush(generationID: expectedGeneration)
        }
    }

    private func flush(generationID: UUID) async {
        pendingFlush = nil
        guard generationID == self.generationID,
              phase == .preparing || phase == .streaming else {
            return
        }
        await emit(renderSnapshot())
    }

    private func renderSnapshot(final: Bool = false) -> StreamingMarkdownSnapshot {
        revision += 1
        let assembly = MarkdownBlockAssembler.assemble(markdown)

        if final {
            let finalHTML = MarkdownHTMLRenderer.render(assembly.source)
            return StreamingMarkdownSnapshot(
                generationID: generationID,
                revision: revision,
                phase: phase,
                markdown: assembly.source,
                stableMarkdown: assembly.source,
                draftMarkdown: "",
                stableBlocks: MarkdownHTMLRenderer.renderBlocks(assembly.source),
                stableHTML: finalHTML,
                draftHTML: "",
                draftPlainText: nil,
                finalHTML: finalHTML
            )
        }

        return StreamingMarkdownSnapshot(
            generationID: generationID,
            revision: revision,
            phase: phase,
            markdown: assembly.source,
            stableMarkdown: assembly.stableMarkdown,
            draftMarkdown: assembly.draftMarkdown,
            stableBlocks: MarkdownHTMLRenderer.renderBlocks(assembly.stableMarkdown),
            stableHTML: MarkdownHTMLRenderer.render(assembly.stableMarkdown),
            draftHTML: assembly.draftRequiresPlainText
                ? ""
                : MarkdownHTMLRenderer.render(assembly.draftMarkdown),
            draftPlainText: assembly.draftRequiresPlainText
                ? assembly.readableDraftText
                : nil,
            finalHTML: nil
        )
    }

    private func emit(_ snapshot: StreamingMarkdownSnapshot) async {
        guard let sink else { return }
        await sink(snapshot)
    }
}
