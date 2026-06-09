import SwiftUI

// MARK: - AIContextNotice

struct AIContextNotice: View {
    let onUndo: () -> Void

    init(onUndo: @escaping () -> Void = {}) {
        self.onUndo = onUndo
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingSmall) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.secondaryAccent)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.secondaryAccent.opacity(AppTheme.Opacity.medium))
                )

            Text("Based on your previous answers, I think your concept is clear enough to discuss MVP boundaries next.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: AppTheme.spacingSmall)

            Button {
                onUndo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .labelStyle(.titleAndIcon)
                    .font(AppTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(Color.primaryAccent)
                    .padding(.horizontal, AppTheme.spacingSmall)
                    .frame(height: 30)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primaryAccent.opacity(AppTheme.Opacity.light))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Layout.cardPadding)
        .padding(.vertical, AppTheme.spacingSmall)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(Color.softAccentBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(AppTheme.Opacity.noticeable), lineWidth: AppTheme.Border.thin)
        )
    }
}

#Preview {
    AIContextNotice {
        print("Undo context notice")
    }
    .padding()
    .background(Color.appBackground)
}
