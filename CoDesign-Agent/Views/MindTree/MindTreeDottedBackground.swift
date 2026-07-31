import SwiftUI

enum MindTreeDottedBackgroundMetrics {
    static let baseSpacing: CGFloat = 18
    static let baseDotDiameter: CGFloat = 3.2
    static let dotOpacity: Double = 0.34
    static let minimumScale: CGFloat = 0.20

    static func effectiveScale(_ scale: CGFloat) -> CGFloat {
        max(scale, minimumScale)
    }

    static func spacing(for scale: CGFloat) -> CGFloat {
        baseSpacing * effectiveScale(scale)
    }

    static func dotDiameter(for scale: CGFloat) -> CGFloat {
        baseDotDiameter * effectiveScale(scale)
    }

    static func phase(for offset: CGSize, scale: CGFloat) -> CGPoint {
        let spacing = spacing(for: scale)
        return CGPoint(
            x: offset.width.truncatingRemainder(dividingBy: spacing),
            y: offset.height.truncatingRemainder(dividingBy: spacing)
        )
    }
}

/// A subtle, interaction-free canvas texture shared by every mind-tree presentation.
struct MindTreeDottedBackground: View {
    let scale: CGFloat
    let offset: CGSize

    init(scale: CGFloat = 1, offset: CGSize = .zero) {
        self.scale = scale
        self.offset = offset
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
                let spacing = MindTreeDottedBackgroundMetrics.spacing(for: scale)
                let dotDiameter = MindTreeDottedBackgroundMetrics.dotDiameter(for: scale)
                let phase = MindTreeDottedBackgroundMetrics.phase(
                    for: offset,
                    scale: scale
                )
                var dots = Path()
                let radius = dotDiameter / 2
                var y = phase.y - spacing

                while y <= size.height + spacing {
                    var x = phase.x - spacing

                    while x <= size.width + spacing {
                        dots.addEllipse(
                            in: CGRect(
                                x: x - radius,
                                y: y - radius,
                                width: dotDiameter,
                                height: dotDiameter
                            )
                        )
                        x += spacing
                    }

                    y += spacing
                }

                context.fill(
                    dots,
                    with: .color(Color.textSecondary.opacity(
                        MindTreeDottedBackgroundMetrics.dotOpacity
                    ))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
