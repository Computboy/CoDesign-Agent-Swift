import SwiftUI

enum MindTreeAnnotationCoordinateSpace {
    static let graph = "mindTree.annotation.graph"
}

enum MindTreeTextAnnotationGeometry {
    static func translatedCenter(
        from origin: CGPoint,
        by translation: CGSize
    ) -> CGPoint {
        CGPoint(
            x: origin.x + translation.width,
            y: origin.y + translation.height
        )
    }
}

struct MindTreeTextAnnotationBox: View {
    let item: MindTreeTextAnnotationItem
    let isEditable: Bool
    let onEdit: () -> Void
    let onMove: (CGPoint) -> Void
    let onMoveEnded: (CGPoint) -> Void

    @State private var dragOrigin: CGPoint?

    var body: some View {
        Text(item.text)
            .font(AppTheme.Typography.body)
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(
                width: CGFloat(item.width),
                height: CGFloat(item.height),
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .fill(Color.cardBackground.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(
                        Color.primaryAccent.opacity(isEditable ? 0.72 : 0.30),
                        lineWidth: isEditable ? 1.5 : 1
                    )
            )
            .coDesignShadow(.card)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEditable else { return }
                onEdit()
            }
            .gesture(
                DragGesture(
                    minimumDistance: 6,
                    coordinateSpace: .named(MindTreeAnnotationCoordinateSpace.graph)
                )
                    .onChanged { value in
                        guard isEditable else { return }
                        if dragOrigin == nil {
                            dragOrigin = CGPoint(x: item.x, y: item.y)
                        }
                        guard let dragOrigin else { return }
                        onMove(
                            MindTreeTextAnnotationGeometry.translatedCenter(
                                from: dragOrigin,
                                by: value.translation
                            )
                        )
                    }
                    .onEnded { value in
                        guard isEditable, let dragOrigin else { return }
                        let destination = MindTreeTextAnnotationGeometry.translatedCenter(
                            from: dragOrigin,
                            by: value.translation
                        )
                        self.dragOrigin = nil
                        onMoveEnded(destination)
                    },
                including: isEditable ? .all : .none
            )
            .accessibilityLabel("文本批注：\(item.text)")
            .accessibilityHint(isEditable ? "轻点编辑，拖动移动" : "")
    }
}

struct MindTreeTextAnnotationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFocused: Bool

    @State private var text: String

    let allowsDelete: Bool
    let onSave: (String) -> Void
    let onDelete: () -> Void

    init(
        initialText: String,
        allowsDelete: Bool,
        onSave: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        _text = State(initialValue: initialText)
        self.allowsDelete = allowsDelete
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                Text("输入要放在思维树上的文字。保存后可轻点再次编辑，或直接拖动文本框。")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.textSecondary)

                TextEditor(text: $text)
                    .font(AppTheme.Typography.body)
                    .focused($isTextFocused)
                    .padding(10)
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                            .fill(Color.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                            .strokeBorder(AppTheme.Border.color, lineWidth: AppTheme.Border.thin)
                    )

                if allowsDelete {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("删除文本框", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 0)
            }
            .padding(AppTheme.spacingLarge)
            .background(Color.appBackground)
            .navigationTitle(allowsDelete ? "编辑文本框" : "新建文本框")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(trimmedText)
                        dismiss()
                    }
                    .disabled(trimmedText.isEmpty)
                }
            }
            .onAppear {
                isTextFocused = true
            }
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
