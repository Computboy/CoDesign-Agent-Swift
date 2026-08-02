#if os(iOS) && canImport(PencilKit)
import Combine
import PencilKit
import SwiftUI
import UIKit

private final class MindTreeResizingCanvasView: PKCanvasView {
    private var lastLaidOutSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastLaidOutSize else { return }
        lastLaidOutSize = bounds.size
        contentSize = bounds.size
        setNeedsDisplay()
    }
}

enum MindTreeAnnotationInputPolicy: Equatable {
    case anyInput
    case pencilOnly

    fileprivate var pencilKitPolicy: PKCanvasViewDrawingPolicy {
        switch self {
        case .anyInput:
            return .anyInput
        case .pencilOnly:
            return .pencilOnly
        }
    }

    fileprivate var enablesFingerNavigation: Bool {
        self == .pencilOnly
    }
}

@MainActor
final class MindTreeAnnotationCanvasController: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var isEmpty = true

    private weak var canvasView: PKCanvasView?
    private var flushAction: (() -> Void)?
    private var drawingChangedAction: (() -> Void)?
    private var toolPickerVisibilityAction: ((Bool) -> Void)?

    var currentDrawingData: Data {
        canvasView?.drawing.dataRepresentation() ?? Data()
    }

    func undo() {
        canvasView?.undoManager?.undo()
        drawingChangedAction?()
    }

    func redo() {
        canvasView?.undoManager?.redo()
        drawingChangedAction?()
    }

    func clear() {
        guard let canvasView else { return }
        canvasView.drawing = PKDrawing()
        drawingChangedAction?()
    }

    func showToolPicker() {
        toolPickerVisibilityAction?(true)
    }

    func flushPendingChanges() {
        flushAction?()
    }

    fileprivate func attach(
        canvasView: PKCanvasView,
        flushAction: @escaping () -> Void,
        drawingChangedAction: @escaping () -> Void,
        toolPickerVisibilityAction: @escaping (Bool) -> Void
    ) {
        self.canvasView = canvasView
        self.flushAction = flushAction
        self.drawingChangedAction = drawingChangedAction
        self.toolPickerVisibilityAction = toolPickerVisibilityAction
        refreshCommandState()
    }

    fileprivate func refreshCommandState() {
        canUndo = canvasView?.undoManager?.canUndo ?? false
        canRedo = canvasView?.undoManager?.canRedo ?? false
        isEmpty = canvasView?.drawing.strokes.isEmpty ?? true
    }
}

