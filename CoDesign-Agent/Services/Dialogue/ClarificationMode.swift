import Foundation

enum ClarificationMode: String, Hashable {
    case normal
    case stuckScaffold
    case exampleRequested
    case reframe
    case skip

    static func detect(from text: String) -> ClarificationMode {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if containsAny(normalized, [
            "给我一个例子",
            "给个例子",
            "举个例子",
            "例子",
            "示例",
            "怎么回答"
        ]) {
            return .exampleRequested
        }

        if containsAny(normalized, [
            "我还不确定",
            "不确定",
            "我不知道",
            "不知道",
            "想不出来",
            "没想好",
            "卡住了",
            "不会答",
            "没有思路",
            "没思路",
            "没想法"
        ]) {
            return .stuckScaffold
        }

        if containsAny(normalized, [
            "换个角度",
            "重新问",
            "换一种问法",
            "换个问法"
        ]) {
            return .reframe
        }

        if containsAny(normalized, [
            "跳过",
            "先跳过",
            "下一个"
        ]) {
            return .skip
        }

        return .normal
    }

    private static func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.contains($0.lowercased()) }
    }
}
