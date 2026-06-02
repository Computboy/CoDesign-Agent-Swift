import SwiftUI

struct ResourceCardView: View {
    let resource: ResourceCard

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                Text(resource.type.displayName)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(typeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(typeColor.opacity(0.10))
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

            Text(resource.summary)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            recommendationBlock(title: "为什么推荐", text: resource.whyRelevant)

            if isExpanded {
                recommendationBlock(title: "怎么使用", text: resource.howToUse)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if let url = resource.sourceURL {
                    Link(destination: url) {
                        Label("查看论文来源", systemImage: "arrow.up.right.square")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.orange)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.36), lineWidth: AppTheme.Border.thin)
        )
        .scaleEffect(isExpanded ? 1.01 : 1.0)
        .coDesignShadow(.card)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            withAnimation(AppTheme.Animation.spring) {
                isExpanded.toggle()
            }
        }
        .accessibilityHint(isExpanded ? "点击收起资源说明" : "点击展开怎么使用")
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
        VStack(alignment: .leading, spacing: 3) {
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
