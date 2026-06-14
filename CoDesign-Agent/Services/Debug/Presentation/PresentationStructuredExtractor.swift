#if DEBUG
import Foundation

final class PresentationStructuredExtractor: StructuredExtractorProtocol {
    func extract(
        from messages: [ChatPayloadMessage],
        existing: DesignBriefSnapshot?
    ) async throws -> ExtractionOutcome {
        try await Task.sleep(for: .milliseconds(520))

        let lastUserText = messages.last(where: { $0.role == "user" })?.content ?? ""
        let turnIndex = messages.lastIndex(where: { $0.role == "user" }) ?? 0
        let evidence = [EvidenceSpan(role: "user", quote: lastUserText, turnIndex: turnIndex)]

        let envelope: ExtractionEnvelope
        if lastUserText.contains("18") || lastUserText.contains("短视频") || lastUserText.contains("记不住") {
            envelope = stageOneEnvelope(evidence: evidence)
        } else if lastUserText.contains("80") || lastUserText.contains("错误率") || lastUserText.contains("三周") {
            envelope = finalEnvelope(evidence: evidence)
        } else if lastUserText.contains("脚本") || lastUserText.contains("分镜") || lastUserText.contains("不做真实视频") {
            envelope = boundaryEnvelope(evidence: evidence)
        } else {
            envelope = ExtractionEnvelope()
        }

        return ExtractionOutcome(
            source: .mock,
            status: .succeeded,
            envelope: envelope,
            attemptCount: 1
        )
    }

    private func stageOneEnvelope(evidence: [EvidenceSpan]) -> ExtractionEnvelope {
        ExtractionEnvelope(
            targetUser: candidate(
                "18-24 岁大学生，尤其是需要在课程展示或校园文化活动中快速完成创作的学生",
                confidence: 0.94,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            painPoint: candidate(
                "传统文化内容常被感知为说教、遥远、记不住，难以在短视频语境中形成主动传播",
                confidence: 0.92,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            useScenario: candidate(
                "课程展示或校园文化活动前，学生需要在短时间内把文化主题转化成有记忆点的短视频脚本",
                confidence: 0.90,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            coreValue: candidate(
                "把传统文化知识转译为有情绪记忆点的短视频脚本和分镜，降低创作门槛",
                confidence: 0.88,
                evidence: evidence,
                shouldAutoCommit: false
            )
        )
    }

    private func boundaryEnvelope(evidence: [EvidenceSpan]) -> ExtractionEnvelope {
        ExtractionEnvelope(
            differentiation: candidate(
                "不是泛泛生成视频，而是围绕文化主题、受众情绪、传播场景和边界取舍生成可解释的创作方案",
                confidence: 0.90,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            boundaryItems: candidate(
                [
                    BoundaryItemDTO(content: "支持文化主题输入、目标受众选择和情绪目标设定", isIncluded: true),
                    BoundaryItemDTO(content: "生成短视频脚本、分镜草稿和文化依据卡片", isIncluded: true),
                    BoundaryItemDTO(content: "保留人工确认，不自动发布内容", isIncluded: true),
                    BoundaryItemDTO(content: "暂不做真实视频渲染和复杂剪辑", isIncluded: false),
                    BoundaryItemDTO(content: "暂不做社交平台账号运营和推荐算法", isIncluded: false),
                ],
                confidence: 0.93,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            mvpFeatures: candidate(
                "主题输入、受众画像选择、脚本生成、分镜草稿、文化依据卡片、人工确认与导出",
                confidence: 0.91,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            technicalModules: candidate(
                "LLM 脚本生成、RAG 文化素材检索、分镜结构化输出、人工审核节点、报告导出模块",
                confidence: 0.89,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            interactionFlow: candidate(
                "用户输入文化主题后，系统追问受众和传播目标，再生成脚本与分镜，最后由用户确认边界和导出简报",
                confidence: 0.88,
                evidence: evidence,
                shouldAutoCommit: true
            )
        )
    }

    private func finalEnvelope(evidence: [EvidenceSpan]) -> ExtractionEnvelope {
        ExtractionEnvelope(
            operationLogic: candidate(
                "AI 只提供创作建议和结构化草稿，关键文化解释、价值判断和最终发布内容由用户确认",
                confidence: 0.91,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            hardConstraints: candidate(
                "3 周内完成可演示原型；不得生成未经核验的文化事实；不得替代人工审核；优先使用公开可信材料",
                confidence: 0.92,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            successMetrics: candidate(
                [
                    SuccessMetricDTO(metric: "脚本可用率", target: ">= 80%", measurement: "5 名同学试用后认为脚本可继续修改成作品的比例"),
                    SuccessMetricDTO(metric: "文化事实错误率", target: "<= 5%", measurement: "人工抽查生成内容中的事实错误比例"),
                    SuccessMetricDTO(metric: "完成时间", target: "<= 10 分钟", measurement: "从输入主题到导出第一版简报的平均用时"),
                ],
                confidence: 0.93,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            risks: candidate(
                [
                    RiskItemDTO(desc: "AI 生成文化事实不准确", probability: 4, impact: 5, mitigation: "输出依据卡片并要求人工确认来源"),
                    RiskItemDTO(desc: "生成内容仍然像课堂讲稿，不适合短视频语境", probability: 3, impact: 4, mitigation: "加入情绪目标、冲突点和观看后行动的追问"),
                    RiskItemDTO(desc: "用户误以为系统可以直接生成最终视频", probability: 2, impact: 3, mitigation: "在界面和报告中明确 MVP 只覆盖脚本与分镜草稿"),
                ],
                confidence: 0.90,
                evidence: evidence,
                shouldAutoCommit: true
            ),
            milestones: candidate(
                "第 1 周完成用户场景与内容边界；第 2 周完成脚本/分镜生成原型；第 3 周完成测试、报告和课堂演示",
                confidence: 0.91,
                evidence: evidence,
                shouldAutoCommit: true
            )
        )
    }

    private func candidate<Value: Codable>(
        _ value: Value,
        confidence: Double,
        evidence: [EvidenceSpan],
        shouldAutoCommit: Bool
    ) -> ExtractedFieldCandidate<Value> {
        ExtractedFieldCandidate(
            value: value,
            confidence: confidence,
            level: .confirmed,
            evidence: evidence,
            validationNotes: ["presentation cached extraction"],
            shouldAutoCommit: shouldAutoCommit
        )
    }
}
#endif
