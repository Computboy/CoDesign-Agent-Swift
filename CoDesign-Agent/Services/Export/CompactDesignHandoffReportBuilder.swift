import Foundation

/// 将已确认的 Brief 数据整理为 PDF 专用的文档模型。
/// 此层负责选择、清理、去重和条件渲染，不参与任何 PDF 绘制。
struct ReportContentBuilder {
    func build(snapshot: ProjectReportSnapshot) -> ReportDocumentModel {
        var facts = ReportFactRegistry()
        let brief = snapshot.brief
        let semantic = ReportSemanticMapper().map(brief: brief)

        return ReportDocumentModel(
            title: ReportCopy.documentTitle,
            subtitle: ReportCopy.documentSubtitle,
            projectName: publicProjectName(snapshot.project.name),
            metadata: [
                ReportMetadata(label: ReportCopy.exportDate, value: reportDate(snapshot.exportedAt))
            ],
            sections: [
                ReportSection(
                    id: .projectDefinition,
                    title: ReportCopy.Section.projectDefinition.0,
                    englishTitle: ReportCopy.Section.projectDefinition.1,
                    purpose: ReportCopy.Section.projectDefinitionPurpose,
                    blocks: projectDefinitionBlocks(snapshot: snapshot, brief: brief, facts: &facts)
                ),
                ReportSection(
                    id: .productScope,
                    title: ReportCopy.Section.productScope.0,
                    englishTitle: ReportCopy.Section.productScope.1,
                    purpose: ReportCopy.Section.productScopePurpose,
                    blocks: productScopeBlocks(brief: brief, facts: &facts)
                ),
                ReportSection(
                    id: .coreExperienceFlow,
                    title: ReportCopy.Section.coreExperienceFlow.0,
                    englishTitle: ReportCopy.Section.coreExperienceFlow.1,
                    purpose: ReportCopy.Section.coreExperienceFlowPurpose,
                    blocks: coreExperienceFlowBlocks(brief: brief, facts: &facts)
                ),
                ReportSection(
                    id: .aiBehaviorBoundary,
                    title: ReportCopy.Section.aiBehavior.0,
                    englishTitle: ReportCopy.Section.aiBehavior.1,
                    purpose: ReportCopy.Section.aiBehaviorPurpose,
                    blocks: aiBehaviorBlocks(semantic: semantic, facts: &facts)
                ),
                ReportSection(
                    id: .validationRisks,
                    title: ReportCopy.Section.validation.0,
                    englishTitle: ReportCopy.Section.validation.1,
                    purpose: ReportCopy.Section.validationPurpose,
                    blocks: validationRiskBlocks(brief: brief, semantic: semantic, facts: &facts)
                ),
            ]
        )
    }

    private func projectDefinitionBlocks(
        snapshot: ProjectReportSnapshot,
        brief: DesignBriefSnapshot,
        facts: inout ReportFactRegistry
    ) -> [ReportBlock] {
        var blocks: [ReportBlock] = []

        if let solution = facts.claim(.oneSentenceSolution, value: snapshot.project.briefDescription) {
            blocks.append(
                .callout(
                    ReportCallout(
                        title: ReportCopy.Project.solution,
                        body: solution,
                        factKey: .oneSentenceSolution
                    )
                )
            )
        }

        var values: [ReportKeyValue] = []
        appendValue(ReportCopy.Project.targetUser, brief.targetUser, key: .targetUser, facts: &facts, to: &values)
        appendValue(ReportCopy.Project.scenario, brief.useScenario, key: .useScenario, facts: &facts, to: &values)
        appendValue(ReportCopy.Project.painPoint, brief.painPoint, key: .painPoint, facts: &facts, to: &values)
        appendValue(ReportCopy.Project.coreValue, brief.coreValue, key: .coreValue, facts: &facts, to: &values)
        appendValue(ReportCopy.Project.differentiation, brief.differentiation, key: .differentiation, facts: &facts, to: &values)
        if !values.isEmpty {
            blocks.append(.keyValues(values))
        }

        if blocks.isEmpty {
            blocks.append(.pendingNote(.init(title: ReportCopy.Project.pending, body: nil)))
        }
        return blocks
    }

