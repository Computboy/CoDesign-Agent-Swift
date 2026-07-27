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

enum MindTreeAnnotationInputPolicy {
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

    func makeCoordinator() -> Coordinator {
        Coordinator(
            controller: controller,
            onDebouncedDrawingChange: onDebouncedDrawingChange
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

        context.coordinator.attach(canvasView)
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
        canvasView.drawingPolicy = inputPolicy.pencilKitPolicy
        canvasView.isUserInteractionEnabled = isInteractionEnabled
        canvasView.contentSize = canvasView.bounds.size

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
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        fileprivate var onDebouncedDrawingChange: (Data) -> Void
        fileprivate var loadedDrawingIdentity: UUID?

        private let controller: MindTreeAnnotationCanvasController
        private weak var canvasView: PKCanvasView?
        private var toolPicker: PKToolPicker?
        private var debounceWorkItem: DispatchWorkItem?
        private var pendingDrawingData: Data?
        private var isLoadingDrawing = false
        private let debounceInterval: TimeInterval = 0.4

        init(
            controller: MindTreeAnnotationCanvasController,
            onDebouncedDrawingChange: @escaping (Data) -> Void
        ) {
            self.controller = controller
            self.onDebouncedDrawingChange = onDebouncedDrawingChange
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
#endif
