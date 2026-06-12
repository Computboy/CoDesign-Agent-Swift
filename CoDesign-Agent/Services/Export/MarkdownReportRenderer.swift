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
        appendKeyValue(&lines, "一句话描述", ReportSnapshotValue.text(snapshot.project.briefDescription))
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

        append(&lines, "* U 要求的 Bloom 层级 ≤ C 能达到的层级：待人工确认")
        append(&lines, "* C 能做的范围 ≤ B 允许的范围：待人工确认")
        append(&lines, "* B 允许的范围 ≥ U 真正需要的范围：待人工确认")
        append(&lines, "* 三角任一支柱无空缺：\(hasEmptyBriefField ? "待补充" : "通过")")
        append(&lines, "* 是否需要回环修订 Step 1：待人工确认")
        append(&lines, "")
    }

    private func appendRewardFunction(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 4. Reward Function")
        append(&lines, "")

        if snapshot.brief.successMetrics.isEmpty {
            append(&lines, "暂无量化指标，待补充。")
            append(&lines, "")
        } else {
            append(&lines, "| 指标名称 | 测量方式 | 阈值 | 当前状态 |")
            append(&lines, "| --- | --- | --- | --- |")
            for metric in snapshot.brief.successMetrics {
                append(&lines, "| \(cell(metric.metric)) | \(cell(metric.measurement ?? ReportSnapshotValue.missing)) | \(cell(metric.target)) | 待补充 |")
            }
            append(&lines, "")
        }

        appendKeyValue(&lines, "Goodhart 自查", snapshot.reportSections.rewardFunction["Goodhart 自查"] ?? ReportSnapshotValue.missing)
        append(&lines, "")
        append(&lines, "Action Plan：")
        append(&lines, "")
        append(&lines, "* 如果 ______ 跌破 ______，我们将 ______。")
        append(&lines, "* 如果 ______ 超过 ______，我们将 ______。")
        append(&lines, "* 如果 ______ 跌破 ______，我们将 ______。")
        append(&lines, "")
    }

    private func appendFailureRecovery(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 5. Failure & Recovery")
        append(&lines, "")

        if snapshot.brief.risks.isEmpty {
            append(&lines, "### 待分类风险")
            append(&lines, "")
            append(&lines, "待补充")
            append(&lines, "")
        } else {
            append(&lines, "### 待分类风险")
            append(&lines, "")
            append(&lines, "| 风险描述 | 概率 | 影响 | 应对措施 |")
            append(&lines, "| --- | --- | --- | --- |")
            for risk in snapshot.brief.risks {
                append(&lines, "| \(cell(risk.desc)) | \(risk.probability)/5 | \(risk.impact)/5 | \(cell(risk.mitigation ?? ReportSnapshotValue.missing)) |")
            }
            append(&lines, "")
        }

        append(&lines, "### U-failure")
        append(&lines, "")
        append(&lines, "待补充")
        append(&lines, "")
        append(&lines, "### C-failure")
        append(&lines, "")
        append(&lines, "待补充")
        append(&lines, "")
        append(&lines, "### B-failure")
        append(&lines, "")
        append(&lines, "待补充")
        append(&lines, "")
        append(&lines, "| 层级 | Communicate 告知 | Empower 赋能 | Reduce future 减少再发 |")
        append(&lines, "| --- | --- | --- | --- |")
        for level in ["模型层", "交互层", "流程层", "责任层"] {
            append(&lines, "| \(level) | 待补充 | 待补充 | 待补充 |")
        }
        append(&lines, "")
    }

    private func appendInterventionSpec(_ lines: inout [String], snapshot: ProjectReportSnapshot) {
        append(&lines, "## 6. Intervention Spec")
        append(&lines, "")

        let sections: [(String, String)] = [
            ("6.1 时机", snapshot.reportSections.interventionSpec["时机"] ?? ReportSnapshotValue.missing),
            ("6.2 强度", "待补充\n\n提示 / 建议 / 默认 / 自动执行 / 强制阻止"),
            ("6.3 可见", "存在：待补充\n\n状态：待补充\n\n依据：待补充\n\n不确定性：待补充"),
            ("6.4 干预", "暂停：待补充\n\n覆盖：待补充\n\n质疑：待补充\n\n恢复：待补充"),
            ("6.5 实际场景验证", snapshot.reportSections.interventionSpec["实际场景验证"] ?? ReportSnapshotValue.missing),
            ("6.6 失败恢复", "发现：\(snapshot.reportSections.interventionSpec["失败恢复"] ?? ReportSnapshotValue.missing)\n\n解释：待补充\n\n修正：待补充\n\n追责：待补充"),
            ("6.7 关系识别", "用户：待补充\n\nAI：待补充\n\n平台：待补充\n\n组织：待补充\n\n第三方：待补充"),
            ("6.8 层级定位", "微观：待补充\n\n中观：待补充\n\n宏观：待补充")
        ]

        for (title, body) in sections {
            append(&lines, "### \(title)")
            append(&lines, "")
            append(&lines, body)
            append(&lines, "")
        }
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
            appendKeyValue(&lines, "来源 / URL", resource.sourceURL ?? ReportSnapshotValue.missing)
            appendKeyValue(&lines, "引用", resource.citation ?? ReportSnapshotValue.missing)
            appendKeyValue(&lines, "作者", resource.authors ?? ReportSnapshotValue.missing)
            appendKeyValue(&lines, "年份", resource.year.map(String.init) ?? ReportSnapshotValue.missing)
            appendKeyValue(&lines, "venue", resource.venue ?? ReportSnapshotValue.missing)
            appendKeyValue(&lines, "关联阶段", resource.relatedStages.map { "Stage \($0)" }.joined(separator: "、"))
            appendKeyValue(&lines, "tags", resource.tags.joined(separator: "、"))
            appendKeyValue(&lines, "whyRelevant", resource.whyRelevant)
            appendKeyValue(&lines, "howToUse", resource.howToUse)
            appendKeyValue(&lines, "researchInsight", resource.researchInsight ?? ReportSnapshotValue.missing)
            appendKeyValue(&lines, "designImplication", resource.designImplication ?? ReportSnapshotValue.missing)
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
            append(&lines, "待补充")
            append(&lines, "")
            return
        }

        for key in dictionary.keys.sorted() {
            appendKeyValue(&lines, key, dictionary[key] ?? ReportSnapshotValue.missing)
        }
        append(&lines, "")
    }

    private func appendKeyValue(_ lines: inout [String], _ key: String, _ value: String) {
        append(&lines, "- **\(key)**：\(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ReportSnapshotValue.missing : value)")
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