    private func productScopeBlocks(
        brief: DesignBriefSnapshot,
        facts: inout ReportFactRegistry
    ) -> [ReportBlock] {
        let productBoundaryItems = brief.boundaryItems.filter { !isExplicitAIBoundary($0.content) }
        let included = facts.claimList(
            .includedScope,
            values: productBoundaryItems.filter(\.isIncluded).map(\.content),
            splitter: splitList
        )
        let excluded = facts.claimList(
            .excludedScope,
            values: productBoundaryItems.filter { !$0.isIncluded }.map(\.content),
            splitter: splitList
        )

        var blocks: [ReportBlock] = []
        if !included.isEmpty || !excluded.isEmpty {
            blocks.append(
                .twoColumn(
                    ReportColumn(
                        title: ReportCopy.Scope.included,
                        items: included.isEmpty ? [ReportCopy.pending] : included,
                        factKey: .includedScope
                    ),
                    ReportColumn(
                        title: ReportCopy.Scope.excluded,
                        items: excluded.isEmpty ? [ReportCopy.pending] : excluded,
                        factKey: .excludedScope
                    )
                )
            )
        }

        if let capabilities = listBlock(
            title: ReportCopy.Scope.capabilities,
            value: brief.mvpFeatures,
            key: .mvpFeatures,
            facts: &facts
        ) {
            blocks.append(capabilities)
        }
        if let technical = listBlock(
            title: ReportCopy.Scope.technicalSupport,
            value: brief.technicalModules,
            key: .technicalModules,
            facts: &facts
        ) {
            blocks.append(technical)
        }
        if let constraints = facts.claim(.hardConstraints, value: brief.hardConstraints) {
            blocks.append(
                .callout(
                    ReportCallout(
                        title: ReportCopy.Scope.constraints,
                        body: constraints,
                        factKey: .hardConstraints
                    )
                )
            )
        }

        if blocks.isEmpty {
            blocks.append(.pendingNote(.init(title: ReportCopy.Scope.pending, body: nil)))
        }
        return blocks
    }

    private func coreExperienceFlowBlocks(
        brief: DesignBriefSnapshot,
        facts: inout ReportFactRegistry
    ) -> [ReportBlock] {
        var blocks: [ReportBlock] = []
        if let flowText = facts.claim(.interactionFlow, value: brief.interactionFlow) {
            blocks.append(
                .flow(
                    ReportFlow(
                        factKey: .interactionFlow,
                        steps: flowSteps(from: flowText)
                    )
                )
            )
        }
        if let rules = listBlock(
            title: ReportCopy.Flow.rules,
            value: brief.operationLogic,
            key: .operationLogic,
            facts: &facts
        ) {
            blocks.append(rules)
        }
        if blocks.isEmpty {
            blocks.append(.pendingNote(.init(title: ReportCopy.Flow.pending, body: nil)))
        }
        return blocks
    }

    private func aiBehaviorBlocks(
        semantic: ReportSemanticMapping,
        facts: inout ReportFactRegistry
    ) -> [ReportBlock] {
        let groups = semantic.behaviorGroups.compactMap { group -> ReportFieldGroup? in
            let items = group.fields.compactMap { field -> ReportKeyValue? in
                guard let value = field.semanticValue.value,
                      let cleanValue = facts.claimSemantic(value) else { return nil }
                return ReportKeyValue(
                    label: ReportCopy.behaviorFieldLabel(field.id),
                    value: cleanValue,
                    factKey: nil
                )
            }
            guard !items.isEmpty else { return nil }
            return ReportFieldGroup(title: ReportCopy.behaviorGroupTitle(group.id), items: items)
        }

        guard !groups.isEmpty else {
            return [.pendingNote(.init(title: ReportCopy.Behavior.pending, body: nil))]
        }
        return groups.map(ReportBlock.fieldGroup)
    }

