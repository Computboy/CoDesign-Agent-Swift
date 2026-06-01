import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

extension View {
    func coDesignHideScrollIndicators() -> some View {
        self
            .scrollIndicators(.hidden)
            .background(PlatformScrollIndicatorHider())
    }
}

#if canImport(UIKit)
private struct PlatformScrollIndicatorHider: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        ScrollIndicatorHiderView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? ScrollIndicatorHiderView)?.scheduleHide()
    }
}

private final class ScrollIndicatorHiderView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        scheduleHide()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        scheduleHide()
    }

    func scheduleHide() {
        DispatchQueue.main.async { [weak self] in
            self?.hideScrollIndicators()
        }
    }

    private func hideScrollIndicators() {
        guard let root = window ?? superview else { return }
        hideScrollIndicators(in: root)
    }

    private func hideScrollIndicators(in view: UIView) {
        if let scrollView = view as? UIScrollView {
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
        }

        view.subviews.forEach(hideScrollIndicators)
    }
}
#elseif canImport(AppKit)
private struct PlatformScrollIndicatorHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ScrollIndicatorHiderView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ScrollIndicatorHiderView)?.scheduleHide()
    }
}

private final class ScrollIndicatorHiderView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleHide()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleHide()
    }

    func scheduleHide() {
        DispatchQueue.main.async { [weak self] in
            self?.hideScrollIndicators()
        }
    }

    private func hideScrollIndicators() {
        guard let root = window?.contentView ?? superview else { return }
        hideScrollIndicators(in: root)
    }

    private func hideScrollIndicators(in view: NSView) {
        if let scrollView = view as? NSScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            scrollView.verticalScroller?.isHidden = true
            scrollView.horizontalScroller?.isHidden = true
        }

        view.subviews.forEach(hideScrollIndicators)
    }
}
#else
private struct PlatformScrollIndicatorHider: View {
    var body: some View {
        EmptyView()
    }
}
#endif
