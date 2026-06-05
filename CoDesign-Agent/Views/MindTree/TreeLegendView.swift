import SwiftUI

/// Premium legend overlay with refined styling.
struct TreeLegendView: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("图例")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.95))))
            }
        }
    }

    private var legendContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status colors
            VStack(alignment: .leading, spacing: 8) {
                Text("状态")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)

                legendRow(color: .success, label: "已完成")
                legendRow(color: .primaryAccent, label: "进行中")
                legendRow(color: .warning, label: "待修正")
                legendRow(color: .stageNotStarted, label: "未开始", dashed: true)
                legendRow(color: Color(red: 0.58, green: 0.53, blue: 0.48), label: "旧版(已归档)", dashed: true)
            }

            Divider()
                .opacity(0.3)

            // Interaction hints
            VStack(alignment: .leading, spacing: 6) {
                Text("操作")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)

                hintRow(icon: "hand.draw.fill", text: "捏合缩放 · 拖动平移")
                hintRow(icon: "hand.tap.fill", text: "点击节点查看详情")
                hintRow(icon: "pencil.circle.fill", text: "编辑按钮修改节点")
            }
        }
    }

    private func legendRow(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(dashed ? 0.15 : 0.25))
                    .frame(width: 14, height: 14)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                color.opacity(0.6),
                                style: dashed
                                    ? StrokeStyle(lineWidth: 1, dash: [2, 2])
                                    : StrokeStyle(lineWidth: 1)
                            )
                    )
            }

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func hintRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.primaryAccent.opacity(0.7))
                .frame(width: 16)

            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textTertiary)
        }
    }
}
