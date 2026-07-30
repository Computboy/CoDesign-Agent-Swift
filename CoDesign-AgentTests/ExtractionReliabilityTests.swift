import Foundation
import SwiftData
import Testing
@testable import CoDesign_Agent

struct ExtractionReliabilityTests {
    private let messages = [
        ChatPayloadMessage.user("我的目标用户是外地大一新生，他们开学第一周经常找不到教学楼。"),
        ChatPayloadMessage.assistant("你可以继续说明场景。"),
    ]

    @Test func validEnvelopePassesValidation() throws {
        let envelope = ExtractionEnvelope(
            targetUser: ExtractedFieldCandidate(
                value: "外地大一新生",
                confidence: 0.9,
                evidence: [EvidenceSpan(role: "user", quote: "外地大一新生，他们开学第一周经常找不到教学楼", turnIndex: 0)]
            )
        )

        let report = ExtractionSchemaValidator().validate(envelope: envelope, messages: messages)

        #expect(report.hasErrors == false)
        #expect(report.fieldResults["targetUser"]?.userEvidenceFound == true)
    }

    @Test func invalidRiskProbabilityIsRejected() throws {
        let envelope = ExtractionEnvelope(
            risks: ExtractedFieldCandidate(
                value: [
                    RiskItemDTO(desc: "定位不稳定", probability: 6, impact: 4, mitigation: "提供手动选择教学楼")
                ],
                confidence: 0.95,
                evidence: [EvidenceSpan(role: "user", quote: "经常找不到教学楼", turnIndex: 0)]
            )
        )

        let report = ExtractionSchemaValidator().validate(envelope: envelope, messages: messages)
        let scored = ExtractionConfidenceScorer().score(envelope: envelope, validationReport: report)

        #expect(report.fieldResults["risks"]?.hasBlockingErrors == true)
        #expect(scored.risks?.level == .rejected)
        #expect(scored.risks?.shouldAutoCommit == false)
    }

    @Test func scheduleOnlyBoundaryItemIsRejected() throws {
        let scheduleMessages = [
            ChatPayloadMessage.user("我希望 3 周完成。")
        ]
        let envelope = ExtractionEnvelope(
            boundaryItems: ExtractedFieldCandidate(
                value: [
                    BoundaryItemDTO(content: "3 周完成", isIncluded: true)
                ],
                confidence: 0.95,
                evidence: [EvidenceSpan(role: "user", quote: "3 周完成", turnIndex: 0)]
            )
        )

        let report = ExtractionSchemaValidator().validate(envelope: envelope, messages: scheduleMessages)
        let scored = ExtractionConfidenceScorer().score(envelope: envelope, validationReport: report)

        #expect(report.fieldResults["boundaryItems"]?.hasBlockingErrors == true)
        #expect(scored.boundaryItems?.level == .rejected)
        #expect(scored.boundaryItems?.shouldAutoCommit == false)
    }

    @Test func evidenceQuoteNotFoundIsRejected() throws {
        let envelope = ExtractionEnvelope(
            painPoint: ExtractedFieldCandidate(
                value: "容易错过考试",
                confidence: 0.9,
                evidence: [EvidenceSpan(role: "user", quote: "这句话并不存在", turnIndex: 0)]
            )
        )

        let report = ExtractionSchemaValidator().validate(envelope: envelope, messages: messages)
        let scored = ExtractionConfidenceScorer().score(envelope: envelope, validationReport: report)

        #expect(report.fieldResults["painPoint"]?.hasBlockingErrors == true)
        #expect(scored.painPoint?.level == .rejected)
    }

    @Test func assistantOnlyEvidenceCannotAutoCommit() throws {
        let envelope = ExtractionEnvelope(
            coreValue: ExtractedFieldCandidate(
                value: "减少新生迷路焦虑",
                confidence: 0.9,
                evidence: [EvidenceSpan(role: "assistant", quote: "你可以继续说明场景。", turnIndex: 1)]
            )
        )

        let report = ExtractionSchemaValidator().validate(envelope: envelope, messages: messages)
        let scored = ExtractionConfidenceScorer().score(envelope: envelope, validationReport: report)

        #expect(report.fieldResults["coreValue"]?.assistantOnlyEvidence == true)
        #expect(scored.coreValue?.shouldAutoCommit == false)
    }

    @Test func lowConfidenceFieldBecomesNeedsReviewOrRejected() throws {
        let envelope = ExtractionEnvelope(
            targetUser: ExtractedFieldCandidate(
                value: "学生",
                confidence: 0.1,
                evidence: [EvidenceSpan(role: "user", quote: "外地大一新生，他们开学第一周经常找不到教学楼", turnIndex: 0)]
            )
        )

        let report = ExtractionSchemaValidator().validate(envelope: envelope, messages: messages)
        let scored = ExtractionConfidenceScorer().score(envelope: envelope, validationReport: report)

        #expect(scored.targetUser?.level == .needsReview || scored.targetUser?.level == .rejected)
        #expect(scored.targetUser?.shouldAutoCommit == false)
    }

    @Test @MainActor func confirmedFieldCanAutoCommit() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let brief = DesignBrief()
        context.insert(brief)

        let outcome = ExtractionOutcome(
            source: .live,
            status: .succeeded,
            envelope: ExtractionEnvelope(
                targetUser: ExtractedFieldCandidate(
                    value: "外地大一新生",
                    confidence: 0.86,
                    level: .confirmed,
                    evidence: [EvidenceSpan(role: "user", quote: "外地大一新生，他们开学第一周经常找不到教学楼", turnIndex: 0)],
                    shouldAutoCommit: true
                )
            )
        )

        brief.applyValidatedExtraction(outcome: outcome, context: context)

