import Foundation

struct DeferredStageConfirmation {
    enum Resolution: Equatable {
        case confirmed
        case revisedOrRejected
        case unresolved
    }

    func resolve(_ response: String) -> Resolution {
        let normalized = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let compact = normalized.filter {
            !$0.isWhitespace && !$0.isPunctuation
        }

        let revisionMarkers = [
            "不对",
            "不是",
            "有误",
            "不准确",
            "不确定",
            "需要修改",
            "需要调整",
            "改成",
            "改为",
            "调整为",
            "应该",
            "应该是",
            "实际上",
            "但",
            "不过",
            "跳过",
            "先不",
            "取消",
        ]
        if revisionMarkers.contains(where: { compact.contains($0) }) {
            return .revisedOrRejected
        }

        let exactConfirmations = [
            "是",
            "是的",
            "对",
            "对的",
            "好的",
            "好",
            "确认",
            "可以",
            "就这样",
        ]
        if exactConfirmations.contains(compact) {
            return .confirmed
        }

        let confirmationMarkers = [
            "确认无误",
            "没有变化",
            "没问题",
            "没错",
            "都对",
            "都准确",
            "仍然准确",
            "保持不变",
        ]
        if confirmationMarkers.contains(where: { compact.contains($0) }) {
            return .confirmed
        }

        return .unresolved
    }

    func question(
        stageOrder: Int,
        stageName: String,
        candidates: [(field: BriefField, value: String)]
    ) -> String {
        let candidateLines = candidates.map { candidate in
            "- **\(candidate.field.displayName)**：\(compactValue(candidate.value))"
        }
        let isSingleCandidate = candidates.count == 1
        let lead = isSingleCandidate
            ? "你前面提到过一条与 Stage \(stageOrder)「\(stageName)」有关的信息。我先把它作为候选保留了下来，没有提前完成这个阶段："
            : "你前面已经提到过一些与 Stage \(stageOrder)「\(stageName)」有关的信息。我先把它作为候选保留了下来，没有提前完成这个阶段："
        let confirmationTarget = isSingleCandidate ? "这条内容" : "以上内容"

        return """
        \(lead)

        \(candidateLines.joined(separator: "\n"))

        现在我们正式进入这个阶段。请确认：\(confirmationTarget)现在仍然准确吗？如果有变化，直接告诉我需要修改的部分。
        """
    }

    private func compactValue(_ value: String) -> String {
        let compact = value
            .split(whereSeparator: \.isNewline)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "；")

        guard compact.count > 240 else { return compact }
        return String(compact.prefix(240)) + "…"
    }
}
