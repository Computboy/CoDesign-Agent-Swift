import SwiftUI

/// Renders a single node in the thinking tree with premium visual treatment.
struct TreeNodeView: View {
    let node: TreeNode
    var onTap: () -> Void = {}
    var onEdit: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                switch node.kind {
                case .root:   rootContent
                case .stage:  stageContent
                case .field:  fieldContent
                }
            }
            .buttonStyle(.plain)
            .opacity(node.isGhost ? 0.4 : (node.isArchived ? 0.55 : 1.0))
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: node.richness)

            // Edit button with glass morphism effect
            if !node.isGhost {
                Button(action: onEdit) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 22, height: 22)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.primaryAccent.opacity(0.9), Color.secondaryAccent.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 20, height: 20)

                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.primaryAccent.opacity(0.3), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .offset(x: 10, y: -10)
            }
        }
    }

    // MARK: - Root Node (Large gradient circle with depth)

    private var rootContent: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(Color.primaryAccent.opacity(0.15))
                .frame(width: 100, height: 100)
                .blur(radius: 12)

            // Main circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primaryAccent,
                            Color.secondaryAccent,
                            Color(red: 0.65, green: 0.52, blue: 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.primaryAccent.opacity(0.35), radius: 16, y: 6)
                .shadow(color: Color.secondaryAccent.opacity(0.25), radius: 8, y: 3)

            // Project name
            Text(truncate(node.content, maxLen: 8))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        }
    }

    // MARK: - Stage Node (Polished card with gradient border)

    private var stageContent: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // Stage number badge with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [node.nodeColor, node.nodeColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)

                    Text("\(node.stageOrder ?? 0)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: node.nodeColor.opacity(0.3), radius: 3, y: 1)

                // Stage name
                Text(node.subContent ?? "")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cardBackground,
                                Color.cardBackground.opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                node.nodeColor.opacity(node.isArchived ? 0.25 : 0.5),
                                node.nodeColor.opacity(node.isArchived ? 0.15 : 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: node.isArchived
                            ? StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                            : StrokeStyle(lineWidth: 1.5)
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            .shadow(color: node.nodeColor.opacity(0.08), radius: 4, y: 1)
            .frame(maxWidth: 180)

            // Archived label with pill style
            if node.isArchived {
                Text("v\(node.branchVersion) 旧版")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.5, blue: 0.45))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.6, green: 0.55, blue: 0.5).opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                Color(red: 0.6, green: 0.55, blue: 0.5).opacity(0.25),
                                lineWidth: 0.5
                            )
                    )
            }
        }
    }

    // MARK: - Field Node (Elegant card with content preview)

    private var fieldContent: some View {
        let maxWidth: CGFloat = 180
        return VStack(spacing: 5) {
            // Field name label with icon hint
            HStack(spacing: 4) {
                Circle()
                    .fill(node.nodeColor)
                    .frame(width: 4, height: 4)

                Text(node.content)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(node.nodeColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: maxWidth)

            // Value content card
            if let sub = node.subContent {
                Text(sub)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: maxWidth, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.cardBackground,
                                        Color.cardBackground.opacity(0.96)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        node.nodeColor.opacity(node.isArchived ? 0.2 : 0.35),
                                        node.nodeColor.opacity(node.isArchived ? 0.12 : 0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: node.isArchived
                                    ? StrokeStyle(lineWidth: 1, dash: [4, 3])
                                    : StrokeStyle(lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                    .frame(maxWidth: maxWidth)
            }

            // Archived label
            if node.isArchived {
                Text("旧版 v\(node.branchVersion)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.5, blue: 0.45))
            }
        }
    }

    private func truncate(_ s: String, maxLen: Int) -> String {
        s.count > maxLen ? String(s.prefix(maxLen)) + "…" : s
    }
}
