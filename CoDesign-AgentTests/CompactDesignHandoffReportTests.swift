import Foundation
import Testing
@testable import CoDesign_Agent

struct CompactDesignHandoffReportTests {
    @Test func fieldPolicyClassifiesEveryExportableSourceField() {
        let classified = Set(CompactReportFieldPolicy.all.map(\.field))
        #expect(classified == Set(ReportSourceField.allCases))

        #expect(CompactReportFieldPolicy.policy(for: .targetUser).tier == .required)
        #expect(CompactReportFieldPolicy.policy(for: .differentiation).tier == .conditional)
        #expect(CompactReportFieldPolicy.policy(for: .decisionTrace).tier == .archiveOnly)
        #expect(CompactReportFieldPolicy.policy(for: .resources).tier == .archiveOnly)
    }

    @Test @MainActor func builderCreatesOnlyFiveHandoffSections() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)

        #expect(document.title == "AI 产品设计交接简报")
        #expect(document.subtitle == "AI Product Design Handoff Brief")
        #expect(document.sections.map(\.id) == ReportSectionID.allCases)
        #expect(document.sections.map(\.title) == [
            "01 项目定义",
            "02 产品范围",
            "03 核心体验流程",
            "04 AI 行为与用户控制",
            "05 验证、风险与下一步",
        ])
        #expect(document.sections.compactMap(\.englishTitle) == [
            "Project Definition",
            "Product Scope",
            "Core Experience Flow",
            "AI Behavior & User Control",
            "Validation, Risks & Next Steps",
        ])
    }

    @Test @MainActor func coreFactsHaveOneOwningSection() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)

        for fact in [
            ReportFactKey.targetUser,
            .painPoint,
            .useScenario,
            .coreValue,
            .hardConstraints,
        ] {
            #expect(document.occurrenceCount(of: fact) == 1)
        }

        #expect(document.sections.first { $0.id == .projectDefinition }?.blocks.contains {
            $0.factKeys.contains(.targetUser)
        } == true)
        #expect(document.sections.first { $0.id == .productScope }?.blocks.contains {
            $0.factKeys.contains(.hardConstraints)
        } == true)
    }

    @Test @MainActor func defaultPDFExcludesProcessArchiveContent() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)
        let text = CompactReportPlainTextRenderer().render(document: document)

        #expect(!snapshot.exportOptions.includeDecisionTrace)
        #expect(!snapshot.exportOptions.includeResources)
        #expect(!snapshot.exportOptions.includeFullMindTree)
        #expect(!snapshot.exportOptions.includeReportSections)
        #expect(snapshot.reportSections.projectSummary.isEmpty)
        #expect(snapshot.reportSections.behaviorSpec.isEmpty)
        #expect(!text.contains("成果看板"))
        #expect(!text.contains("作品档案"))
        #expect(!text.contains("设计决策路径"))
        #expect(!text.contains("Thinking Action Cards"))
        #expect(!text.contains("资源线索"))
        #expect(!text.contains("Stage 1"))
    }

    @Test @MainActor func reportRemovesInternalTestCopy() {
        var snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        snapshot.project.name = "已完成测试任务：非遗 AI 短视频"

        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)
        let text = CompactReportPlainTextRenderer().render(document: document)

        #expect(document.projectName == "非遗 AI 短视频")
        #expect(!text.contains("已完成测试任务"))
        #expect(!text.contains("PDF 导出阶段"))
        #expect(!text.contains("LLM 补全项目事实"))
    }

    @Test @MainActor func rewardFunctionKeepsThresholdMeasurementAndStatus() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)
        let validation = document.sections.first { $0.id == .validationRisks }
        let metrics = validation?.blocks.compactMap { block -> ReportMetricsTable? in
            guard case .metrics(let table) = block else { return nil }
            return table
        }.first

        #expect(metrics?.rows.first?.metric == "首次到达成功率")
        #expect(metrics?.rows.first?.category == "待分类")
        #expect(metrics?.rows.first?.target == "80%")
        #expect(metrics?.rows.first?.measurement == "任务完成率")
        #expect(metrics?.rows.first?.status == "待验证")
    }

    @Test @MainActor func rewardFunctionPreservesEveryThresholdVerbatim() {
        var snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        snapshot.brief.successMetrics = [
            SuccessMetricDTO(id: nil, metric: "完成时间", target: "≤10 min", measurement: "端到端计时"),
            SuccessMetricDTO(id: nil, metric: "文化事实错误率", target: "≤5%", measurement: "人工事实抽查"),
            SuccessMetricDTO(id: nil, metric: "脚本可用率", target: "≥80%", measurement: "用户任务评估"),
        ]

        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)
        let validation = document.sections.first { $0.id == .validationRisks }
        let metrics = validation?.blocks.compactMap { block -> ReportMetricsTable? in
            guard case .metrics(let table) = block else { return nil }
            return table
        }.first
        let text = CompactReportPlainTextRenderer().render(document: document)

        #expect(metrics?.rows.map(\.target) == ["≤10 min", "≤5%", "≥80%"])
        #expect(metrics?.rows.allSatisfy { $0.category == "待分类" } == true)
        #expect(metrics?.rows.allSatisfy { $0.status == "待验证" } == true)
        #expect(text.contains("指标 | 类型 | 目标值 | 测量方式 | 当前状态"))
        #expect(text.contains("完成时间 | 待分类 | ≤10 min | 端到端计时 | 待验证"))
        #expect(text.contains("文化事实错误率 | 待分类 | ≤5% | 人工事实抽查 | 待验证"))
        #expect(text.contains("脚本可用率 | 待分类 | ≥80% | 用户任务评估 | 待验证"))
    }

    @Test @MainActor func risksKeepProbabilityImpactAndMitigation() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)
        let validation = document.sections.first { $0.id == .validationRisks }
        let risks = validation?.blocks.compactMap { block -> ReportRisksTable? in
            guard case .risks(let table) = block else { return nil }
            return table
        }.first

        #expect(risks?.rows.first?.risk == "定位漂移导致路线错误")
        #expect(risks?.rows.first?.probability == 3)
        #expect(risks?.rows.first?.impact == 4)
        #expect(risks?.rows.first?.triggerOrFailure == nil)
        #expect(risks?.rows.first?.detection == nil)
        #expect(risks?.rows.first?.recovery == "提示用户核对地标")
        #expect(risks?.rows.first?.userControl == nil)
        #expect(risks?.rows.first?.recovery != snapshot.brief.hardConstraints)
    }

    @Test @MainActor func eachRecoveryStaysAttachedToItsOwnRisk() {
        var snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        snapshot.brief.risks = [
            RiskItemDTO(
                id: nil,
                desc: "文化事实错误",
                probability: 4,
                impact: 5,
                mitigation: "needsReview + 显示依据"
            ),
            RiskItemDTO(
                id: nil,
                desc: "脚本结构不可用",
                probability: 3,
                impact: 4,
                mitigation: "返回结构化编辑并保留原稿"
            ),
        ]

        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)
        let validation = document.sections.first { $0.id == .validationRisks }
        let risks = validation?.blocks.compactMap { block -> ReportRisksTable? in
            guard case .risks(let table) = block else { return nil }
            return table
        }.first

        #expect(risks?.rows.map(\.risk) == ["文化事实错误", "脚本结构不可用"])
        #expect(risks?.rows.map(\.recovery) == ["needsReview + 显示依据", "返回结构化编辑并保留原稿"])
        #expect(risks?.rows.allSatisfy { $0.triggerOrFailure == nil } == true)
        #expect(risks?.rows.allSatisfy { $0.detection == nil } == true)
        #expect(risks?.rows.allSatisfy { $0.userControl == nil } == true)
    }

    @Test @MainActor func aiBehaviorDoesNotBorrowUnrelatedBriefFields() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)
        let section = document.sections.first { $0.id == .aiBehaviorBoundary }
        #expect(section?.blocks.count == 1)
        #expect(section?.blocks.contains {
            guard case .pendingNote(let note) = $0 else { return false }
            return note.title == "AI 行为与用户控制待进一步明确"
        } == true)

        #expect(section?.blocks.contains { if case .fieldGroup = $0 { true } else { false } } == false)
    }

    @Test @MainActor func semanticMapperRejectsAdjacentFallbackFields() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .markdown)
        let semantic = ReportSemanticMapper().map(brief: snapshot.brief)

        for field in ReportBehaviorFieldID.allCases {
            #expect(semantic.field(field)?.semanticValue.value == nil)
        }

        #expect(snapshot.reportSections.behaviorSpec["UNDERSTAND"]?.isEmpty == true)
        #expect(snapshot.reportSections.behaviorSpec["CAPABILITY"]?.isEmpty == true)
        #expect(snapshot.reportSections.behaviorSpec["BOUNDARY"]?.isEmpty == true)
        #expect(snapshot.reportSections.aiValueHypothesis.isEmpty)
        #expect(snapshot.reportSections.rewardFunction.isEmpty)
        #expect(snapshot.reportSections.failureRecovery.isEmpty)
        #expect(snapshot.reportSections.interventionSpec.isEmpty)
    }

    @Test @MainActor func semanticMapperAllowsOnlyExplicitDeterministicDerivations() {
        var snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        snapshot.brief.boundaryItems = [
            BoundaryItemDTO(id: nil, content: "AI：生成候选路线", isIncluded: true),
            BoundaryItemDTO(id: nil, content: "AI：替用户确认最终路线", isIncluded: false),
            BoundaryItemDTO(id: nil, content: "仅支持校内场景", isIncluded: true),
        ]
        snapshot.brief.interactionFlow = "用户：输入目的地 → AI：生成路线 → 人工确认：核验后发布"

        let semantic = ReportSemanticMapper().map(brief: snapshot.brief)

        #expect(semantic.field(.willDo)?.semanticValue.value == "生成候选路线")
        #expect(semantic.field(.willNotDo)?.semanticValue.value == "替用户确认最终路线")
        #expect(semantic.field(.approval)?.semanticValue.value == "核验后发布")
        #expect(
            semantic.field(.willDo)?.semanticValue.provenance == .derived(
                sources: ["brief.boundaryItems.content", "brief.boundaryItems.isIncluded"],
                rule: "仅接收以 AI: 或 AI：显式标记的边界项"
            )
        )
        #expect(semantic.field(.feedbackLoop)?.semanticValue.value == nil)
        #expect(semantic.field(.responsibility)?.semanticValue.value == nil)
        #expect(semantic.field(.fallback)?.semanticValue.value == nil)
    }

    @Test @MainActor func flowActorsRequireExplicitPrefixes() {
        var snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        snapshot.brief.interactionFlow = "用户：输入主题 → AI：生成草稿 → 人工确认：核验事实"
        let document = CompactDesignHandoffReportBuilder().build(snapshot: snapshot)
        let section = document.sections.first { $0.id == .coreExperienceFlow }
        let flow = section?.blocks.compactMap { block -> ReportFlow? in
            guard case .flow(let flow) = block else { return nil }
            return flow
        }.first

        #expect(flow?.steps.map(\.actor) == [.user, .ai, .humanInTheLoop])
        #expect(flow?.steps.last?.isConfirmation == true)
    }

    @Test @MainActor func emptyMetricsAndRisksUseNotesInsteadOfFabricatedRows() {
        var snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        snapshot.brief.successMetrics = []
        snapshot.brief.risks = []

        let document = ReportContentBuilder().build(snapshot: snapshot)
        let validation = document.sections.first { $0.id == .validationRisks }

        #expect(validation?.blocks.contains { if case .metrics = $0 { true } else { false } } == false)
        #expect(validation?.blocks.contains { if case .risks = $0 { true } else { false } } == false)
        #expect(validation?.blocks.filter { if case .pendingNote = $0 { true } else { false } }.count == 2)
    }

    @Test @MainActor func duplicateFactsAreRemovedBeforeRendering() {
        var snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        snapshot.brief.coreValue = "让创作者更快完成可信脚本"
        snapshot.brief.differentiation = "让创作者更快完成可信脚本"
        snapshot.brief.hardConstraints = "让创作者更快完成可信脚本"

        let document = ReportContentBuilder().build(snapshot: snapshot)
        let text = CompactReportPlainTextRenderer().render(document: document)

        #expect(text.components(separatedBy: "让创作者更快完成可信脚本").count - 1 == 1)
        #expect(document.occurrenceCount(of: .coreValue) == 1)
        #expect(document.occurrenceCount(of: .differentiation) == 0)
        #expect(document.occurrenceCount(of: .hardConstraints) == 0)
    }

    @Test @MainActor func milestonesAppearOnlyAsConfirmedNextSteps() {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        let document = ReportContentBuilder().build(snapshot: snapshot)

        #expect(document.sections.first { $0.id == .productScope }?.blocks.contains {
            $0.factKeys.contains(.milestones)
        } == false)
        #expect(document.sections.first { $0.id == .validationRisks }?.blocks.contains {
            $0.factKeys.contains(.milestones)
        } == true)
        #expect(document.occurrenceCount(of: .milestones) == 1)
    }

    @Test @MainActor func sensitiveCopyIsCleanedAndFinalDocumentPassesStaticScan() {
        var snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        snapshot.project.name = "已完成测试任务：路线助手 v1.1.0"
        snapshot.project.briefDescription = "本次重构使用 SwiftData renderer 输出当前方案"
        snapshot.brief.coreValue = "用于测试完整 Design Brief：帮助用户完成路线确认"

        let document = ReportContentBuilder().build(snapshot: snapshot)
        let text = CompactReportPlainTextRenderer().render(document: document)

        #expect(ReportContentValidator.violations(in: document).isEmpty)
        for phrase in ReportContentValidator.prohibitedPhrases {
            #expect(text.range(of: phrase, options: .caseInsensitive) == nil)
        }
        #expect(text.contains("路线助手"))
        #expect(text.contains("帮助用户完成路线确认"))
    }

    @Test @MainActor func adaptiveLayoutPolicyUsesDataDensity() {
        let policy = ReportLayoutPolicy()
        let shortFlow = ReportFlow(
            factKey: .interactionFlow,
            steps: [
                .init(actor: .user, text: "输入主题", isConfirmation: false),
                .init(actor: .ai, text: "生成草稿", isConfirmation: false),
                .init(actor: .humanInTheLoop, text: "确认发布", isConfirmation: true),
            ]
        )
        let longFlow = ReportFlow(
            factKey: .interactionFlow,
            steps: (1...12).map { .init(actor: .system, text: "处理步骤 \($0)", isConfirmation: false) }
        )
        let compactRisk = ReportRiskRow(
            risk: "事实错误",
            probability: 3,
            impact: 5,
            triggerOrFailure: nil,
            detection: nil,
            recovery: "保留原稿并允许重试",
            userControl: nil
        )
        let detailedRisk = ReportRiskRow(
            risk: "事实错误",
            probability: 3,
            impact: 5,
            triggerOrFailure: "引用冲突",
            detection: "事实抽查",
            recovery: "保留原稿并允许重试",
            userControl: "允许拒绝结果"
        )

        #expect(policy.flowLayout(for: shortFlow) == .horizontal)
        #expect(policy.flowLayout(for: longFlow) == .timeline)
        #expect(policy.riskLayout(for: compactRisk) == .compact)
        #expect(policy.riskLayout(for: detailedRisk) == .detailed)
    }
}
