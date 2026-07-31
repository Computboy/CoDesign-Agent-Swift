import SwiftUI

/// Premium legend overlay with refined styling.
struct TreeLegendView: View {
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppTheme.spacingSM) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("图例")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.vertical, AppTheme.spacingSmall)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                legendContent
                    .padding(AppTheme.spacingMedium)
                    .fixedSize(horizontal: true, vertical: true)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                            .strokeBorder(Color.white.opacity(AppTheme.Opacity.soft), lineWidth: 0.5)
                    )
                    .coDesignShadow(.elevated)
                    .padding(.top, AppTheme.spacingSM)
                    .transition(.opacity.combined(with: .move(edge: .leading).combined(with: .scale(scale: 0.95))))
            }
        }
    }

    private var legendContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("卡片类型")
                    .font(AppTheme.Typography.microSemibold)
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)

                ForEach(ResourceType.allCases) { type in
                    cardTypeRow(type)
                }
            }
        }
    }

    private func cardTypeRow(_ type: ResourceType) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: type.treeIcon)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(type.treeColor)
                .frame(width: 22, height: 22)
                .background(Circle().fill(type.treeColor.opacity(0.12)))

            Text(type.displayName)
                .font(AppTheme.Typography.tiny)
                .foregroundStyle(Color.textSecondary)
        }
    }

}
