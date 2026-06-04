import SwiftUI

/// Renders a single node in the thinking tree.
struct TreeNodeView: View {
    let node: TreeNode
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            switch node.kind {
            case .root:   rootContent
            case .stage:  stageContent
            case .field:  fieldContent
            }
        }
        .buttonStyle(.plain)
        .opacity(node.isGhost ? 0.45 : 1.0)
        .animation(AppTheme.Animation.spring, value: node.richness)
    }

    // MARK: - Root Node

    private var rootContent: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.primaryAccent, Color.secondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: Color.primaryAccent.opacity(0.25), radius: 12, y: 4)

            Text(truncate(node.content, maxLen: 6))
                .font(AppTheme.Typography.caption.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Stage Node

    private var stageContent: some View {
        let size: CGFloat = 48
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(node.nodeColor.opacity(node.isGhost ? 0.12 : 0.18))
                    .frame(width: size, height: size)

                if node.isGhost {
                    Circle()
                        .strokeBorder(
                            node.nodeColor.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .frame(width: size, height: size)
                } else {
                    Circle()
                        .strokeBorder(node.nodeColor.opacity(0.5), lineWidth: 1.5)
                        .frame(width: size, height: size)
                }

                Text(node.content)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(node.isGhost ? node.nodeColor.opacity(0.5) : node.nodeColor)
            }

            if let subtitle = node.subContent {
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    // MARK: - Field Node

    private var fieldContent: some View {
        let maxWidth: CGFloat = 120
        return VStack(spacing: 3) {
            Text(node.content)
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundStyle(node.isGhost ? node.nodeColor.opacity(0.6) : node.nodeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(node.isGhost
                              ? node.nodeColor.opacity(0.05)
                              : node.nodeColor.opacity(0.10))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            node.nodeColor.opacity(node.isGhost ? 0.25 : 0.40),
                            style: node.isGhost
                                ? StrokeStyle(lineWidth: 1, dash: [3, 2])
                                : StrokeStyle(lineWidth: 1)
                        )
                )
                .frame(maxWidth: maxWidth)

            if let sub = node.subContent {
                Text(truncate(sub, maxLen: 16))
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: maxWidth)
            }
        }
    }

    private func truncate(_ s: String, maxLen: Int) -> String {
        s.count > maxLen ? String(s.prefix(maxLen)) + "…" : s
    }
}
