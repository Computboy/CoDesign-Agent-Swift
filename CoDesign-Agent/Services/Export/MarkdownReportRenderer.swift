import Foundation

struct MarkdownReportRenderer {
    func render(snapshot: ProjectReportSnapshot) -> String {
        var lines: [String] = []
        append(&lines, "# AI 产品设计报告")
        append(&lines, "")
        appendSection0(&lines, snapshot: snapshot)
        appendProjectSummary(&lines, snapshot: snapshot)
        appendAIValueHypothesis(&lines, snapshot: snapshot)
        appendBehaviorSpec(&lines, snapshot: snapshot)
        appendRewardFunction(&lines, snapshot: snapshot)
        appendFailureRecovery(&lines, snapshot: snapshot)
        appendInterventionSpec(&lines, snapshot: snapshot)
        appendDecisionTrace(&lines, snapshot: snapshot)
        appendResources(&lines, snapshot: snapshot)

        if snapshot.exportOptions.includeFullMindTree {
            appendMindTreeAppendix(&lines, snapshot: snapshot)
        }

        if snapshot.exportOptions.includeConversationSummary,
           let conversationSummary = snapshot.processEvidence.conversationSummary {
            append(&lines, "## 附录 B：对话摘要")
            append(&lines, "")
            append(&lines, conversationSummary)
            append(&lines, "")
        }

        if !snapshot.exportOptions.includeDesignBrief {
            append(&lines, "> 本报告导出时未包含 Design Brief 详情。")
            append(&lines, "")
        }

        return lines.joined(separator: "\n")
    }

    private func appendSection0(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 0. 项目信息")
        append(&lines, "")
        appendKeyValue(&lines, "项目名称", snapshot.project.name)
        appendKeyValue(&lines, "一句话描述", snapshot.project.briefDescription)
        appendKeyValue(&lines, "创建时间", formatDate(snapshot.project.createdAt))
        appendKeyValue(&lines, "更新时间", formatDate(snapshot.project.updatedAt))
        appendKeyValue(&lines, "导出时间", formatDate(snapshot.exportedAt))
        appendKeyValue(&lines, "完成度", "\(Int(snapshot.project.completionRate * 100))%")
        append(&lines, "")
    }

    private func appendProjectSummary(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 1. 项目摘要")
        append(&lines, "")
        appendDictionary(&lines, snapshot.reportSections.projectSummary)
    }

    private func appendAIValueHypothesis(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 2. AI 价值假设")
        append(&lines, "")
        appendDictionary(&lines, snapshot.reportSections.aiValueHypothesis)
    }

    private func appendBehaviorSpec(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 3. Behavior Spec")
        append(&lines, "")

        for key in ["UNDERSTAND", "CAPABILITY", "BOUNDARY"] {
            append(&lines, "### 3.\(sectionNumber(for: key)) \(key)")
            append(&lines, "")
            appendDictionary(&lines, snapshot.reportSections.behaviorSpec[key] ?? [:])
        }

        append(&lines, "### 3.4 三角自洽性检查")
        append(&lines, "")
        let hasEmptyBriefField = [
            snapshot.brief.targetUser,
            snapshot.brief.painPoint,
            snapshot.brief.useScenario,
            snapshot.brief.coreValue,
            snapshot.brief.operationLogic
        ].contains { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty
        }

        if hasEmptyBriefField {
            append(&lines, "* 核心 U/C/B 字段尚未全部形成，报告仅呈现已确认内容。")
        } else {
            append(&lines, "* 核心 U/C/B 字段已形成，可进入人工复核。")
        }
        append(&lines, "")
    }

    private func appendRewardFunction(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 4. Reward Function")
        append(&lines, "")

        if snapshot.brief.successMetrics.isEmpty {
            append(&lines, "暂无已确认的量化指标。")
            append(&lines, "")
        } else {
            append(&lines, "| 指标名称 | 测量方式 | 阈值 |")
            append(&lines, "| --- | --- | --- |")
            for metric in snapshot.brief.successMetrics {
                append(&lines, "| \(cell(metric.metric)) | \(cell(displayValue(metric.measurement))) | \(cell(metric.target)) |")
            }
            append(&lines, "")
        }

        appendKeyValueIfPresent(&lines, "Goodhart 自查", snapshot.reportSections.rewardFunction["Goodhart 自查"])
        append(&lines, "")
    }

    private func appendFailureRecovery(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 5. Failure & Recovery")
        append(&lines, "")

        if snapshot.brief.risks.isEmpty {
            append(&lines, "### 待分类风险")
            append(&lines, "")
            append(&lines, "暂无已确认风险。")
            append(&lines, "")
        } else {
            append(&lines, "### 待分类风险")
            append(&lines, "")
            append(&lines, "| 风险描述 | 概率 | 影响 | 应对措施 |")
            append(&lines, "| --- | --- | --- | --- |")
            for risk in snapshot.brief.risks {
                append(&lines, "| \(cell(risk.desc)) | \(risk.probability)/5 | \(risk.impact)/5 | \(cell(displayValue(risk.mitigation))) |")
            }
            append(&lines, "")
        }

        appendDictionary(&lines, snapshot.reportSections.failureRecovery)
        append(&lines, "")
    }

    private func appendInterventionSpec(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 6. Intervention Spec")
        append(&lines, "")

        appendDictionary(&lines, snapshot.reportSections.interventionSpec)
    }

