import SwiftUI

/// 阶段解释弹窗，长按 StagePill 时显示
struct StageExplanationPopover: View {
    let stage: ProgressStage
    let definition: StageDefinition
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // 弹窗内容
            CoDesignCard {
                StageExplanationContent(
                    stage: stage,
                    definition: definition,
                    onDismiss: onDismiss
                )
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, AppTheme.spacingLarge)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// Anchored stage help used by the wide bottom timeline.
/// The system popover supplies the bubble shape and arrow; this view only supplies its content.
struct StageExplanationBubble: View {
    let stage: ProgressStage
    let definition: StageDefinition
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            StageExplanationContent(
                stage: stage,
                definition: definition,
                onDismiss: onDismiss
            )
            .padding(.horizontal, 24)
            .padding(.vertical, AppTheme.spacingLarge)
        }
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.16), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
        )
        .coDesignShadow(.elevated)
    }
}

private struct StageExplanationContent: View {
    let stage: ProgressStage
    let definition: StageDefinition
    let onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
            HStack(spacing: AppTheme.spacingMedium) {
                ZStack {
                    Circle()
                        .fill(Color.primaryAccent.opacity(AppTheme.Opacity.medium))

                    Image(systemName: definition.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primaryAccent)
                }
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                    Text("阶段 \(stage.order)")
                        .font(AppTheme.Typography.captionMono)
                        .foregroundStyle(Color.primaryAccent)

                    Text(stage.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppTheme.spacingSmall)

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(Color.textTertiary)
                            .frame(width: 44, height: 44, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭阶段说明")
                    .accessibilityIdentifier("workspace.stageExplanation.close")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                StageExplanationSectionHeader(
                    title: "阶段目标",
                    systemImage: "scope"
                )

                Text(definition.description)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !definition.briefFields.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    StageExplanationSectionHeader(
                        title: "影响字段",
                        systemImage: "square.stack.3d.up"
                    )

                    CoDesignFlowLayout(spacing: AppTheme.spacingSmall) {
                        ForEach(definition.briefFields, id: \.rawValue) { field in
                            HStack(spacing: AppTheme.spacingXS) {
                                Image(systemName: field.systemImage)
                                    .font(.system(size: 10, weight: .semibold))
                                    .accessibilityHidden(true)

                                Text(field.displayName)
                            }
                                .font(AppTheme.Typography.caption.weight(.medium))
                                .foregroundStyle(Color.primaryAccent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.primaryAccent.opacity(0.1))
                                )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                StageExplanationSectionHeader(
                    title: "思考问题",
                    systemImage: "questionmark.bubble"
                )

                ForEach(
                    Array(definition.thinkingQuestions.enumerated()),
                    id: \.element
                ) { index, question in
                    StageExplanationQuestionRow(
                        number: index + 1,
                        question: question
                    )
                }
            }
        }
    }
}

private struct StageExplanationSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primaryAccent)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StageExplanationQuestionRow: View {
    let number: Int
    let question: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            Text("\(number)")
                .font(AppTheme.Typography.tinySemibold.monospacedDigit())
                .foregroundStyle(Color.primaryAccent)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(Color.primaryAccent.opacity(AppTheme.Opacity.light))
                )

            Text(question)
                .font(AppTheme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    StageExplanationPopover(
        stage: ProgressStage(order: 1, name: "痛点与场景锚定", status: "active", completionRatio: 0.5),
        definition: StageDefinition.all[0],
        onDismiss: {}
    )
}
