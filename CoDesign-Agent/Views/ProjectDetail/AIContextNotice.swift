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
                        .fill(Color.secondaryAccent.opacity(0.12))
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
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primaryAccent.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.softAccentBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primaryAccent.opacity(0.16), lineWidth: AppTheme.Border.thin)
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