    private func appendDecisionTrace(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 7. 设计决策路径")
        append(&lines, "")

        guard !snapshot.processEvidence.decisionTrace.isEmpty else {
            append(&lines, "暂无设计决策路径。")
            append(&lines, "")
            return
        }

        for item in snapshot.processEvidence.decisionTrace {
            append(&lines, "* 阶段：Stage \(item.stageOrder) / \(item.stageTitle)")
            append(&lines, "  * 类型：\(item.type)")
            append(&lines, "  * 内容：\(item.content)")
            if let relatedField = item.relatedField {
                append(&lines, "  * 关联字段：\(relatedField)")
            }
            append(&lines, "  * 时间：\(formatDate(item.timestamp))")
            if !item.isActiveBranch {
                append(&lines, "  * 分支：旧分支 v\(item.branchVersion)")
            }
        }
        append(&lines, "")
    }

    private func appendResources(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 8. 资源线索")
        append(&lines, "")

        guard snapshot.exportOptions.includeResources else {
            append(&lines, "本次导出未包含资源线索。")
            append(&lines, "")
            return
        }

        guard !snapshot.processEvidence.resources.isEmpty else {
            append(&lines, "暂无可导出的资源线索。")
            append(&lines, "")
            return
        }

        for resource in snapshot.processEvidence.resources {
            append(&lines, "### \(resource.title)")
            append(&lines, "")
            appendKeyValue(&lines, "摘要", resource.summary)
            appendKeyValueIfPresent(&lines, "来源 / URL", resource.sourceURL)
            appendKeyValueIfPresent(&lines, "引用", resource.citation)
            appendKeyValueIfPresent(&lines, "作者", resource.authors)
            appendKeyValueIfPresent(&lines, "年份", resource.year.map(String.init))
            appendKeyValueIfPresent(&lines, "venue", resource.venue)
            appendKeyValue(&lines, "关联阶段", resource.relatedStages.map { "Stage \($0)" }.joined(separator: "、"))
            appendKeyValue(&lines, "tags", resource.tags.joined(separator: "、"))
            appendKeyValue(&lines, "whyRelevant", resource.whyRelevant)
            appendKeyValue(&lines, "howToUse", resource.howToUse)
            appendKeyValueIfPresent(&lines, "researchInsight", resource.researchInsight)
            appendKeyValueIfPresent(&lines, "designImplication", resource.designImplication)
            append(&lines, "")
        }
    }

    private func appendMindTreeAppendix(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 附录 A：完整思维树")
        append(&lines, "")
        append(&lines, "<details>")
        append(&lines, "<summary>展开完整 thinkingMoments outline</summary>")
        append(&lines, "")

        guard !snapshot.processEvidence.thinkingMoments.isEmpty else {
            append(&lines, "暂无完整思维树节点。")
            append(&lines, "")
            append(&lines, "</details>")
            append(&lines, "")
            return
        }

        for moment in snapshot.processEvidence.thinkingMoments {
            append(&lines, "* id：\(moment.id)")
            append(&lines, "  * parentMomentID：\(moment.parentMomentID ?? "nil")")
            append(&lines, "  * stageOrder：\(moment.stageOrder)")
            append(&lines, "  * momType：\(moment.momType)")
            append(&lines, "  * content：\(moment.content)")
            append(&lines, "  * relatedField：\(moment.relatedField ?? "nil")")
            append(&lines, "  * isActiveBranch：\(moment.isActiveBranch)")
            append(&lines, "  * branchVersion：\(moment.branchVersion)")
            append(&lines, "  * archivedAt：\(moment.archivedAt.map { formatDate($0) } ?? "nil")")
        }

        append(&lines, "")
        append(&lines, "</details>")
        append(&lines, "")
    }

    private func appendDictionary(_ lines: inout [String], _ dictionary: [String: String]) {
        if dictionary.isEmpty {
            appendEmptyNotice(&lines)
            append(&lines, "")
            return
        }

        var appended = false
        for key in dictionary.keys.sorted() {
            if appendKeyValueIfPresent(&lines, key, dictionary[key]) {
                appended = true
            }
        }
        if !appended {
            appendEmptyNotice(&lines)
        }
        append(&lines, "")
    }

    private func appendKeyValue(_ lines: inout [String], _ key: String, _ value: String) {
        append(&lines, "- **\(key)**：\(displayValue(value))")
    }

    @discardableResult
    private func appendKeyValueIfPresent(_ lines: inout [String], _ key: String, _ value: String?) -> Bool {
        guard let value = meaningfulValue(value) else { return false }
        appendKeyValue(&lines, key, value)
        return true
    }

    private func appendEmptyNotice(_ lines: inout [String]) {
        append(&lines, "暂无已确认内容。")
    }

    private func append(_ lines: inout [String], _ line: String) {
        lines.append(line)
    }

    private func sectionNumber(for key: String) -> String {
        switch key {
        case "UNDERSTAND": return "1"
        case "CAPABILITY": return "2"
        case "BOUNDARY": return "3"
        default: return "0"
        }
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func cell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "|", with: "\\|")
    }

    private func displayValue(_ value: String?) -> String {
        meaningfulValue(value) ?? "未记录"
    }

    private func meaningfulValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let disallowedFragments = [
            ReportSnapshotValue.missing,
            "需要补充",
            "待人工确认",
            "______"
        ]
        guard !disallowedFragments.contains(where: { trimmed.contains($0) }) else {
            return nil
        }
        return trimmed
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
