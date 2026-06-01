import SwiftUI

// MARK: - StructuredProjectSnapshot

/// A lightweight grid of 5 key DesignBrief field cards shown in the centre column.
/// Each card displays the field icon, title, current value (2–3 lines max),
/// a status badge, and an optional edit pencil.
///
/// Pure UI layer — no new Model / DB fields.  Reuses BriefField.displayName
/// and the existing DesignBrief → snapshot value-reading logic from EditableInsightCard.

struct StructuredProjectSnapshot: View {
    let project: Project
    var onEditField: ((BriefField) -> Void)? = nil

    // MARK: - Fields to display

    private let displayFields: [BriefField] = [
        .targetUser,
        .painPoint,
        .coreValue,
        .boundaryItems,
        .mvpFeatures,
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {

            // Section header
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text("Structured Project Snapshot")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(Color.textPrimary)
                    Text("\(filledCount) of \(displayFields.count) fields extracted")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                // Edit All — visual placeholder, not wired yet
                if onEditField != nil {
                    Button {
                        // TODO: open bulk edit
                        print("[StructuredProjectSnapshot] Edit All tapped")
                    } label: {
                        Label("Edit All", systemImage: "pencil.line")
                            .font(AppTheme.Typography.caption.weight(.medium))
                            .foregroundStyle(Color.primaryAccent)
                            .padding(.horizontal, 10)
                            .frame(height: AppTheme.Layout.buttonHeightSmall)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.primaryAccent.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Grid of field cards
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: AppTheme.spacingMedium)],
                spacing: AppTheme.spacingMedium
            ) {
                ForEach(displayFields, id: \.rawValue) { field in
                    FieldSnapshotCard(
                        field: field,
                        brief: project.brief,
                        onEdit: { onEditField?(field) }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private var filledCount: Int {
        guard let brief = project.brief else { return 0 }
        let snapshot = brief.toSnapshot()
        return displayFields.filter { $0.isFilled(in: snapshot) }.count
    }
}

// MARK: - FieldSnapshotCard

private struct FieldSnapshotCard: View {
    let field: BriefField
    let brief: DesignBrief?
    let onEdit: () -> Void

    // MARK: - Derived data

    private var fieldValue: String? {
        guard let brief else { return nil }
        let snapshot = brief.toSnapshot()
        switch field {
        case .targetUser:    return snapshot.targetUser
        case .painPoint:     return snapshot.painPoint
        case .useScenario:   return snapshot.useScenario
        case .coreValue:     return snapshot.coreValue
        case .differentiation: return snapshot.differentiation
        case .boundaryItems:
            return snapshot.boundaryItems.isEmpty ? nil
                : "\(snapshot.boundaryItems.count) items defined"
        case .mvpFeatures:   return snapshot.mvpFeatures
        case .technicalModules: return snapshot.technicalModules
        case .interactionFlow: return snapshot.interactionFlow
        case .operationLogic: return snapshot.operationLogic
        case .hardConstraints: return snapshot.hardConstraints
        case .successMetrics:
            return snapshot.successMetrics.isEmpty ? nil
                : "\(snapshot.successMetrics.count) metrics defined"
        case .risks:
            return snapshot.risks.isEmpty ? nil
                : "\(snapshot.risks.count) risks identified"
        case .milestones:    return snapshot.milestones
        }
    }

    private var isFilled: Bool {
        fieldValue?.isEmpty == false
    }

    private var fieldIcon: String {
        switch field {
        case .targetUser:    return "person.fill"
        case .painPoint:     return "exclamationmark.bubble.fill"
        case .useScenario:   return "location.fill"
        case .coreValue:     return "sparkles"
        case .differentiation: return "arrow.up.forward"
        case .boundaryItems: return "rectangle.dashed"
        case .mvpFeatures:   return "square.stack.3d.up.fill"
        case .technicalModules: return "gearshape.2.fill"
        case .interactionFlow: return "flowchart.fill"
        case .operationLogic: return "slider.horizontal.3"
        case .hardConstraints: return "lock.shield.fill"
        case .successMetrics: return "checklist"
        case .risks:         return "exclamationmark.triangle.fill"
        case .milestones:    return "calendar"
        }
    }

    private var statusBadge: (status: CoDesignStatusBadge.Status, text: String) {
        if isFilled { return (.info, "已提取") }
        return (.locked, "未定义")
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {

            // Top row: icon + title + edit
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                Image(systemName: fieldIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryAccent)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primaryAccent.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(field.displayName)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer(minLength: AppTheme.spacingXS)

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            // Content
            if isFilled {
                Text(fieldValue ?? "")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not defined yet")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
                    .italic()
            }

            Spacer(minLength: 0)

            // Bottom: status badge
            HStack {
                Spacer()
                CoDesignStatusBadge(status: statusBadge.status, text: statusBadge.text)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.10), lineWidth: AppTheme.Border.thin)
        )
        .coDesignShadow(.card)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: AppTheme.spacingLarge) {

            // Partially filled
            StructuredProjectSnapshot(
                project: {
                    let p = Project(name: "校园导航助手", briefDescription: "帮助新生找到教室")
                    let brief = DesignBrief()
                    brief.targetUser = "大一新生，尤其是来自外地的学生"
                    brief.painPoint = "校园面积大、建筑命名混乱，新生经常找不到教室"
                    brief.coreValue = "智能路径规划，减少迷路焦虑"
                    p.brief = brief
                    return p
                }(),
                onEditField: { f in print("Edit \(f.displayName)") }
            )

            Divider()

            // Fully filled
            StructuredProjectSnapshot(
                project: {
                    let p = Project(name: "完整项目", briefDescription: "")
                    let brief = DesignBrief()
                    brief.targetUser = "一线城市的年轻白领，25-35 岁"
                    brief.painPoint = "工作日午餐选择困难，外卖平台信息过载"
                    brief.coreValue = "基于营养偏好的智能推荐，3 次点击下单"
                    brief.mvpFeatures = "AI 推荐引擎、一键复购、营养追踪"
                    brief.boundaryItems = [
                        BoundaryItem(content: "外卖配送", isIncluded: true),
                        BoundaryItem(content: "堂食预订", isIncluded: false),
                        BoundaryItem(content: "菜谱分享", isIncluded: false),
                    ]
                    p.brief = brief
                    return p
                }()
            )

            Divider()

            // Empty brief
            StructuredProjectSnapshot(
                project: Project(name: "新项目", briefDescription: "")
            )
        }
        .padding()
    }
    .background(Color.appBackground)
}
