import SwiftUI

/// Developer-only debug view for running Dialogue Gym simulations.
/// Accessible from the Settings / Developer section.
/// NOT exposed to regular users.
struct DialogueGymDebugView: View {
    @State private var store = DialogueGymDebugStore()
    @State private var expandedReportID: UUID?
    @State private var showRunAllConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if store.reports.isEmpty && !store.isRunning {
                    emptyState
                } else {
                    reportList
                }
            }
            .navigationTitle("Dialogue Gym")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showRunAllConfirmation = true
                    }) {
                        if store.isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Label("Run All", systemImage: "play.fill")
                        }
                    }
                    .disabled(store.isRunning)
                }
            }
            .alert("Run all scenarios?", isPresented: $showRunAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Continue") {
                    Task { await store.runAllScenarios() }
                }
            } message: {
                Text("Running all scenarios may call the LLM many times. Continue?")
            }
            .overlay {
                if store.isRunning {
                    runningOverlay
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Dialogue Gym")
                .font(.title2.bold())

            Text("澄清对话训练场")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Label("调用真实 CoDesign Agent 生成追问", systemImage: "checkmark.circle")
                Label("LLM 模拟学生用户回答", systemImage: "checkmark.circle")
                Label("LLM 评估对话质量", systemImage: "checkmark.circle")
                Label("输出 SimulationReport", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("需要配置 Live LLM API Key")
                .font(.caption)
                .foregroundStyle(.orange)

            Button(action: {
                Task { await store.runFirstScenarioOnly() }
            }) {
                Label("Run First Scenario Only", systemImage: "1.circle.fill")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.bordered)
            .disabled(store.isRunning)

            Button(action: {
                showRunAllConfirmation = true
            }) {
                Label("Run 5 Built-in Scenarios", systemImage: "play.fill")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isRunning)
        }
        .padding()
    }

    // MARK: - Running Overlay

    private var runningOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Running scenarios...")
                .font(.headline)
            Text(store.progressText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Report List

    private var reportList: some View {
        List {
            ForEach(store.reports) { report in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedReportID == report.id },
                            set: { expandedReportID = $0 ? report.id : nil }
                        )
                    ) {
                        reportDetail(report)
                    } label: {
                        reportHeader(report)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Report Header

    private func reportHeader(_ report: SimulationReport) -> some View {
        HStack {
            // Overall score badge
            ZStack {
                Circle()
                    .fill(scoreColor(report.scores.overall))
                    .frame(width: 40, height: 40)
                Text("\(report.scores.overall)")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(report.scenarioTitle)
                    .font(.subheadline.bold())

                Text("\(report.transcript.count) turns · \(report.detectedProblems.count) problems")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Report Detail

    private func reportDetail(_ report: SimulationReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Scores grid
            Text("Evaluation Scores")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                scoreRow("questionNecessity", "问题必要性", report.scores.questionNecessity)
                scoreRow("stageAlignment", "阶段匹配", report.scores.stageAlignment)
                scoreRow("cognitiveProgress", "认知推动", report.scores.cognitiveProgress)
                scoreRow("userBurden", "用户负担", report.scores.userBurden)
                scoreRow("informationCompression", "信息压缩", report.scores.informationCompression)
                scoreRow("briefProgress", "Brief 进展", report.scores.briefProgress)
                scoreRow("convergenceQuality", "收敛质量", report.scores.convergenceQuality)
            }

            // Detected problems
            if !report.detectedProblems.isEmpty {
                Text("Detected Problems")
                    .font(.caption.bold())
                    .foregroundStyle(.red)

                ForEach(report.detectedProblems, id: \.self) { problem in
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Bad questions
            if !report.badQuestions.isEmpty {
                Text("Bad Questions")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)

                ForEach(report.badQuestions, id: \.self) { question in
                    Label(question, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Suggested fixes
            if !report.suggestedFixes.isEmpty {
                Text("Suggested Fixes")
                    .font(.caption.bold())
                    .foregroundStyle(.green)

                ForEach(report.suggestedFixes, id: \.self) { fix in
                    Label(fix, systemImage: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Final brief summary
            if !report.finalBriefSummary.isEmpty {
                Text("Final Brief Summary")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(report.finalBriefSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(10)
            }

            // Transcript (collapsed)
            if !report.transcript.isEmpty {
                DisclosureGroup("Transcript (\(report.transcript.count) turns)") {
                    ForEach(report.transcript) { turn in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Turn \(turn.turnIndex + 1) · \(turn.stageTitle)")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Text("Q: \(turn.agentQuestion)")
                                .font(.caption2)
                            Text("A: \(turn.simulatedUserAnswer)")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            if !turn.changedBriefFields.isEmpty {
                                Text("Fields: \(turn.changedBriefFields.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func scoreRow(_ key: String, _ label: String, _ value: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= value ? scoreColor(value) : Color.secondary.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func scoreColor(_ value: Int) -> Color {
        switch value {
        case 4...5: return .green
        case 3: return .yellow
        default: return .red
        }
    }
}

#Preview {
    DialogueGymDebugView()
}