    private func validationRiskBlocks(
        brief: DesignBriefSnapshot,
        semantic: ReportSemanticMapping,
        facts: inout ReportFactRegistry
    ) -> [ReportBlock] {
        var blocks: [ReportBlock] = []

        if facts.claimKey(.successMetrics), !semantic.metrics.isEmpty {
            let rows = semantic.metrics.map {
                ReportMetricRow(
                    metric: semanticText($0.metric),
                    category: semanticText($0.category, missing: ReportCopy.Validation.metricCategoryPending),
                    target: semanticText($0.target),
                    measurement: semanticText($0.measurement),
                    status: semanticText($0.validationStatus, missing: ReportCopy.Validation.validationPending)
                )
            }
            blocks.append(.metrics(.init(factKey: .successMetrics, rows: rows)))
        } else {
            blocks.append(.pendingNote(.init(title: ReportCopy.Validation.metricsPending, body: nil)))
        }

        if facts.claimKey(.risks), !semantic.risks.isEmpty {
            let rows = semantic.risks.map {
                ReportRiskRow(
                    risk: semanticText($0.risk),
                    probability: $0.probability.value,
                    impact: $0.impact.value,
                    triggerOrFailure: semanticOptionalText($0.triggerOrFailure),
                    detection: semanticOptionalText($0.detection),
                    recovery: semanticOptionalText($0.recovery),
                    userControl: semanticOptionalText($0.userControl)
                )
            }
            blocks.append(.risks(.init(factKey: .risks, rows: rows)))
        } else {
            blocks.append(.pendingNote(.init(title: ReportCopy.Validation.risksPending, body: nil)))
        }

        if let milestones = listBlock(
            title: ReportCopy.Validation.nextSteps,
            value: brief.milestones,
            key: .milestones,
            facts: &facts
        ) {
            blocks.append(milestones)
        }
        return blocks
    }

    private func appendValue(
        _ label: String,
        _ value: String?,
        key: ReportFactKey,
        facts: inout ReportFactRegistry,
        to values: inout [ReportKeyValue]
    ) {
        guard let value = facts.claim(key, value: value) else { return }
        values.append(.init(label: label, value: value, factKey: key))
    }

    private func listBlock(
        title: String,
        value: String?,
        key: ReportFactKey,
        facts: inout ReportFactRegistry
    ) -> ReportBlock? {
        let items = facts.claimList(key, values: [value].compactMap { $0 }, splitter: splitList)
        guard !items.isEmpty else { return nil }
        return .bulletList(.init(title: title, items: items, factKey: key))
    }

    private func semanticText(
        _ value: ReportSemanticValue<String>,
        missing: String = ReportCopy.pending
    ) -> String {
        optionalText(value.value) ?? missing
    }

    private func semanticOptionalText(_ value: ReportSemanticValue<String>) -> String? {
        optionalText(value.value)
    }

    private func publicProjectName(_ value: String?) -> String {
        optionalText(value) ?? "未命名项目"
    }

    private func reportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private func optionalText(_ value: String?) -> String? {
        guard let cleaned = ReportContentSanitizer.clean(value) else { return nil }
        let placeholders = [ReportSnapshotValue.missing, "需要补充", ReportCopy.pending, "______"]
        guard !placeholders.contains(where: { cleaned.contains($0) }) else { return nil }
        return cleaned
    }

    private func splitList(_ value: String) -> [String] {
        let separators = CharacterSet(charactersIn: "\n；;、")
        let items = value.components(separatedBy: separators).compactMap(optionalText)
        return unique(items.isEmpty ? [value] : items)
    }

    private func flowSteps(from value: String) -> [ReportFlowStep] {
        let normalized = value
            .replacingOccurrences(of: "->", with: "→")
            .replacingOccurrences(of: "=>", with: "→")
            .replacingOccurrences(of: "➡️", with: "→")
        let rawSteps = normalized
            .components(separatedBy: CharacterSet(charactersIn: "→\n"))
            .compactMap(optionalText)
        return unique(rawSteps.isEmpty ? [value] : rawSteps).map(parseFlowStep)
    }

    private func parseFlowStep(_ text: String) -> ReportFlowStep {
        let actorPrefixes: [(ReportFlowActor, [String])] = [
            (.humanInTheLoop, ["HITL:", "HITL：", "人工确认:", "人工确认：", "人工审批:", "人工审批："]),
            (.user, ["USER:", "USER：", "用户:", "用户："]),
            (.ai, ["AI:", "AI："]),
            (.system, ["SYSTEM:", "SYSTEM：", "系统:", "系统："]),
        ]

        for (actor, prefixes) in actorPrefixes {
            if let prefix = prefixes.first(where: { text.hasPrefix($0) }) {
                let content = String(text.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return ReportFlowStep(
                    actor: actor,
                    text: content.isEmpty ? ReportCopy.pending : content,
                    isConfirmation: actor == .humanInTheLoop
                )
            }
        }
        return ReportFlowStep(actor: .unspecified, text: text, isConfirmation: false)
    }

    private func isExplicitAIBoundary(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.hasPrefix("AI:") || value.hasPrefix("AI：")
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            guard let value = optionalText(value) else { return nil }
            guard seen.insert(normalizedKey(value)).inserted else { return nil }
            return value
        }
    }
}

