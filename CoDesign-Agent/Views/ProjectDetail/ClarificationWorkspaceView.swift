import SwiftUI

// MARK: - ClarificationWorkspaceView

/// The v0.3 main workspace view that replaces ChatPanel as the primary interface.
/// Organizes the design clarification process into a structured workspace layout.
///
/// ChatViewModel is injected from ProjectDetailView so that Workspace and Chat tab
/// share the same instance and message state stays in sync across tab switches.
struct ClarificationWorkspaceView: View {
    let project: Project
    let chatViewModel: ChatViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingMedium) {

                // 1. Workspace Header
                WorkspaceHeader(project: project)

                // 2. Stage Rail
                StageRail(stages: project.stages)

                // 3. Current Clarification Card
                CurrentClarificationCard(
                    project: project,
                    isStreaming: chatViewModel.isStreaming,
                    streamingText: chatViewModel.currentStreamingText
                )

                // 4. Answer Composer
                AnswerComposer(
                    isStreaming: chatViewModel.isStreaming,
                    onSend: { text in
                        Task {
                            await chatViewModel.sendMessage(text)
                        }
                    }
                )

                // 5. Error message
                if let errorMessage = chatViewModel.errorMessage {
                    CoDesignCard(style: .highlighted(.danger)) {
                        HStack(spacing: AppTheme.spacingSmall) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.danger)
                            Text(errorMessage)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(Color.danger)
                        }
                    }
                }

                // 6. Process Log (collapsed by default)
                ProcessLogDisclosure(
                    messages: project.messages,
                    isStreaming: chatViewModel.isStreaming,
                    streamingText: chatViewModel.currentStreamingText
                )

                // 7. Insights Panel (reused from existing)
                InsightsPanel(project: project)
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ClarificationWorkspaceView(
            project: {
                let p = Project(
                    name: "校园导航助手",
                    briefDescription: "帮助大一新生快速找到教室"
                )
                p.stages = [
                    ProgressStage(order: 1, name: "痛点与场景锚定", status: "active", completionRatio: 0.3),
                    ProgressStage(order: 2, name: "差异化价值提炼", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 3, name: "项目边界定义", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 4, name: "功能与技术拆解", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 5, name: "运行逻辑与规则", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 6, name: "硬性约束设计", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 7, name: "量化验收标准", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 8, name: "风险识别与预案", status: "notStarted", completionRatio: 0.0),
                    ProgressStage(order: 9, name: "项目阶段排期", status: "notStarted", completionRatio: 0.0),
                ]
                return p
            }(),
            chatViewModel: ChatViewModel(
                project: Project(name: "Preview", briefDescription: ""),
                llmService: MockLLMService(),
                extractor: MockStructuredExtractor()
            )
        )
    }
}
