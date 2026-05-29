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
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    // 标题
                    HStack {
                        Text("阶段 \(stage.order)")
                            .font(AppTheme.Typography.captionMono)
                            .foregroundStyle(Color.primaryAccent)

                        Text(stage.name)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.textTertiary)
                        }
                    }

                    // 阶段目标
                    VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                        Text("阶段目标")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.textTertiary)

                        Text(definition.description)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // 影响字段
                    if !definition.briefFields.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                            Text("影响字段")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(Color.textTertiary)

                            CoDesignFlowLayout(spacing: AppTheme.spacingXS) {
                                ForEach(definition.briefFields, id: \.rawValue) { field in
                                    Text(field.displayName)
                                        .font(AppTheme.Typography.caption.weight(.medium))
                                        .foregroundStyle(Color.primaryAccent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.primaryAccent.opacity(0.1))
                                        )
                                }
                            }
                        }
                    }

                    // 思考问题
                    VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                        Text("思考问题")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.textTertiary)

                        ForEach(Array(definition.thinkingQuestions.enumerated()), id: \.offset) { index, question in
                            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                                Text("•")
                                    .font(AppTheme.Typography.body)
                                    .foregroundStyle(Color.textSecondary)
                                Text(question)
                                    .font(AppTheme.Typography.body)
                                    .foregroundStyle(Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, AppTheme.spacingLarge)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

#Preview {
    StageExplanationPopover(
        stage: ProgressStage(order: 1, name: "痛点与场景锚定", status: "active", completionRatio: 0.5),
        definition: StageDefinition.all[0],
        onDismiss: {}
    )
}