/// 兼容先前草稿名称；正式调用链使用 ReportContentBuilder。
typealias CompactDesignHandoffReportBuilder = ReportContentBuilder

private struct ReportFactRegistry {
    private var claimedKeys: Set<ReportFactKey> = []
    private var claimedContent: Set<String> = []

    mutating func claimKey(_ key: ReportFactKey) -> Bool {
        claimedKeys.insert(key).inserted
    }

    mutating func claim(_ key: ReportFactKey, value: String?) -> String? {
        guard claimKey(key), let value = ReportContentSanitizer.clean(value) else { return nil }
        let placeholders = [ReportSnapshotValue.missing, "需要补充", ReportCopy.pending, "______"]
        guard !placeholders.contains(where: { value.contains($0) }) else { return nil }
        guard claimedContent.insert(normalizedKey(value)).inserted else { return nil }
        return value
    }

    mutating func claimList(
        _ key: ReportFactKey,
        values: [String],
        splitter: (String) -> [String]
    ) -> [String] {
        guard claimKey(key) else { return [] }
        var result: [String] = []
        for value in values {
            guard let cleaned = ReportContentSanitizer.clean(value) else { continue }
            for item in splitter(cleaned) {
                if let item = claimSemantic(item) {
                    result.append(item)
                }
            }
        }
        return result
    }

    mutating func claimSemantic(_ value: String) -> String? {
        guard let value = ReportContentSanitizer.clean(value) else { return nil }
        guard claimedContent.insert(normalizedKey(value)).inserted else { return nil }
        return value
    }
}

private func normalizedKey(_ value: String) -> String {
    var normalized = value
        .precomposedStringWithCompatibilityMapping
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    for prefix in ["user:", "user：", "用户:", "用户：", "ai:", "ai：", "system:", "system：", "系统:", "系统："]
        where normalized.hasPrefix(prefix) {
        normalized.removeFirst(prefix.count)
        break
    }
    return normalized
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

struct CompactReportPlainTextRenderer {
    func render(document: ReportDocumentModel) -> String {
        var lines = [document.title, document.subtitle, document.projectName]
        document.metadata.forEach { lines.append("\($0.label)：\($0.value)") }
        lines.append("")
        for section in document.sections where !section.blocks.isEmpty {
            lines.append(section.title)
            if let englishTitle = section.englishTitle {
                lines.append(englishTitle)
            }
            lines.append(section.purpose)
            lines.append("")
            section.blocks.forEach { append($0, to: &lines) }
        }
        return lines.joined(separator: "\n")
    }

    private func append(_ block: ReportBlock, to lines: inout [String]) {
        switch block {
        case .keyValues(let items):
            items.forEach { lines.append("\($0.label)：\($0.value)") }
        case .fieldGroup(let group):
            lines.append(group.title)
            group.items.forEach { lines.append("\($0.label)：\($0.value)") }
        case .twoColumn(let left, let right):
            appendColumn(left, to: &lines)
            appendColumn(right, to: &lines)
        case .bulletList(let list):
            lines.append(list.title)
            list.items.forEach { lines.append("- \($0)") }
        case .flow(let flow):
            for (index, step) in flow.steps.enumerated() {
                lines.append("\(index + 1). [\(step.actor.displayLabel)] \(step.text)")
            }
        case .callout(let callout):
            lines.append(callout.title)
            lines.append(callout.body)
        case .metrics(let table):
            lines.append(ReportCopy.Validation.metricHeaders.joined(separator: " | "))
            table.rows.forEach {
                lines.append("\($0.metric) | \($0.category) | \($0.target) | \($0.measurement) | \($0.status)")
            }
        case .risks(let table):
            lines.append(ReportCopy.Risk.title)
            for row in table.rows {
                let priority = [
                    row.probability.map { "\(ReportCopy.Risk.probability) \($0)/5" },
                    row.impact.map { "\(ReportCopy.Risk.impact) \($0)/5" },
                ].compactMap { $0 }.joined(separator: " · ")
                lines.append(priority.isEmpty ? row.risk : "\(row.risk)（\(priority)）")
                row.availableDetails.forEach { lines.append("\($0.0)：\($0.1)") }
            }
        case .pendingNote(let note):
            lines.append(note.title)
            if let body = note.body { lines.append(body) }
        }
        lines.append("")
    }

    private func appendColumn(_ column: ReportColumn, to lines: inout [String]) {
        lines.append(column.title)
        column.items.forEach { lines.append("- \($0)") }
    }
}
