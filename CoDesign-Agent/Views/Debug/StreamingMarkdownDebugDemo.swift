#if DEBUG
import Observation
import SwiftUI

@MainActor
@Observable
private final class StreamingMarkdownDebugController {
    var snapshot: StreamingMarkdownSnapshot?
    var chunkSize = 4.0
    var intervalMilliseconds = 45.0
    var isPaused = false

    @ObservationIgnored private let buffer = StreamingMarkdownBuffer()
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var generationID: UUID?

    let sample = """
    ## 一次可读的流式回答

    这里有一段 **逐块到达的强调文本**，Markdown 标记不应该裸露。

    - 第一项说明稳定块
    - 第二项包含 `inline code`
    - 第三项提供 [官方链接](https://www.swift.org)

    > 即使网络分块切在语法中间，草稿区也应保持可读。

    | 状态 | 行为 |
    | --- | --- |
    | streaming | 增量更新 |
    | completed | 全文重解析 |

    ```swift
    let answer = "safe"
    print(answer)
    ```
    """

    func start(simulateFailure: Bool = false) {
        playbackTask?.cancel()
        isPaused = false
        let id = UUID()
        generationID = id
        snapshot = nil

        playbackTask = Task { [weak self] in
            guard let self else { return }
            await buffer.start(generationID: id) { [weak self] snapshot in
                guard self?.generationID == snapshot.generationID else { return }
                self?.snapshot = snapshot
            }

            let chunks = sample.chunked(maxLength: max(1, Int(chunkSize)))
            for (index, chunk) in chunks.enumerated() {
                guard !Task.isCancelled, generationID == id else { return }
                while isPaused, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(40))
                }
                if simulateFailure, index >= chunks.count / 2 {
                    _ = await buffer.fail(generationID: id)
                    return
                }
                await buffer.append(chunk, generationID: id)
                try? await Task.sleep(for: .milliseconds(Int(intervalMilliseconds)))
            }
            _ = await buffer.finish(generationID: id)
        }
    }

    func togglePause() {
        isPaused.toggle()
    }

    func cancel() {
        guard let generationID else { return }
        playbackTask?.cancel()
        Task {
            _ = await buffer.cancel(generationID: generationID)
        }
    }
}

private extension String {
    nonisolated func chunked(maxLength: Int) -> [String] {
        guard maxLength > 0 else { return [self] }
        var chunks: [String] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: maxLength, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[index..<end]))
            index = end
        }
        return chunks
    }
}

struct StreamingMarkdownDebugDemo: View {
    @State private var controller = StreamingMarkdownDebugController()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("开始") { controller.start() }
                Button(controller.isPaused ? "继续" : "暂停") { controller.togglePause() }
                Button("取消") { controller.cancel() }
                Button("模拟错误") { controller.start(simulateFailure: true) }
                Button("重新生成") { controller.start() }
            }

            HStack {
                Text("Chunk \(Int(controller.chunkSize))")
                Slider(value: $controller.chunkSize, in: 1...20, step: 1)
                Text("\(Int(controller.intervalMilliseconds)) ms")
                Slider(value: $controller.intervalMilliseconds, in: 10...250, step: 5)
            }

            ScrollView {
                StreamingMarkdownWebView(
                    markdown: controller.snapshot?.markdown ?? "",
                    streamingSnapshot: controller.snapshot,
                    baseFontSize: 18
                )
                .padding()
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(24)
        .onAppear { controller.start() }
    }
}

#Preview("Streaming Markdown") {
    StreamingMarkdownDebugDemo()
        .frame(width: 900, height: 700)
}
#endif
