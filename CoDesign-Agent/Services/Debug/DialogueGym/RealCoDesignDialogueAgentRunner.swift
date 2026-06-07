import Foundation
import SwiftData

/// Real adapter that drives the existing CoDesign Agent pipeline.
///
/// On each turn it:
/// 1. Saves the user message into conversation history
/// 2. Runs LiveStructuredExtractor to update DesignBrief
/// 3. Runs ProgressAnalyzer to update stage status
/// 4. Streams the next agent question from LiveLLMService
///
/// This is NOT a mock — it calls the same LiveLLMService,
/// SocraticPromptTemplates, LiveStructuredExtractor, and
/// ProgressAnalyzer used by the main app.
@MainActor
final class RealCoDesignDialogueAgentRunner: DialogueAgentRunning {
    private let llmService: LiveLLMService
    private let extractor: LiveStructuredExtractor
    private let analyzer = ProgressAnalyzer()

    /// In-memory SwiftData stack so temporary projects never pollute
    /// the user's real project list.
    private let container: ModelContainer
    private let project: Project

    /// In-memory conversation history (for extraction context).
    private var messages: [ChatPayloadMessage] = []

    /// Current brief state as snapshot.
    private var briefSnapshot: DesignBriefSnapshot

    /// Current stage snapshots.
    private var stageSnapshots: [ProgressStageSnapshot]

    /// Previous brief snapshot for detecting changed fields.
    private var previousBriefSnapshot: DesignBriefSnapshot

    // MARK: - Init

    init() throws {
        self.llmService = LiveLLMService()
        self.extractor = LiveStructuredExtractor()

        // Create in-memory SwiftData container
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
            ThinkingMoment.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw DialogueGymError.agentCreationFailed(
                "Cannot create in-memory ModelContainer: \(error.localizedDescription)"
            )
        }

        let context = container.mainContext

        // Create temporary project
        let project = Project(name: "[DialogueGym] Simulation Session")
        context.insert(project)

        // Create stages (1-9)
        var stages: [ProgressStage] = []
        for def in StageDefinition.all {
            let stage = ProgressStage(order: def.order, name: def.name)
            context.insert(stage)
            project.stages.append(stage)
            stages.append(stage)
        }

        // Create design brief
        let brief = DesignBrief()
        context.insert(brief)
        project.brief = brief

        try? context.save()

