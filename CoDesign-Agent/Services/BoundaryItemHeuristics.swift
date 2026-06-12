import Foundation

enum BoundaryItemHeuristics {
    static func completionRatio(for items: [BoundaryItemDTO]) -> Double {
        let meaningfulItems = items.filter { isMeaningfulBoundaryContent($0.content) }
        guard !meaningfulItems.isEmpty else { return 0 }

        let hasIncluded = meaningfulItems.contains { $0.isIncluded }
        let hasExcluded = meaningfulItems.contains { !$0.isIncluded }

        if hasIncluded && hasExcluded { return 1 }
        return 0.5
    }

    static func isMeaningfulBoundaryContent(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isScheduleOnly(trimmed)
    }

    static func isScheduleOnly(_ content: String) -> Bool {
        let compact = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .lowercased()

        guard !compact.isEmpty else { return false }

        let hasTimeExpression =
            compact.range(
                of: #"(\d+|[一二两三四五六七八九十半]+)(天|日|周|星期|个月|月|年|小时|分钟|h|d|day|days|week|weeks|month|months)"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
            || containsAny(["ddl", "deadline", "排期", "工期", "周期", "截止", "期限", "时间"], in: compact)

        guard hasTimeExpression else { return false }

        let hasBoundaryIntent = containsAny(
            [
                "只做", "不做", "暂不", "先做", "后续", "包含", "包括", "排除",
                "保留", "聚焦", "范围", "边界", "mvp", "核心功能", "功能", "模块", "流程", "版本",
            ],
            in: compact
        )
        let isShortDeadline = compact.count <= 12
            && containsAny(["完成", "做完", "交付", "截止", "ddl", "deadline"], in: compact)

        return !hasBoundaryIntent || isShortDeadline
    }

    private static func containsAny(_ terms: [String], in text: String) -> Bool {
        terms.contains { text.contains($0.lowercased()) }
    }
}