struct MindTreeAnnotationCanvas: UIViewRepresentable {
    let drawingData: Data
    let drawingIdentity: UUID?
    let isInteractionEnabled: Bool
    let showsToolPicker: Bool
    var inputPolicy: MindTreeAnnotationInputPolicy = .anyInput
    let controller: MindTreeAnnotationCanvasController
    let onDebouncedDrawingChange: (Data) -> Void
    let onFingerPanChanged: (CGSize) -> Void
    let onFingerPanEnded: (CGSize) -> Void
    let onFingerMagnificationChanged: (CGFloat) -> Void
    let onFingerMagnificationEnded: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            controller: controller,
            onDebouncedDrawingChange: onDebouncedDrawingChange,
            onFingerPanChanged: onFingerPanChanged,
            onFingerPanEnded: onFingerPanEnded,
            onFingerMagnificationChanged: onFingerMagnificationChanged,
            onFingerMagnificationEnded: onFingerMagnificationEnded
        )
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = MindTreeResizingCanvasView(frame: .zero)
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.alwaysBounceVertical = false
        canvasView.bounces = false
        canvasView.contentInset = .zero
        canvasView.drawingPolicy = inputPolicy.pencilKitPolicy
        canvasView.isUserInteractionEnabled = isInteractionEnabled
        canvasView.tool = PKInkingTool(.pen, color: .systemBlue, width: 5)
        canvasView.accessibilityLabel = "思维树批注画布"
        canvasView.accessibilityHint = "使用 Apple Pencil 书写；单指移动，双指缩放"

        context.coordinator.attach(canvasView)
        context.coordinator.updateFingerNavigation(
            enabled: inputPolicy.enablesFingerNavigation,
            on: canvasView
        )
        context.coordinator.loadDrawing(
            data: drawingData,
            identity: drawingIdentity,
            into: canvasView
        )
        context.coordinator.updateToolPicker(
            visible: showsToolPicker && isInteractionEnabled,
            for: canvasView
        )
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.onDebouncedDrawingChange = onDebouncedDrawingChange
        context.coordinator.onFingerPanChanged = onFingerPanChanged
        context.coordinator.onFingerPanEnded = onFingerPanEnded
        context.coordinator.onFingerMagnificationChanged = onFingerMagnificationChanged
        context.coordinator.onFingerMagnificationEnded = onFingerMagnificationEnded
        canvasView.drawingPolicy = inputPolicy.pencilKitPolicy
        canvasView.isUserInteractionEnabled = isInteractionEnabled
        canvasView.contentSize = canvasView.bounds.size
        context.coordinator.updateFingerNavigation(
            enabled: inputPolicy.enablesFingerNavigation,
            on: canvasView
        )

        if context.coordinator.loadedDrawingIdentity != drawingIdentity {
            context.coordinator.loadDrawing(
                data: drawingData,
                identity: drawingIdentity,
                into: canvasView
            )
        }

        context.coordinator.updateToolPicker(
            visible: showsToolPicker && isInteractionEnabled,
            for: canvasView
        )
    }

    static func dismantleUIView(_ canvasView: PKCanvasView, coordinator: Coordinator) {
        coordinator.flushPendingChanges()
        coordinator.hideToolPicker(for: canvasView)
        canvasView.delegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        fileprivate var onDebouncedDrawingChange: (Data) -> Void
        fileprivate var onFingerPanChanged: (CGSize) -> Void
        fileprivate var onFingerPanEnded: (CGSize) -> Void
        fileprivate var onFingerMagnificationChanged: (CGFloat) -> Void
        fileprivate var onFingerMagnificationEnded: (CGFloat) -> Void
        fileprivate var loadedDrawingIdentity: UUID?

        private let controller: MindTreeAnnotationCanvasController
        private weak var canvasView: PKCanvasView?
        private var toolPicker: PKToolPicker?
        private var debounceWorkItem: DispatchWorkItem?
        private var pendingDrawingData: Data?
        private var fingerPanGesture: UIPanGestureRecognizer?
        private var fingerPinchGesture: UIPinchGestureRecognizer?
        private var isLoadingDrawing = false
        private let debounceInterval: TimeInterval = 0.4

        init(
            controller: MindTreeAnnotationCanvasController,
            onDebouncedDrawingChange: @escaping (Data) -> Void,
            onFingerPanChanged: @escaping (CGSize) -> Void,
            onFingerPanEnded: @escaping (CGSize) -> Void,
            onFingerMagnificationChanged: @escaping (CGFloat) -> Void,
            onFingerMagnificationEnded: @escaping (CGFloat) -> Void
        ) {
            self.controller = controller
            self.onDebouncedDrawingChange = onDebouncedDrawingChange
            self.onFingerPanChanged = onFingerPanChanged
            self.onFingerPanEnded = onFingerPanEnded
            self.onFingerMagnificationChanged = onFingerMagnificationChanged
            self.onFingerMagnificationEnded = onFingerMagnificationEnded
        }

        func attach(_ canvasView: PKCanvasView) {
            self.canvasView = canvasView
            controller.attach(
                canvasView: canvasView,
                flushAction: { [weak self] in
                    self?.flushPendingChanges()
                },
                drawingChangedAction: { [weak self] in
                    self?.captureDrawingChange()
                },
                toolPickerVisibilityAction: { [weak self, weak canvasView] visible in
                    guard let self, let canvasView else { return }
                    self.updateToolPicker(visible: visible, for: canvasView)
                }
            )
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isLoadingDrawing else { return }
            captureDrawingChange()
        }

        fileprivate func updateFingerNavigation(
            enabled: Bool,
            on canvasView: PKCanvasView
        ) {
            if fingerPanGesture == nil {
                let pan = UIPanGestureRecognizer(
                    target: self,
                    action: #selector(handleFingerPan(_:))
                )
                pan.minimumNumberOfTouches = 1
                pan.maximumNumberOfTouches = 1
                pan.allowedTouchTypes = [
                    NSNumber(value: UITouch.TouchType.direct.rawValue)
                ]
                pan.cancelsTouchesInView = false
                pan.delegate = self
                canvasView.addGestureRecognizer(pan)
                fingerPanGesture = pan
            }

            if fingerPinchGesture == nil {
                let pinch = UIPinchGestureRecognizer(
                    target: self,
                    action: #selector(handleFingerPinch(_:))
                )
                pinch.allowedTouchTypes = [
                    NSNumber(value: UITouch.TouchType.direct.rawValue)
                ]
                pinch.cancelsTouchesInView = false
                pinch.delegate = self
                canvasView.addGestureRecognizer(pinch)
                fingerPinchGesture = pinch
            }

            fingerPanGesture?.isEnabled = enabled
            fingerPinchGesture?.isEnabled = enabled
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            gestureRecognizer === fingerPanGesture
                || gestureRecognizer === fingerPinchGesture
        }

        @objc
        private func handleFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard let canvasView else { return }
            let point = gesture.translation(in: canvasView)
            let translation = CGSize(width: point.x, height: point.y)

            switch gesture.state {
            case .began, .changed:
                onFingerPanChanged(translation)
            case .ended, .cancelled, .failed:
                onFingerPanEnded(translation)
            default:
                break
            }
        }

        @objc
        private func handleFingerPinch(_ gesture: UIPinchGestureRecognizer) {
            let magnification = CGFloat(gesture.scale)

            switch gesture.state {
            case .began, .changed:
                onFingerMagnificationChanged(magnification)
            case .ended, .cancelled, .failed:
                onFingerMagnificationEnded(magnification)
            default:
                break
            }
        }

        fileprivate func loadDrawing(
            data: Data,
            identity: UUID?,
            into canvasView: PKCanvasView
        ) {
            debounceWorkItem?.cancel()
            debounceWorkItem = nil
            pendingDrawingData = nil

            isLoadingDrawing = true
            if data.isEmpty {
                canvasView.drawing = PKDrawing()
            } else if let drawing = try? PKDrawing(data: data) {
                canvasView.drawing = drawing
            } else {
                canvasView.drawing = PKDrawing()
            }
            isLoadingDrawing = false

            loadedDrawingIdentity = identity
            canvasView.setNeedsLayout()
            canvasView.setNeedsDisplay()
            DispatchQueue.main.async { [weak canvasView] in
                canvasView?.setNeedsDisplay()
            }
            controller.refreshCommandState()
        }

        fileprivate func updateToolPicker(visible: Bool, for canvasView: PKCanvasView) {
            if toolPicker == nil {
                let picker = PKToolPicker()
                picker.addObserver(canvasView)
                toolPicker = picker
            }

            guard canvasView.window != nil else {
                if visible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak canvasView] in
                        guard let self,
                              let canvasView,
                              canvasView.window != nil else {
                            return
                        }
                        self.updateToolPicker(visible: true, for: canvasView)
                    }
                }
                return
            }

            if visible {
                canvasView.becomeFirstResponder()
                toolPicker?.setVisible(true, forFirstResponder: canvasView)
            } else if canvasView.isFirstResponder {
                toolPicker?.setVisible(false, forFirstResponder: canvasView)
                canvasView.resignFirstResponder()
            } else {
                toolPicker?.setVisible(false, forFirstResponder: canvasView)
            }
        }

        fileprivate func hideToolPicker(for canvasView: PKCanvasView) {
            toolPicker?.setVisible(false, forFirstResponder: canvasView)
            toolPicker?.removeObserver(canvasView)
            if canvasView.isFirstResponder {
                canvasView.resignFirstResponder()
            }
        }

        fileprivate func flushPendingChanges() {
            debounceWorkItem?.cancel()
            debounceWorkItem = nil

            guard let data = pendingDrawingData ?? canvasView?.drawing.dataRepresentation() else {
                return
            }
            pendingDrawingData = nil
            onDebouncedDrawingChange(data)
            controller.refreshCommandState()
        }

        private func captureDrawingChange() {
            guard let canvasView else { return }
            let data = canvasView.drawing.dataRepresentation()
            pendingDrawingData = data
            controller.refreshCommandState()

            debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.flushPendingChanges()
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + debounceInterval,
                execute: workItem
            )
        }
    }
}