        #expect(brief.targetUser == "外地大一新生")
        #expect(brief.extractionAuditLogs.first?.decisionValue == .autoCommitted)
    }

    @Test @MainActor func arrayMergeDoesNotDeleteExistingItems() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let brief = DesignBrief(boundaryItems: [BoundaryItem(content: "保留校园地图", isIncluded: true)])
        context.insert(brief)

        let outcome = ExtractionOutcome(
            source: .live,
            status: .succeeded,
            envelope: ExtractionEnvelope(
                boundaryItems: ExtractedFieldCandidate(
                    value: [BoundaryItemDTO(content: "加入路径提醒", isIncluded: true)],
                    confidence: 0.82,
                    level: .confirmed,
                    evidence: [EvidenceSpan(role: "user", quote: "经常找不到教学楼", turnIndex: 0)],
                    shouldAutoCommit: true
                )
            )
        )

        brief.applyValidatedExtraction(outcome: outcome, context: context)

        let contents = Set(brief.boundaryItems.map(\.content))
        #expect(contents.contains("保留校园地图"))
        #expect(contents.contains("加入路径提醒"))
        #expect(brief.boundaryItems.count == 2)
    }

    @Test @MainActor func futureStageCandidateIsDeferredUntilThatStage() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let brief = DesignBrief()
        context.insert(brief)

        let outcome = ExtractionOutcome(
            source: .live,
            status: .succeeded,
            envelope: ExtractionEnvelope(
                mvpFeatures: ExtractedFieldCandidate(
                    value: "状态总览与异常提醒",
                    confidence: 0.92,
                    level: .confirmed,
                    evidence: [
                        EvidenceSpan(
                            role: "user",
                            quote: "状态总览与异常提醒",
                            turnIndex: 0
                        )
                    ],
                    shouldAutoCommit: true
                )
            )
        )

        brief.applyValidatedExtraction(
            outcome: outcome,
            context: context,
            currentStageOrder: 1
        )

        #expect(brief.mvpFeatures == nil)
        #expect(
            brief.deferredExtractionLogs(forStageOrder: 4)
                .first?.candidateValue == "状态总览与异常提醒"
        )
        #expect(
            brief.extractionAuditLogs.first?.decisionValue
                == .deferredUntilStage
        )

        // Re-reading the same historical conversation after Stage 4 becomes
        // active must not bypass the explicit confirmation gate.
        brief.applyValidatedExtraction(
            outcome: outcome,
            context: context,
            currentStageOrder: 4
        )
        #expect(brief.mvpFeatures == nil)
        #expect(
            brief.deferredExtractionLogs(forStageOrder: 4).count == 1
        )
    }

    @Test func progressAnalyzerUnlocksOnlyTheNextStage() throws {
        let brief = DesignBriefSnapshot(
            targetUser: "独居老人",
            painPoint: "突发异常无法及时被家人发现",
            useScenario: "夜间独自在家时",
            coreValue: "更快发现异常",
            differentiation: "只关注家庭内异常状态",
            mvpFeatures: "状态总览与异常提醒",
            technicalModules: "传感器、规则引擎、通知模块",
            interactionFlow: "查看状态—发现异常—通知家人"
        )
        let stages = StageDefinition.all.map { definition in
            ProgressStageSnapshot(
                order: definition.order,
                name: definition.name,
                status: definition.order == 1
                    ? .active
                    : (definition.order == 4 ? .completed : .notStarted),
                completionRatio: definition.order == 4 ? 1 : 0
            )
        }

        let updated = ProgressAnalyzer().analyze(
            brief: brief,
            stages: stages
        )

        #expect(updated.first { $0.order == 1 }?.status == .completed)
        #expect(updated.first { $0.order == 2 }?.status == .active)
        #expect(updated.first { $0.order == 2 }?.completionRatio == 0)
        #expect(updated.first { $0.order == 4 }?.status == .notStarted)
        #expect(updated.first { $0.order == 4 }?.completionRatio == 0)
    }

    @Test func deferredConfirmationRecognizesConfirmationsAndCorrections() {
        let confirmation = DeferredStageConfirmation()

        #expect(confirmation.resolve("对，确认无误") == .confirmed)
        #expect(
            confirmation.resolve("不对，技术模块应该改为本地规则引擎")
                == .revisedOrRejected
        )
        #expect(confirmation.resolve("为什么需要再次确认？") == .unresolved)
    }

    @Test func stageThreeRequiresIncludeAndExcludeBoundaryItems() throws {
        let stage = try #require(StageDefinition.all.first { $0.order == 3 })

        let scheduleOnly = DesignBriefSnapshot(
            boundaryItems: [
                BoundaryItemDTO(content: "3 周完成", isIncluded: true)
            ]
        )
        #expect(stage.completionRatio(from: scheduleOnly) == 0)

        let includedOnly = DesignBriefSnapshot(
            boundaryItems: [
                BoundaryItemDTO(content: "第一版只做视频脚本生成", isIncluded: true)
            ]
        )
        #expect(stage.completionRatio(from: includedOnly) == 0.5)

        let includeAndExclude = DesignBriefSnapshot(
            boundaryItems: [
                BoundaryItemDTO(content: "第一版只做视频脚本生成", isIncluded: true),
                BoundaryItemDTO(content: "暂不做社交发布和复杂推荐", isIncluded: false),
            ]
        )
        #expect(stage.completionRatio(from: includeAndExclude) == 1)
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Project.self,
            ChatMessage.self,
            DesignBrief.self,
            ProgressStage.self,
            BoundaryItem.self,
            RiskItem.self,
            SuccessMetric.self,
            LearningTrace.self,
            ExtractionAuditLog.self,
            MindTreeAnnotation.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
