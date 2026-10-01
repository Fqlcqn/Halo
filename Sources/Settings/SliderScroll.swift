import AppKit
import SwiftUI

/// A non-hit-testing local scroll region preserves Slider drag/keyboard access.
struct SliderScroll: NSViewRepresentable {
    var changed: (Int) -> Void
    func makeNSView(context: Context) -> SliderScrollView { SliderScrollView() }
    func updateNSView(_ view: SliderScrollView, context: Context) { view.changed = changed }
    static func dismantleNSView(_ view: SliderScrollView, coordinator: ()) { view.stop() }
}
final class SliderScrollView: NSView {
    var changed: ((Int) -> Void)?
    private var monitor: Any?
    private var detents = ScrollDetents()
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); stop()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self, let window = self.window, event.window === window,
                      !self.isHiddenOrHasHiddenAncestor,
                      self.bounds.contains(self.convert(event.locationInWindow, from: nil)) else { return false }
                let delta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) ? event.scrollingDeltaY : event.scrollingDeltaX
                let step = self.detents.step(delta: delta, precise: event.hasPreciseScrollingDeltas,
                                            momentum: !event.momentumPhase.isEmpty, time: event.timestamp)
                if step != 0 { self.changed?(step) }
                return true
            }
            return consumed ? nil : event
        }
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; detents = ScrollDetents()
    }
}
