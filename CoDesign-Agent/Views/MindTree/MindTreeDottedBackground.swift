import SwiftUI

/// A subtle, interaction-free canvas texture shared by every mind-tree presentation.
struct MindTreeDottedBackground: View {
    private enum Metrics {
        static let spacing: CGFloat = 18
        static let dotDiameter: CGFloat = 2.2
    }

    var body: some View {
        LinearGradient(
            colors: [
                Color.panelBackground,
                Color.appBackground,
                Color.softAccentBackground.opacity(0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Canvas(
                opaque: false,
                colorMode: .nonLinear,
                rendersAsynchronously: true
            ) { context, size in
                var dots = Path()
                let radius = Metrics.dotDiameter / 2
                var y = Metrics.spacing / 2

                while y < size.height {
                    var x = Metrics.spacing / 2

                    while x < size.width {
                        dots.addEllipse(
                            in: CGRect(
                                x: x - radius,
                                y: y - radius,
                                width: Metrics.dotDiameter,
                                height: Metrics.dotDiameter
                            )
                        )
                        x += Metrics.spacing
                    }

                    y += Metrics.spacing
                }

                context.fill(
                    dots,
                    with: .color(Color.textTertiary.opacity(0.22))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
