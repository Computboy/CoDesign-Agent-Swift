import SwiftUI

struct ResourceCardView: View {
    let resource: ResourceCard

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                Text(typeLabel)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(typeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(typeColor.opacity(0.10))
                    )

                Text(roleLabel)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.textTertiary.opacity(0.08))
                    )

                if let metaText {
                    Text(metaText)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer(minLength: AppTheme.spacingSmall)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }

            Text(resource.title)
                .font(AppTheme.Typography.subheadline.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(resource.userDisplayText)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            recommendationBlock(title: "核心观点", text: resource.promptCoreIdea)
            recommendationBlock(title: "为什么与当前阶段相关", text: resource.whyRelevant)

            if isExpanded {
                recommendationBlock(title: "它帮助完成的设计判断", text: resource.processActionText)
                    .transition(.opacity)

                recommendationBlock(title: "AI 可以怎样用", text: resource.promptRAGUse)
                    .transition(.opacity)

                recommendationBlock(title: "可能追问", text: resource.promptExampleQuestion)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                recommendationBlock(title: "依据说明", text: resource.evidenceDisplayText)
                    .transition(.opacity)

                if let sourceText = resource.sourceDisplayText {
                    recommendationBlock(title: "来源简写", text: sourceText)
                        .transition(.opacity)
                }

                if let url = resource.sourceURL {
                    Link(destination: url) {
                        Label("查看来源", systemImage: "arrow.up.right.square")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.warning)
                    }
                    .padding(.top, AppTheme.spacingXXS)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color.warning.opacity(AppTheme.Opacity.noticeable), lineWidth: AppTheme.Border.thin)
        )
        .scaleEffect(isExpanded ? 1.01 : 1.0)
        .coDesignShadow(.card)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.20)) {
                isExpanded.toggle()
            }
        }
        .accessibilityHint(isExpanded ? "点击收起设计依据说明" : "点击查看 AI 为什么这样问")
    }

    private var typeLabel: String {
        resource.type == .paper ? "RAG" : resource.type.displayName
    }

    private var roleLabel: String {
        switch resource.cardRole {
        case .content:
            return "设计依据"
        case .questionStrategy, .cognitiveDepth, .scaffoldingStrategy:
            return resource.cardRole.displayName
        default:
            return resource.cardRole.displayName
        }
    }

    private var metaText: String? {
        let parts = [
            resource.year.map { "\($0)" },
            resource.venue?.isEmpty == false ? resource.venue : nil
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var typeColor: Color {
        switch resource.type {
        case .paper: return Color.primaryAccent
        case .method: return Color.success
        case .caseStudy: return Color.info
        case .designPrinciple: return Color.warning
        case .courseFramework: return Color.secondaryAccent
        }
    }

    private func recommendationBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ResourceCardView(resource: ResourceLibrary.all[0])
        .padding()
        .background(Color.appBackground)
}
