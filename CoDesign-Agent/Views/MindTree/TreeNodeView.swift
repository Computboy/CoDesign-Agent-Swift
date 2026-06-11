import SwiftUI

/// Renders a single node in the thinking tree with compact semantic styles.
struct TreeNodeView: View {
    let node: TreeNode
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            content
        }
        .buttonStyle(.plain)
        .opacity(nodeOpacity)
        .animation(AppTheme.Animation.spring, value: node.position.x)
        .animation(AppTheme.Animation.spring, value: node.position.y)
    }

    @ViewBuilder
    private var content: some View {
        switch node.kind {
        case .root:
            rootContent
        case .stage, .branchStage:
            stageContent
        case .question:
            questionContent
        case .field:
            processContent(width: 174)
        case .process:
            processContent(width: 166)
        case .evidence:
            evidenceContent
        case .revision:
            processContent(width: 164)
        }
    }

    // MARK: - Root Node

    private var rootContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16, weight: .bold))

            Text(node.content)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 190)
        .frame(minHeight: 78)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primaryAccent,
                            Color.secondaryAccent,
                            Color(red: 0.38, green: 0.66, blue: 0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.primaryAccent.opacity(AppTheme.Opacity.noticeable), radius: 18, y: 7)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.46), lineWidth: 1.4)
        }
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.primaryAccent.opacity(0.13 + node.richness * 0.08))
                .blur(radius: 12)
                .padding(-10)
        }
    }

    // MARK: - Stage Node

    private var stageContent: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(node.nodeColor.opacity(node.isGhost ? 0.12 : 0.18))
                    .frame(width: 34, height: 34)

                Image(systemName: node.iconSystemName ?? "circle.grid.3x3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(node.isGhost ? Color.textTertiary : node.nodeColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(node.content)
                        .font(AppTheme.Typography.captionMono)
                        .foregroundStyle(node.isGhost ? Color.textTertiary : node.nodeColor)
                    if let statusText = node.statusText {
                        Text(statusText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(node.isGhost ? Color.textTertiary : node.nodeColor)
                    }
                }

                Text(node.subContent ?? "")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(node.isGhost ? Color.textSecondary : Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.Layout.compactPadding)
        .frame(width: 214, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(stageBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(
                    node.nodeColor.opacity(node.isGhost ? 0.13 : 0.34),
                    style: node.isGhost
                        ? StrokeStyle(lineWidth: 1, dash: [5, 5])
                        : StrokeStyle(lineWidth: 1.2)
                )
        )
        .shadow(
            color: node.kind == .stage && node.statusText == "进行中"
                ? node.nodeColor.opacity(AppTheme.Opacity.noticeable)
                : .black.opacity(AppTheme.Opacity.hairline),
            radius: node.statusText == "进行中" ? 14 : 10,
            y: 5
        )
    }

    private var stageBackground: Color {
        if node.isGhost {
            return Color.cardBackground.opacity(AppTheme.Opacity.muted)
        }
        return Color.cardBackground.opacity(AppTheme.Opacity.nearFull)
    }

    // MARK: - Process Nodes

    private var questionContent: some View {
        HStack(spacing: 7) {
            Image(systemName: node.isArchived ? "arrow.uturn.backward" : "questionmark")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(questionForeground)
                .frame(width: 20, height: 20)
                .background(Circle().fill(questionForeground.opacity(0.12)))

            Text(questionSummary)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(questionTextColor)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 184, alignment: .leading)
        .frame(minHeight: 48)
        .background(
            Capsule(style: .continuous)
                .fill(questionBackground)
                .shadow(color: questionForeground.opacity(0.10), radius: 8, y: 3)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    questionForeground.opacity(node.isArchived ? 0.24 : 0.30),
                    style: node.isArchived
                        ? StrokeStyle(lineWidth: 1, dash: [5, 5])
                        : StrokeStyle(lineWidth: 1.1)
                )
        )
        .overlay(alignment: .bottomTrailing) {
            if node.isArchived {
                Circle()
                    .fill(Color(red: 0.58, green: 0.59, blue: 0.64))
                    .frame(width: 10, height: 10)
                    .offset(x: -7, y: -5)
            }
        }
    }

    private var questionSummary: String {
        let flattened = node.content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flattened.count > 28 else { return flattened }
        return String(flattened.prefix(28)) + "..."
    }

    private var questionForeground: Color {
        node.isArchived ? Color(red: 0.58, green: 0.59, blue: 0.64) : Color.primaryAccent
    }

    private var questionTextColor: Color {
        node.isArchived ? Color.textSecondary : Color.textPrimary
    }

    private var questionBackground: Color {
        if node.isArchived {
            return Color(red: 0.82, green: 0.84, blue: 0.93).opacity(0.82)
        }
        return Color.primaryAccent.opacity(0.15)
    }

    private func processContent(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: node.iconSystemName ?? "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(node.nodeColor)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(node.nodeColor.opacity(0.12)))

                Text(node.processLabel ?? "Process")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(node.nodeColor)

                Spacer(minLength: 0)
            }

            Text(node.content)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let subContent = node.subContent {
                Text(subContent)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(node.isArchived ? Color(red: 0.95, green: 0.93, blue: 0.90).opacity(AppTheme.Opacity.nearFull) : Color.cardBackground.opacity(AppTheme.Opacity.nearFull))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(
                    node.nodeColor.opacity(node.isArchived ? 0.28 : 0.22),
                    style: node.isArchived
                        ? StrokeStyle(lineWidth: 1, dash: [4, 4])
                        : StrokeStyle(lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 7, y: 3)
    }

    private var evidenceContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondaryAccent)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.secondaryAccent.opacity(0.12)))

                Text("RAG")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.secondaryAccent)

                Spacer(minLength: 0)

                if node.isGhost {
                    Text("推荐")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Text(node.content)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let subContent = node.subContent {
                Text(subContent)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(width: 178, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(Color.secondaryAccent.opacity(node.isGhost ? 0.055 : AppTheme.Opacity.light))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(
                    Color.secondaryAccent.opacity(node.isGhost ? 0.18 : 0.34),
                    style: node.isGhost
                        ? StrokeStyle(lineWidth: 1, dash: [5, 5])
                        : StrokeStyle(lineWidth: 1)
                )
        )
    }

    private var nodeOpacity: Double {
        if node.isArchived { return 0.72 }
        if node.isGhost { return 0.64 }
        return 1.0
    }

}
