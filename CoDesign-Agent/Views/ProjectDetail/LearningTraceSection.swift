import SwiftUI

// MARK: - LearningTraceSection

/// Horizontal carousel of learning traces in the centre column.
/// Default: only the carousel of small cards is visible.
/// Tap a card → a detail overlay appears above the carousel.
/// Tap close or another card → overlay updates or dismisses.
///
/// Pure UI layer — reuses existing LearningTrace data.  No new DB fields.

struct LearningTraceSection: View {
    let project: Project

    @State private var selectedTrace: LearningTrace?
    @State private var showingDetail = false
    @State private var isHoveringCarousel = false

    private var sortedTraces: [LearningTrace] {
        project.learningTraces.sorted { $0.timestamp > $1.timestamp }
    }

    private var recentTraces: [LearningTrace] {
        Array(sortedTraces.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {

            // MARK: Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text("学习轨迹")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(Color.textPrimary)

                    Text("你的回答如何改变任务理解、边界与设计判断")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                if !recentTraces.isEmpty {
                    Text("\(recentTraces.count) records")
                        .font(AppTheme.Typography.captionMono)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            if recentTraces.isEmpty {
                emptyState
            } else {
                // MARK: Carousel + optional overlay
                ZStack(alignment: .top) {

                    // Detail overlay — only visible when a card is tapped
                    if showingDetail, let trace = selectedTrace {
                        detailOverlay(for: trace)
                            .transition(
                                .move(edge: .top)
                                .combined(with: .opacity)
                            )
                            .zIndex(1)
                    }

                    // Carousel always visible
                    carousel
                        .zIndex(0)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        CoDesignCard {
            VStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.textTertiary)

                Text("还没有学习轨迹")
                    .font(AppTheme.Typography.body.weight(.medium))
                    .foregroundStyle(Color.textSecondary)

                Text("完成一次澄清后，这里会记录你的设计判断变化。")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Detail Overlay (bubble)

    private func detailOverlay(for trace: LearningTrace) -> some View {
        let (icon, color) = iconAndColor(for: trace)

        return VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {

            // Top row: icon + title + stage + close
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(color.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(shortTitle(for: trace))
                        .font(AppTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(actionDisplayName(for: trace.actionType))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(color.opacity(0.08))
                        )
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("阶段 \(trace.stageOrder)")
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(color)

                    Text(trace.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                }

                Button {
                    withAnimation(AppTheme.Animation.spring) {
                        showingDetail = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Detail text
            Text(trace.detail)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.12), lineWidth: AppTheme.Border.thin)
        )
        .coDesignShadow(.elevated)
    }

    // MARK: - Carousel

    private var carousel: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(recentTraces) { trace in
                        smallCard(for: trace)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onHover { hovering in
                withAnimation(AppTheme.Animation.quick) {
                    isHoveringCarousel = hovering
                }
            }

            // Subtle hover indicator bar
            hoverIndicator
        }
    }

    private var hoverIndicator: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color.primaryAccent.opacity(isHoveringCarousel ? 0.35 : 0.0))
            .frame(height: 2)
            .padding(.top, 6)
            .animation(AppTheme.Animation.quick, value: isHoveringCarousel)
    }

    // MARK: - Small Card

    private func smallCard(for trace: LearningTrace) -> some View {
        let isSelected = showingDetail && trace.id == selectedTrace?.id
        let (icon, color) = iconAndColor(for: trace)

        return Button {
            withAnimation(AppTheme.Animation.spring) {
                if isSelected {
                    // Tap same card → dismiss
                    showingDetail = false
                    selectedTrace = nil
                } else {
                    selectedTrace = trace
                    showingDetail = true
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? color : Color.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? color.opacity(0.12) : Color.textTertiary.opacity(0.06))
                    )

                Spacer(minLength: 2)

                Text(shortTitle(for: trace))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text("S\(trace.stageOrder)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isSelected ? color : Color.textTertiary)
                }
            }
            .padding(12)
            .frame(width: 130, height: 96, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected
                        ? Color.primaryAccent.opacity(0.06)
                        : Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.primaryAccent.opacity(0.40) : Color.primaryAccent.opacity(0.08),
                        lineWidth: isSelected ? AppTheme.Border.medium : AppTheme.Border.thin
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func iconAndColor(for trace: LearningTrace) -> (String, Color) {
        switch trace.actionType {
        case "reframe":        return ("arrow.triangle.2.circlepath", Color.primaryAccent)
        case "converge":       return ("scope", Color.success)
        case "boundaryShrink": return ("rectangle.compress.vertical", Color.warning)
        default:               return ("sparkles", Color.textTertiary)
        }
    }

    private func actionDisplayName(for actionType: String) -> String {
        switch actionType {
        case "reframe":        return "重新定义"
        case "converge":       return "收敛推进"
        case "boundaryShrink": return "边界收缩"
        default:               return actionType
        }
    }

    private func shortTitle(for trace: LearningTrace) -> String {
        let t = trace.title

        if t.hasPrefix("你完成了一次") {
            return String(t.dropFirst("你完成了一次".count))
        }

        let mappings: [String: String] = [
            "重新定义问题": "重新定义",
            "收缩项目边界": "边界收缩",
            "收敛核心痛点": "痛点收敛",
        ]
        if let mapped = mappings[t] { return mapped }

        if t.count > 6 { return String(t.prefix(6)) }
        return t
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: AppTheme.spacingLarge) {

            LearningTraceSection(project: {
                let p = Project(name: "校园导航", briefDescription: "")
                p.learningTraces = [
                    LearningTrace(
                        stageOrder: 1,
                        actionType: "reframe",
                        title: "重新定义问题",
                        detail: "你把问题从'找不到教室'重新定义为'校园空间认知负担过重'",
                        timestamp: Date()
                    ),
                    LearningTrace(
                        stageOrder: 3,
                        actionType: "converge",
                        title: "收敛核心痛点",
                        detail: "通过对话，你明确了三个最关键的用户痛点",
                        timestamp: Date().addingTimeInterval(-3600)
                    ),
                    LearningTrace(
                        stageOrder: 2,
                        actionType: "boundaryShrink",
                        title: "收缩项目边界",
                        detail: "你主动排除了'社交功能'和'外卖配送'，聚焦核心导航需求",
                        timestamp: Date().addingTimeInterval(-7200)
                    ),
                    LearningTrace(
                        stageOrder: 4,
                        actionType: "converge",
                        title: "方案拆解与推进",
                        detail: "你将核心功能拆解为 5 个可执行模块并确定了技术方案",
                        timestamp: Date().addingTimeInterval(-10800)
                    ),
                ]
                return p
            }())

            Divider()

            LearningTraceSection(project: Project(name: "新项目", briefDescription: ""))
        }
        .padding()
    }
    .background(Color.appBackground)
}