        self.project = project
        self.briefSnapshot = DesignBriefSnapshot()
        self.previousBriefSnapshot = DesignBriefSnapshot()
        self.stageSnapshots = stages.map { $0.toSnapshot() }
    }

    deinit {
        // Clean up in-memory data — nothing persists to disk.
    }

    // MARK: - DialogueAgentRunning

    func start(initialIdea: String, scenario: SimulationScenario) async throws -> DialogueAgentTurnResult {
        // Reset state for new session
        messages.removeAll()
        briefSnapshot = DesignBriefSnapshot()
        previousBriefSnapshot = DesignBriefSnapshot()

        // Save the initial idea as the first user message
        await saveUserMessage(initialIdea)
        messages.append(.user(initialIdea))

        // Run the core agent pipeline
        return try await processTurn(userText: initialIdea)
    }

    func sendUserAnswer(_ answer: String) async throws -> DialogueAgentTurnResult {
        // Save user answer
        await saveUserMessage(answer)
        messages.append(.user(answer))

        // Run the core agent pipeline
        return try await processTurn(userText: answer)
    }

    // MARK: - Core Pipeline (mirrors ChatViewModel.sendMessage)

    /// Runs the real CoDesign Agent pipeline:
    /// Extraction → Brief Update → Stage Update → Agent Response
    private func processTurn(userText: String) async throws -> DialogueAgentTurnResult {
        let context = container.mainContext

        // ① Snapshot current brief before extraction
        previousBriefSnapshot = briefSnapshot

        // ② Run LiveStructuredExtractor
        do {
            let outcome = try await extractor.extract(
                from: messages,
                existing: briefSnapshot
            )
            if let brief = project.brief {
                brief.applyValidatedExtraction(outcome: outcome, context: context)
            }
        } catch {
            print("[RealCoDesignDialogueAgentRunner] Extraction error: \(error)")
            // Continue even if extraction fails — we still want the agent to respond
        }

        // ③ Refresh brief snapshot
        if let brief = project.brief {
            briefSnapshot = brief.toSnapshot()
        }

        // ④ Compute changed brief fields
        let changedFields = computeChangedFields(
            from: previousBriefSnapshot,
            to: briefSnapshot
        )

        // ⑤ Update stage progress
        stageSnapshots = analyzer.analyze(
            brief: briefSnapshot,
            stages: stageSnapshots
        )

        // Apply stage updates to SwiftData models
        let sortedStages = project.stages.sorted { $0.order < $1.order }
        for (i, updated) in stageSnapshots.enumerated() {
            if i < sortedStages.count {
                let stage = sortedStages[i]
                stage.status = updated.status.rawValue
                stage.completionRatio = updated.completionRatio
                stage.lastUpdated = Date()
            }
        }
        try? context.save()

        // ⑥ Determine current active stage
        let activeStage = currentActiveStage()

        // ⑦ Stream agent response via LiveLLMService
        let assistantText: String
        do {
            let stream = llmService.streamChat(
                messages: messages,
                briefSnapshot: briefSnapshot,
                currentStage: activeStage
            )
            var full = ""
            for try await token in stream {
                full += token
            }
            assistantText = full.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw DialogueGymError.agentStreamFailed(
                "LLM stream failed: \(error.localizedDescription)"
            )
        }

        guard !assistantText.isEmpty else {
            throw DialogueGymError.agentStreamFailed("Agent returned empty response")
        }

        // ⑧ Save assistant message
        await saveAssistantMessage(assistantText)
        messages.append(.assistant(assistantText))

        // ⑨ Build result
        let stageTitle = activeStage?.name ?? "Unknown"
        let summary = buildBriefSummary()

        return DialogueAgentTurnResult(
            assistantText: assistantText,
            currentStageTitle: stageTitle,
            changedBriefFields: changedFields,
            briefSummary: summary
        )
    }

    // MARK: - Private Helpers

    private func currentActiveStage() -> ProgressStageSnapshot? {
        stageSnapshots.first { $0.status == .needsReview }
            ?? stageSnapshots.first { $0.status == .active }
            ?? stageSnapshots.first { $0.status == .notStarted }
    }

    private func computeChangedFields(
        from previous: DesignBriefSnapshot,
        to current: DesignBriefSnapshot
    ) -> [String] {
        var changed: [String] = []
        for field in BriefField.allCases {
            let prevFilled = field.isFilled(in: previous)
            let currFilled = field.isFilled(in: current)
            if !prevFilled && currFilled {
                changed.append(field.displayName)
            } else if prevFilled && currFilled {
                // Check for meaningful change
                let prevFingerprint = fieldFingerprint(field, in: previous)
                let currFingerprint = fieldFingerprint(field, in: current)
                if prevFingerprint != currFingerprint {
                    changed.append(field.displayName)
                }
            }
        }
        return changed
    }

    private func fieldFingerprint(_ field: BriefField, in snapshot: DesignBriefSnapshot) -> String {
        switch field {
        case .targetUser:
            return (snapshot.targetUser ?? "").lowercased()
        case .painPoint:
            return (snapshot.painPoint ?? "").lowercased()
        case .useScenario:
            return (snapshot.useScenario ?? "").lowercased()
        case .coreValue:
            return (snapshot.coreValue ?? "").lowercased()
        case .differentiation:
            return (snapshot.differentiation ?? "").lowercased()
        case .boundaryItems:
            return snapshot.boundaryItems
                .map { "\($0.isIncluded ? "in" : "out"):\($0.content)" }
                .sorted()
                .joined(separator: "|")
                .lowercased()
        case .mvpFeatures:
            return (snapshot.mvpFeatures ?? "").lowercased()
        case .technicalModules:
            return (snapshot.technicalModules ?? "").lowercased()
        case .interactionFlow:
            return (snapshot.interactionFlow ?? "").lowercased()
        case .operationLogic:
            return (snapshot.operationLogic ?? "").lowercased()
        case .hardConstraints:
            return (snapshot.hardConstraints ?? "").lowercased()
        case .successMetrics:
            return snapshot.successMetrics
                .map { "\($0.metric):\($0.target)" }
                .sorted()
                .joined(separator: "|")
                .lowercased()
        case .risks:
            return snapshot.risks
                .map { "\($0.desc):p\($0.probability)i\($0.impact)" }
                .sorted()
                .joined(separator: "|")
                .lowercased()
        case .milestones:
            return (snapshot.milestones ?? "").lowercased()
        }
    }

    private func buildBriefSummary() -> String {
        var lines: [String] = []
        if let v = briefSnapshot.targetUser { lines.append("目标用户：\(v)") }
        if let v = briefSnapshot.painPoint { lines.append("痛点：\(v)") }
        if let v = briefSnapshot.useScenario { lines.append("场景：\(v)") }
        if let v = briefSnapshot.coreValue { lines.append("核心价值：\(v)") }
        if let v = briefSnapshot.differentiation { lines.append("差异化：\(v)") }
        if !briefSnapshot.boundaryItems.isEmpty {
            let items = briefSnapshot.boundaryItems.map { "\($0.isIncluded ? "[做]" : "[不做]") \($0.content)" }
            lines.append("边界：\(items.joined(separator: "; "))")
        }
        if let v = briefSnapshot.mvpFeatures { lines.append("MVP功能：\(v)") }
        if let v = briefSnapshot.technicalModules { lines.append("技术模块：\(v)") }
        if let v = briefSnapshot.interactionFlow { lines.append("交互流程：\(v)") }
        if let v = briefSnapshot.operationLogic { lines.append("运行逻辑：\(v)") }
        if let v = briefSnapshot.hardConstraints { lines.append("硬性约束：\(v)") }
        if !briefSnapshot.successMetrics.isEmpty {
            let metrics = briefSnapshot.successMetrics.map { "\($0.metric)=\($0.target)" }
            lines.append("验收标准：\(metrics.joined(separator: "; "))")
        }
        if !briefSnapshot.risks.isEmpty {
            let risks = briefSnapshot.risks.map { "\($0.desc)(P\($0.probability)/I\($0.impact))" }
            lines.append("风险：\(risks.joined(separator: "; "))")
        }
        if let v = briefSnapshot.milestones { lines.append("里程碑：\(v)") }
        return lines.isEmpty ? "暂无简报信息" : lines.joined(separator: "\n")
    }

    // MARK: - SwiftData Persistence (in-memory only)

    private func saveUserMessage(_ text: String) async {
        let context = container.mainContext
        let msg = ChatMessage(role: "user", content: text)
        context.insert(msg)
        project.messages.append(msg)
        project.updatedAt = Date()
        try? context.save()
    }

    private func saveAssistantMessage(_ text: String) async {
        let context = container.mainContext
        let msg = ChatMessage(role: "assistant", content: text)
        context.insert(msg)
        project.messages.append(msg)
        project.updatedAt = Date()
        try? context.save()
    }
}