/// Read-only PencilKit renderer used while browsing the tree. The projected
/// drawing is rasterized only when its identity changes; resource-card drags
/// can then fade this entire layer without rebuilding any strokes.
struct MindTreeAnnotationInkOverlay: UIViewRepresentable {
    let groups: [MindTreeAnchoredInkGroup]
    let snapshot: MindTreeAnnotationLayoutSnapshot
    let drawingIdentity: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        context.coordinator.render(
            groups: groups,
            snapshot: snapshot,
            identity: drawingIdentity,
            in: view
        )
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.render(
            groups: groups,
            snapshot: snapshot,
            identity: drawingIdentity,
            in: view
        )
    }

    final class Coordinator {
        private var loadedDrawingIdentity: UUID?
        private var loadedGroupIDs: [UUID] = []

        func render(
            groups: [MindTreeAnchoredInkGroup],
            snapshot: MindTreeAnnotationLayoutSnapshot,
            identity: UUID,
            in container: UIView
        ) {
            let groupIDs = groups.map(\.id)
            guard loadedDrawingIdentity != identity
                    || loadedGroupIDs != groupIDs else {
                return
            }

            loadedDrawingIdentity = identity
            loadedGroupIDs = groupIDs
            container.subviews.forEach { $0.removeFromSuperview() }

            var drawing = PKDrawing()
            for group in groups where group.resolutionState != .hidden {
                guard let localDrawing = try? PKDrawing(data: group.drawingData) else {
                    continue
                }

                if let frame = snapshot.frame(for: group.anchor) {
                    drawing.append(
                        localDrawing.transformed(
                            using: CGAffineTransform(
                                translationX: frame.x,
                                y: frame.y
                            )
                        )
                    )
                } else if group.resolutionState == .unresolved {
                    let target = CGPoint(
                        x: clampedNormalized(group.fallbackNormalizedX)
                            * snapshot.contentWidth,
                        y: clampedNormalized(group.fallbackNormalizedY)
                            * snapshot.contentHeight
                    )
                    let localCenter = CGPoint(
                        x: localDrawing.bounds.midX,
                        y: localDrawing.bounds.midY
                    )
                    drawing.append(
                        localDrawing.transformed(
                            using: CGAffineTransform(
                                translationX: target.x - localCenter.x,
                                y: target.y - localCenter.y
                            )
                        )
                    )
                }
            }

            guard !drawing.strokes.isEmpty else { return }
            let imageBounds = drawing.bounds.insetBy(dx: -4, dy: -4)
            guard imageBounds.width > 0, imageBounds.height > 0 else { return }

            let imageView = UIImageView(
                image: drawing.image(
                    from: imageBounds,
                    scale: max(container.traitCollection.displayScale, 1)
                )
            )
            imageView.frame = imageBounds
            imageView.backgroundColor = .clear
            imageView.isOpaque = false
            imageView.isUserInteractionEnabled = false
            container.addSubview(imageView)
        }

        private func clampedNormalized(_ value: Double) -> Double {
            guard value.isFinite else { return 0.5 }
            return min(max(value, 0), 1)
        }
    }
}
#endif
