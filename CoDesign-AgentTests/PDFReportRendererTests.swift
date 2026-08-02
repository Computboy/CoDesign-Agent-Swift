import Foundation
import CoreGraphics
import Testing
@testable import CoDesign_Agent

struct PDFReportRendererTests {
    @Test @MainActor func rendererAcceptsMockSnapshot() throws {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        #if canImport(UIKit)
        let output = PDFReportRenderer().renderWithDiagnostics(snapshot: snapshot)
        let data = output.data
        #else
        let data = try PDFReportRenderer().render(snapshot: snapshot)
        #endif
        let provider = CGDataProvider(data: data as CFData)
        let document = provider.flatMap(CGPDFDocument.init)

        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "%PDF")
        #if canImport(UIKit)
        expectHealthyPagination(output, document: document)
        #else
        #expect((document?.numberOfPages ?? 0) >= 1)
        #endif
    }

    @Test func readablePDFErrorExists() {
        let error = ReportExportError.unsupportedPDFPlatform
        #expect(error.localizedDescription.contains("PDF"))
    }

    @Test @MainActor func denseValidationRowsRenderWithoutDroppingThresholds() throws {
        var snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        snapshot.brief.successMetrics = [
            SuccessMetricDTO(id: nil, metric: "完成时间", target: "≤10 min", measurement: "端到端计时"),
            SuccessMetricDTO(id: nil, metric: "文化事实错误率", target: "≤5%", measurement: "人工事实抽查"),
            SuccessMetricDTO(id: nil, metric: "脚本可用率", target: "≥80%", measurement: "用户任务评估"),
        ]
        snapshot.brief.risks = [
            RiskItemDTO(id: nil, desc: "文化事实错误", probability: 4, impact: 5, mitigation: "needsReview + 显示依据"),
            RiskItemDTO(id: nil, desc: "脚本结构不可用", probability: 3, impact: 4, mitigation: "返回结构化编辑并保留原稿"),
            RiskItemDTO(id: nil, desc: "用户误把草稿当成最终内容", probability: 2, impact: 3, mitigation: "保持草稿标记并要求发布前确认"),
        ]

        #if canImport(UIKit)
        let output = PDFReportRenderer().renderWithDiagnostics(snapshot: snapshot)
        let data = output.data
        #else
        let data = try PDFReportRenderer().render(snapshot: snapshot)
        #endif
        let provider = CGDataProvider(data: data as CFData)
        let document = provider.flatMap(CGPDFDocument.init)

        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "%PDF")
        #if canImport(UIKit)
        expectHealthyPagination(output, document: document)
        #else
        #expect((document?.numberOfPages ?? 0) >= 1)
        #endif
    }

    #if canImport(UIKit)
    @Test @MainActor func paginationHandlesEightExtremeDataShapes() {
        let renderer = PDFReportRenderer()

        var short = ExportTestFixtures.makeSnapshot(format: .pdf)
        short.project.name = "短"
        short.project.briefDescription = "短"
        short.brief = compactBrief(seed: "短")
        let shortOutput = renderer.renderWithDiagnostics(snapshot: short)
        expectHealthyPagination(shortOutput)

        var longChinese = ExportTestFixtures.makeSnapshot(format: .pdf)
        let chinese = String(repeating: "这是用于验证中文长段落分页与内容完整性的真实项目描述，必须保留每一个字符。", count: 90)
        longChinese.project.briefDescription = chinese
        longChinese.brief = compactBrief(seed: chinese)
        let longOutput = renderer.renderWithDiagnostics(snapshot: longChinese)
        expectHealthyPagination(longOutput)
        #expect(longOutput.diagnostics.splitTextBlockCount > 0)

        var mixed = ExportTestFixtures.makeSnapshot(format: .pdf)
        let mixedText = String(repeating: "用户输入 User Input → AI draft → 人工确认 HITL；threshold ≤5%，status pending。", count: 45)
        mixed.project.briefDescription = mixedText
        mixed.brief = compactBrief(seed: mixedText)
        let mixedOutput = renderer.renderWithDiagnostics(snapshot: mixed)
        expectHealthyPagination(mixedOutput)
        #expect((mixedOutput.diagnostics.pageContentHeights.last ?? 0) >= 240)

        let baseSnapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        var emptySectionDocument = CompactDesignHandoffReportBuilder().build(snapshot: baseSnapshot)
        emptySectionDocument.sections[2].blocks = []
        var removedSectionDocument = emptySectionDocument
        removedSectionDocument.sections.remove(at: 2)
        let emptyOutput = renderer.renderWithDiagnostics(snapshot: baseSnapshot, document: emptySectionDocument)
        let removedOutput = renderer.renderWithDiagnostics(snapshot: baseSnapshot, document: removedSectionDocument)
        expectHealthyPagination(emptyOutput)
        #expect(emptyOutput.diagnostics.pageCount == removedOutput.diagnostics.pageCount)

        var eightMetrics = ExportTestFixtures.makeSnapshot(format: .pdf)
        eightMetrics.brief.successMetrics = (1...8).map { index in
            SuccessMetricDTO(
                id: nil,
                metric: "指标 \(index)",
                target: index.isMultiple(of: 2) ? "≤\(index * 5)%" : "≥\(index * 10)%",
                measurement: String(repeating: "测量步骤 \(index)：记录任务、抽样复核并汇总结果。", count: 10)
            )
        }
        let metricsOutput = renderer.renderWithDiagnostics(snapshot: eightMetrics)
        expectHealthyPagination(metricsOutput)
        #expect(metricsOutput.diagnostics.repeatedTableHeaderCount > 0)

        var tenRisks = ExportTestFixtures.makeSnapshot(format: .pdf)
        tenRisks.brief.risks = (1...10).map { index in
            RiskItemDTO(
                id: nil,
                desc: "风险 \(index)：关键任务在异常输入下失败",
                probability: (index % 5) + 1,
                impact: ((index + 2) % 5) + 1,
                mitigation: String(repeating: "恢复步骤 \(index)：保留原稿、显示原因并允许用户重试。", count: 5)
            )
        }
        let risksOutput = renderer.renderWithDiagnostics(snapshot: tenRisks)
        expectHealthyPagination(risksOutput)

        var minimal = ExportTestFixtures.makeSnapshot(format: .pdf)
        minimal.project.name = "最小项目"
        minimal.project.briefDescription = ""
        minimal.brief = DesignBriefSnapshot()
        let minimalOutput = renderer.renderWithDiagnostics(snapshot: minimal)
        expectHealthyPagination(minimalOutput)
        #expect((minimalOutput.diagnostics.pageContentHeights.last ?? 0) >= 160)

        var sawBoundarySplit = false
        for repeatCount in [280, 360, 440, 520, 600] {
            let boundaryText = String(repeating: "边界文本用于覆盖刚好落在分页线附近的内容。", count: repeatCount)
            let document = ReportDocument(
                title: "Boundary Pagination Test",
                projectName: "边界测试",
                sections: [
                    ReportSection(
                        id: .projectDefinition,
                        title: "Boundary Section",
                        purpose: "测试接近页边界的长段落。",
                        blocks: [
                            .keyValues([
                                ReportKeyValue(label: "Boundary Paragraph", value: boundaryText, factKey: nil)
                            ])
                        ]
                    )
                ]
            )
            let output = renderer.renderWithDiagnostics(snapshot: baseSnapshot, document: document)
            expectHealthyPagination(output)
            sawBoundarySplit = sawBoundarySplit || output.diagnostics.splitTextBlockCount > 0
        }
        #expect(sawBoundarySplit)
    }
    #endif

    @Test @MainActor func pdfRendererDoesNotAffectMarkdownOrJSON() throws {
        let snapshot = ExportTestFixtures.makeSnapshot(format: .pdf)
        _ = try PDFReportRenderer().render(snapshot: snapshot)

        let markdown = MarkdownReportRenderer().render(snapshot: snapshot)
        let json = try JSONReportRenderer().render(snapshot: snapshot)

        #expect(markdown.contains("AI 产品设计报告"))
        #expect(!json.isEmpty)
    }

    @Test @MainActor func acceptanceFixturesRenderWithNaturalPageCounts() throws {
        let fixtures = acceptanceFixtures()
        var pageCounts: [Int] = []

        for fixture in fixtures {
            let document = ReportContentBuilder().build(snapshot: fixture.snapshot)
            #expect(ReportContentValidator.violations(in: document).isEmpty)

            let output = PDFReportRenderer().renderWithDiagnostics(snapshot: fixture.snapshot)
            expectHealthyPagination(output)
            pageCounts.append(output.diagnostics.pageCount)

            let environment = ProcessInfo.processInfo.environment
            let requestedDirectory: URL? = environment["CODESIGN_PDF_FIXTURE_OUTPUT_DIR"].map {
                URL(fileURLWithPath: $0, isDirectory: true)
            } ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("PDF-Export-Fixtures", isDirectory: true)
            if let directory = requestedDirectory {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try output.data.write(to: directory.appendingPathComponent(fixture.filename), options: .atomic)
            }
        }

        #expect(pageCounts.count == 3)
        #expect(pageCounts[0] <= pageCounts[1])
        #expect(pageCounts[1] < pageCounts[2])
    }

    #if canImport(UIKit)
    @MainActor
    private func compactBrief(seed: String) -> DesignBriefSnapshot {
        DesignBriefSnapshot(
            targetUser: seed,
            painPoint: seed,
            useScenario: seed,
            coreValue: seed,
            differentiation: seed,
            boundaryItems: [
                BoundaryItemDTO(id: nil, content: seed, isIncluded: true),
                BoundaryItemDTO(id: nil, content: seed, isIncluded: false),
            ],
            mvpFeatures: seed,
            technicalModules: seed,
            interactionFlow: seed,
            operationLogic: seed,
            hardConstraints: seed,
            successMetrics: [
                SuccessMetricDTO(id: nil, metric: seed, target: "≤10 min", measurement: seed)
            ],
            risks: [
                RiskItemDTO(id: nil, desc: seed, probability: 3, impact: 4, mitigation: seed)
            ],
            milestones: seed
        )
    }

    private func expectHealthyPagination(
        _ output: PDFRenderOutput,
        document: CGPDFDocument? = nil
    ) {
        let pageBodyHeight: CGFloat = 736
        #expect(output.diagnostics.pageCount >= 1)
        #expect(output.diagnostics.pageContentHeights.count == output.diagnostics.pageCount)
        #expect(output.diagnostics.pageContentHeights.allSatisfy { $0 > 0 && $0 <= pageBodyHeight + 0.5 })
        #expect(output.diagnostics.overflowCount == 0)
        #expect(output.diagnostics.orphanHeadingCount == 0)
        #expect(output.diagnostics.forcedSectionPageBreakCount == 0)
        if let document {
            #expect(document.numberOfPages == output.diagnostics.pageCount)
        }

        for usage in output.diagnostics.pageContentHeights.dropLast() {
            #expect(usage >= 96)
        }
        if output.diagnostics.pageContentHeights.count >= 2,
           let previous = output.diagnostics.pageContentHeights.dropLast().last,
           let last = output.diagnostics.pageContentHeights.last,
           last < 96 {
            #expect(pageBodyHeight - previous < last + 24)
        }
    }
    #endif

    @MainActor
    private func acceptanceFixtures() -> [(filename: String, snapshot: ProjectReportSnapshot)] {
        var sparse = ExportTestFixtures.makeSnapshot(format: .pdf)
        sparse.project.name = "社区长者问诊提醒"
        sparse.project.briefDescription = "帮助独居长者按时记录并确认问诊安排"
        sparse.brief = DesignBriefSnapshot(
            targetUser: "需要家属协助安排问诊的独居长者",
            painPoint: nil,
            useScenario: "收到医院通知后记录问诊时间",
            coreValue: nil,
            differentiation: nil,
            boundaryItems: [],
            mvpFeatures: nil,
            technicalModules: nil,
            interactionFlow: nil,
            operationLogic: nil,
            hardConstraints: "不得代替医生给出诊断",
            successMetrics: [
                .init(id: nil, metric: "提醒确认率", target: "≥70%", measurement: "记录提醒后的确认操作")
            ],
            risks: [
                .init(id: nil, desc: "提醒时间记录错误", probability: 2, impact: 4, mitigation: "允许家属核对并修改")
            ],
            milestones: nil
        )

        var typical = ExportTestFixtures.makeSnapshot(format: .pdf)
        typical.project.name = "可信文化短视频创作助手"
        typical.project.briefDescription = "帮助地方文化创作者把可靠资料整理成可编辑的短视频脚本"
        typical.brief = DesignBriefSnapshot(
            targetUser: "需要稳定产出文化内容、但缺少资料核验时间的地方文化创作者",
            painPoint: "资料分散、脚本结构不稳定，且文化事实错误会显著影响公信力",
            useScenario: "创作者确定选题后，在一次工作会话中完成资料检索、脚本生成、核验与修改",
            coreValue: "缩短从资料到可信脚本的时间，同时保留创作者的最终判断",
            differentiation: "把资料依据、待核验状态和脚本编辑放在同一条工作流中",
            boundaryItems: [
                .init(id: nil, content: "支持资料导入与事实标注", isIncluded: true),
                .init(id: nil, content: "支持结构化脚本编辑", isIncluded: true),
                .init(id: nil, content: "不自动发布内容", isIncluded: false),
                .init(id: nil, content: "不替代文化专家审核", isIncluded: false),
                .init(id: nil, content: "AI：生成带依据的候选脚本", isIncluded: true),
                .init(id: nil, content: "AI：替用户确认文化事实", isIncluded: false),
            ],
            mvpFeatures: "选题输入；资料导入；依据检索；脚本大纲；段落生成；引用查看；事实标注；结构化编辑",
            technicalModules: "内容解析；混合检索；RAG 生成；引用追踪；草稿版本管理",
            interactionFlow: "用户：输入选题 → 系统：整理资料 → AI：生成脚本大纲 → 用户：修改段落 → 人工确认：核验事实后导出",
            operationLogic: "所有生成内容保持草稿状态；资料不足时标记不确定性；用户可以修改、拒绝或重新生成",
            hardConstraints: "不得隐藏引用缺失；未经人工确认不得标记为最终稿",
            successMetrics: (1...4).map { index in
                .init(
                    id: nil,
                    metric: ["首次脚本可用率", "文化事实错误率", "依据查看率", "完成时间"][index - 1],
                    target: ["≥80%", "≤5%", "≥60%", "≤20 min"][index - 1],
                    measurement: ["用户任务评估", "专家事实抽查", "交互事件统计", "端到端计时"][index - 1]
                )
            },
            risks: (1...4).map { index in
                .init(
                    id: nil,
                    desc: ["文化事实错误", "引用与结论不一致", "脚本结构不可用", "用户误把草稿当最终稿"][index - 1],
                    probability: [3, 2, 3, 2][index - 1],
                    impact: [5, 5, 4, 4][index - 1],
                    mitigation: ["显示依据并要求人工核验", "标记冲突并保留原文", "返回结构化编辑并保留原稿", "持续显示草稿状态并在导出前确认"][index - 1]
                )
            },
            milestones: "第 1 周完成资料导入与检索；第 2 周完成脚本编辑原型；第 3 周开展创作者任务验证"
        )

        var dense = typical
        dense.project.name = "面向多地区非物质文化遗产机构与内容团队的可信多语言短视频协同创作与审核工作平台"
        dense.project.briefDescription = "连接资料整理、RAG 检索、脚本生成、人工复核和多语言交付的协同工作平台"
        dense.brief.targetUser = "地方文化机构的内容策划、资料研究员、短视频编导、外部文化顾问与负责最终发布审批的项目负责人"
        dense.brief.painPoint = String(
            repeating: "团队需要在来源分散、表述差异明显的中文与 English materials 中核对人物、时间、技艺与地域信息；任何遗漏都会让后续脚本修改、HITL 审核和发布排期反复返工。",
            count: 8
        )
        dense.brief.useScenario = "多个地区团队同时导入 PDF、网页摘录与访谈记录，系统整理证据，AI 生成候选结构，研究员查看引用，编导修改叙事，文化顾问复核事实，负责人确认多语言版本后交付。"
        dense.brief.coreValue = "在不削弱人工判断的前提下，把跨资料、跨角色、跨语言的长链路创作压缩为可追踪、可修改、可恢复的协同流程。"
        dense.brief.differentiation = "每个脚本结论都可回到资料依据；不确定内容保持明确状态；用户可拒绝、重生成或恢复任一草稿。"
        dense.brief.boundaryItems = (1...18).map {
            .init(id: nil, content: "纳入能力 \($0)：处理资料、脚本与审核状态", isIncluded: true)
        } + (1...6).map {
            .init(id: nil, content: "范围外事项 \($0)：不替代机构的专业判断", isIncluded: false)
        } + [
            .init(id: nil, content: "AI：生成带逐段依据的候选脚本", isIncluded: true),
            .init(id: nil, content: "AI：自动确认争议文化事实", isIncluded: false),
        ]
        dense.brief.mvpFeatures = (1...18).map { "产品能力 \($0)：支持批量资料、协同编辑与审核交接" }.joined(separator: "；")
        dense.brief.technicalModules = (1...12).map { "技术模块 \($0)：解析、索引、检索、生成与审计支持" }.joined(separator: "；")
        dense.brief.interactionFlow = [
            "用户：创建选题", "用户：导入多源资料", "系统：解析并建立索引", "AI：识别资料冲突",
            "用户：选择叙事结构", "AI：生成候选大纲", "用户：修改脚本段落", "系统：保存草稿",
            "用户：查看逐段依据", "AI：标记不确定内容", "人工确认：文化顾问完成事实复核", "人工确认：负责人确认交付版本",
        ].joined(separator: " → ")
        dense.brief.operationLogic = (1...10).map { "运行规则 \($0)：保留状态、依据、人工操作与可恢复草稿" }.joined(separator: "；")
        dense.brief.hardConstraints = "不得把不确定内容呈现为已核验事实；不得自动发布；所有外部交付必须保留责任人确认记录；中文、English、数字、LLM、RAG、HITL 与 PRD 混排时保持原始顺序。"
        dense.brief.successMetrics = (1...9).map { index in
            .init(
                id: nil,
                metric: "验证指标 \(index)",
                target: index.isMultiple(of: 2) ? "≤\(index + 2)%" : "≥\(70 + index)%",
                measurement: "第一阶段记录任务完成率与异常状态。\n第二阶段由研究员抽样复核资料、引用和脚本结论，并按周汇总。"
            )
        }
        dense.brief.risks = (1...11).map { index in
            .init(
                id: nil,
                desc: "风险 \(index)：跨地区资料冲突导致脚本结论或交付状态不一致",
                probability: (index % 5) + 1,
                impact: ((index + 2) % 5) + 1,
                mitigation: "保留原始资料与当前草稿，显示冲突位置，允许负责人退回编辑、拒绝结果或重新生成。"
            )
        }
        dense.brief.milestones = (1...8).map { "里程碑 \($0)：完成一个可独立验收的资料、脚本或审核能力" }.joined(separator: "；")

        return [
            ("CoDesign-PDF-Sparse.pdf", sparse),
            ("CoDesign-PDF-Typical.pdf", typical),
            ("CoDesign-PDF-Dense.pdf", dense),
        ]
    }
}
