#if os(iOS) && canImport(PencilKit)
import Foundation
import PencilKit
import UIKit

struct MindTreeAnnotationInkProjection {
    var drawingData: Data
    var groups: [MindTreeAnchoredInkGroup]
}

enum MindTreeAnnotationInkService {
    static func groups(
        from drawingData: Data,
        in snapshot: MindTreeAnnotationLayoutSnapshot,
        fingerprint: String,
        preservingIDsFrom existing: [MindTreeAnchoredInkGroup] = [],
        now: Date = Date()
    ) -> [MindTreeAnchoredInkGroup] {
        guard let drawing = try? PKDrawing(data: drawingData) else { return [] }

        return drawing.strokes.enumerated().compactMap { index, stroke in
            let bounds = stroke.renderBounds
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            guard let frame = MindTreeAnnotationProjectionService.nearestAnchor(
                to: center,
                in: snapshot
            ) else {
                return nil
            }

            let localDrawing = PKDrawing(strokes: [stroke]).transformed(
                using: CGAffineTransform(translationX: -frame.x, y: -frame.y)
            )
            let existingGroup = existing.indices.contains(index) ? existing[index] : nil
            return MindTreeAnchoredInkGroup(
                id: existingGroup?.id ?? UUID(),
                anchor: frame.anchor,
                drawingData: localDrawing.dataRepresentation(),
                sourceAnchorX: frame.x,
                sourceAnchorY: frame.y,
                sourceAnchorWidth: frame.width,
                sourceAnchorHeight: frame.height,
                fallbackNormalizedX: normalized(center.x, dimension: snapshot.contentWidth),
                fallbackNormalizedY: normalized(center.y, dimension: snapshot.contentHeight),
                createdAt: existingGroup?.createdAt ?? now,
                updatedAt: now,
                createdAgainstFingerprint: existingGroup?.createdAgainstFingerprint ?? fingerprint
            )
        }
    }

    static func migrateLegacyDrawing(
        _ drawingData: Data,
        sourceWidth: Double,
        sourceHeight: Double,
        to snapshot: MindTreeAnnotationLayoutSnapshot,
        fingerprint: String,
        now: Date = Date()
    ) -> [MindTreeAnchoredInkGroup] {
        guard var drawing = try? PKDrawing(data: drawingData) else { return [] }

        let widthScale = safeScale(from: sourceWidth, to: snapshot.contentWidth)
        let heightScale = safeScale(from: sourceHeight, to: snapshot.contentHeight)
        drawing.transform(
            using: CGAffineTransform(scaleX: widthScale, y: heightScale)
        )
        return groups(
            from: drawing.dataRepresentation(),
            in: snapshot,
            fingerprint: fingerprint,
            now: now
        )
    }

    static func project(
        _ groups: [MindTreeAnchoredInkGroup],
        into snapshot: MindTreeAnnotationLayoutSnapshot,
        knownAnchors: Set<MindTreeAnnotationAnchor>
    ) -> MindTreeAnnotationInkProjection {
        var result = PKDrawing()
        var updatedGroups: [MindTreeAnchoredInkGroup] = []

        for var group in groups {
            guard let localDrawing = try? PKDrawing(data: group.drawingData) else {
                group.resolutionState = .unresolved
                updatedGroups.append(group)
                continue
            }

            if let frame = snapshot.frame(for: group.anchor) {
                group.resolutionState = .resolved
                result.append(
                    localDrawing.transformed(
                        using: CGAffineTransform(translationX: frame.x, y: frame.y)
                    )
                )
            } else if knownAnchors.contains(group.anchor) {
                group.resolutionState = .hidden
            } else {
                group.resolutionState = .unresolved
                let target = CGPoint(
                    x: clampedNormalized(group.fallbackNormalizedX) * snapshot.contentWidth,
                    y: clampedNormalized(group.fallbackNormalizedY) * snapshot.contentHeight
                )
                let localCenter = CGPoint(
                    x: localDrawing.bounds.midX,
                    y: localDrawing.bounds.midY
                )
                result.append(
                    localDrawing.transformed(
                        using: CGAffineTransform(
                            translationX: target.x - localCenter.x,
                            y: target.y - localCenter.y
                        )
                    )
                )
            }
            updatedGroups.append(group)
        }

        return MindTreeAnnotationInkProjection(
            drawingData: result.dataRepresentation(),
            groups: updatedGroups
        )
    }

    private static func safeScale(from source: Double, to destination: Double) -> Double {
        guard source > 0, destination > 0 else { return 1 }
        return destination / source
    }

    private static func normalized(_ value: Double, dimension: Double) -> Double {
        guard dimension > 0, value.isFinite else { return 0.5 }
        return clampedNormalized(value / dimension)
    }

    private static func clampedNormalized(_ value: Double) -> Double {
        guard value.isFinite else { return 0.5 }
        return min(max(value, 0), 1)
    }
}
#endif
