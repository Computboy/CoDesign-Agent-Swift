import SwiftUI

/// Small legend overlay for the thinking tree view.
struct TreeLegendView: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(AppTheme.Animation.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppTheme.spacingXS) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("图例")
                        .font(AppTheme.Typography.caption.weight(.medium))
                }
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.cardBackground.opacity(0.85))
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                legendContent
                    .padding(AppTheme.spacingMedium)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                            .fill(Color.cardBackground.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
                    )
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var legendContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            legendRow(color: .success, label: "已完成")
            legendRow(color: .primaryAccent, label: "进行中")
            legendRow(color: .warning, label: "待修正")
            legendRow(color: .stageNotStarted, label: "未探索", dashed: true)

            Divider()
                .padding(.vertical, 2)

            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                Text("捏合缩放 · 拖动平移")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                Text("点击节点查看详情")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private func legendRow(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Circle()
                .fill(color.opacity(dashed ? 0.15 : 0.25))
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .strokeBorder(
                            color.opacity(0.6),
                            style: dashed
                                ? StrokeStyle(lineWidth: 1, dash: [2, 2])
                                : StrokeStyle(lineWidth: 1)
                        )
                )
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }
}
