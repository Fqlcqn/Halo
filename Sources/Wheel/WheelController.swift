import AppKit
import SwiftUI

final class WheelPanel: NSPanel {
    var handleKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) { _ = handleKey?(event) }
    override func keyUp(with event: NSEvent) { _ = handleKey?(event) }
}

@MainActor final class WheelController {
    let state = WheelState()
    private(set) var panel: NSPanel?
    private var generation = 0
    private var tracking: Timer?
    private var canCommit = false
    var haptics = true
    var safeMode = false
    var dynamicIconMovement = false
    private var lastMouse: CGPoint?
    var onAccessibilitySelect: ((Int) -> Void)?
    var onKeyEvent: ((NSEvent) -> Bool)?

    func show(items: [WheelItem], geometry: WheelGeometry, center: CGPoint? = nil, trackMouse: Bool = true, instant: Bool = false) {
        generation += 1
        let ticket = generation
        tracking?.invalidate(); tracking = nil
        canCommit = true
        lastMouse = nil
        var reset = Transaction(); reset.disablesAnimations = true
        withTransaction(reset) {
            state.instantTransitions = instant
            state.revealed = false; state.selected = nil
            state.selectionHasOrigin = false
            state.selectionAngle = geometry.startAngle
            state.geometry = geometry; state.items = items
            state.motion.lift = dynamicIconMovement ? 0 : 8
        }
        let origin = center ?? NSEvent.mouseLocation
        let frame = NSRect(x: origin.x - geometry.panelSize/2, y: origin.y - geometry.panelSize/2, width: geometry.panelSize, height: geometry.panelSize)
        if panel == nil {
            let window = WheelPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.becomesKeyOnlyIfNeeded = false
            window.handleKey = { [weak self] in self?.onKeyEvent?($0) ?? false }
            window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
            window.level = .statusBar
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false; window.acceptsMouseMovedEvents = true
            window.animationBehavior = .none // SwiftUI owns motion; no competing window animation.
            window.appearance = NSAppearance(named: .darkAqua)
            let host = NSHostingView(rootView: WheelView(state: state, activate: { [weak self] index in self?.onAccessibilitySelect?(index) }))
            host.sizingOptions = []
            host.frame = NSRect(origin: .zero, size: frame.size)
            host.autoresizingMask = [.width, .height]
            window.contentView = host
            panel = window
        }
        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()
        if trackMouse { panel?.makeKey() }
        // Make the wheel interactive immediately. The first hover should not
        // wait for a deferred SwiftUI state update or the first timer tick.
        if instant { withTransaction(reset) { state.revealed = true } }
        else { state.revealed = true }
        if trackMouse { updateSelection() }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == ticket else { return }
            // Pick up a pointer move that occurred between orderFront and the
            // first timer tick without changing the animation timing.
            if trackMouse { self.updateSelection() }
        }
        if trackMouse {
            let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateSelection() }
            }
            tracking = timer; RunLoop.main.add(timer, forMode: .common)
        }
    }

    func updateSelection() {
        guard let panel, panel.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        guard mouse != lastMouse else { return }
        lastMouse = mouse
        let dx = mouse.x-panel.frame.midX, dy = mouse.y-panel.frame.midY
        let index = state.geometry.selectedIndex(dx: dx, dy: dy, count: state.items.count)
        let lift = state.geometry.iconLift(distance: hypot(dx, dy), dynamic: dynamicIconMovement)
        if abs(state.motion.lift - lift) > 0.001 { state.motion.lift = lift }
        select(index)
    }

    func select(_ index: Int?) {
        guard index != state.selected else { return }
        if let index, state.items.indices.contains(index) {
            let target = state.geometry.angle(index: index, count: state.items.count)
            state.selectionHasOrigin = state.selected != nil
            state.selectionAngle += WheelGeometry.shortestDelta(from: state.selectionAngle, to: target)
            if haptics && !safeMode {
                NSHapticFeedbackManager.defaultPerformer.perform(state.geometry.startAngle > 0 ? .alignment : .levelChange, performanceTime: .default)
            }
            state.selected = index
        } else { state.selected = nil }
    }

    func takeSelection() -> WheelItem? {
        guard canCommit, let index = state.selected, state.items.indices.contains(index) else { return nil }
        canCommit = false
        return state.items[index]
    }

    func replaceItems(_ items: [WheelItem]) {
        guard items.map(\.id) != state.items.map(\.id) else { return }
        let selectedID = state.selected.flatMap { state.items.indices.contains($0) ? state.items[$0].id : nil }
        let next = selectedID.flatMap { id in items.firstIndex { $0.id == id } }
        withAnimation(state.instantTransitions ? nil : .easeOut(duration: 0.12)) {
            state.items = items; state.selected = next
            if let next { state.selectionAngle += WheelGeometry.shortestDelta(from: state.selectionAngle, to: state.geometry.angle(index: next, count: items.count)) }
        }
        lastMouse = nil
    }

    func hide(immediately: Bool = false) {
        generation += 1
        let ticket = generation
        canCommit = false
        tracking?.invalidate(); tracking = nil
        if immediately || state.instantTransitions {
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { state.revealed = false; state.selected = nil }
            panel?.orderOut(nil); return
        }
        state.revealed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            guard let self, self.generation == ticket else { return }
            self.panel?.orderOut(nil); self.state.selected = nil
        }
    }

    func capture(to url: URL) throws {
        guard let view = panel?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileWriteUnknown) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
    }

    /// Visual-QA fixture: put the user's recorded desktop behind the real renderer.
    /// No screenshot permissions or interaction with other applications are required.
    func showFixture(background: NSImage, centerPixels: CGPoint) {
        guard let panel else { return }
        let size = NSSize(width: background.size.width / 2, height: background.size.height / 2)
        let wheel = WheelView(state: state)
        let view = NSHostingView(rootView: ZStack(alignment: .topLeading) {
            Image(nsImage: background).resizable().frame(width: size.width, height: size.height)
            wheel.position(x: centerPixels.x / 2, y: centerPixels.y / 2)
        }.frame(width: size.width, height: size.height).environment(\.colorScheme, .dark))
        view.sizingOptions = []
        view.frame = NSRect(origin: .zero, size: size)
        panel.contentView = view
        panel.setContentSize(size)
        panel.center()
        panel.title = "Halo Visual Comparison"
    }
}

@MainActor final class WheelCoordinator: NSObject, HaloWheelDriver {
    let launcher = WheelController(), quitter = WheelController()
    let catalog = ApplicationCatalog()
    let store: PreferenceStore
    let actions: ActionService
    private func transitionIsInstant() -> Bool {
        let instant = store.value.lessAnimation
        launcher.state.instantTransitions = instant; quitter.state.instantTransitions = instant
        return instant
    }
    init(store: PreferenceStore, safeMode: Bool) {
        self.store = store; self.actions = ActionService(safeMode: safeMode)
        self.actions.forceQuitApps = { [weak store] in store?.value.forceQuitApps ?? true }
        super.init()
        launcher.safeMode = safeMode; quitter.safeMode = safeMode
        actions.quitStateChanged = { [weak self] in self?.refreshQuitter() }
        catalog.runningAppsChanged = { [weak self] in self?.refreshQuitter() }
    }
    private func refreshQuitter() {
        guard quitter.state.revealed else { return }
        quitter.replaceItems(catalog.quitter(showsTrash: store.value.showsTrash, excluding: actions.pendingQuitIDs))
    }
    func controller(_ wheel: HaloWheel) -> WheelController { wheel == .launcher ? launcher : quitter }
    func showWheel(_ wheel: HaloWheel) {
        let instant = transitionIsInstant()
        let isQuitter = wheel == .quitter
        controller(isQuitter ? .launcher : .quitter).hide(immediately: true)
        let preferences = store.value
        let c = controller(wheel)
        c.state.glassFinish = preferences.glassFinish
        c.state.glassAmount = preferences.glassAmount
        c.state.selectionTint = preferences.selectionTint
        c.state.highlightsTrash = preferences.highlightsTrash
        c.haptics = preferences.haptics
        c.dynamicIconMovement = preferences.dynamicIconMovement
        c.show(items: isQuitter ? catalog.quitter(showsTrash: preferences.showsTrash, excluding: actions.pendingQuitIDs) : catalog.launcher(targets: preferences.launcherTargets), geometry: WheelGeometry(diameter: isQuitter ? preferences.quitterDiameter : preferences.launcherDiameter, selectionDistance: preferences.selectionDistance, maximumSelectionDistance: preferences.maximumSelectionDistance, quitter: isQuitter, trashPosition: preferences.trashPosition, thickness: preferences.wheelThickness), instant: instant)
    }
    func hideWheel(_ wheel: HaloWheel) {
        let c = controller(wheel)
        if c.state.revealed { _ = transitionIsInstant() }
        c.hide()
    }
    func commitWheel(_ wheel: HaloWheel) {
        let c = controller(wheel)
        if c.state.revealed { _ = transitionIsInstant() }
        c.updateSelection()
        let item = c.takeSelection()
        c.hide()
        guard let item else { return }
        actions.prepare(item)
        if store.value.haptics && !actions.safeMode { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
        // Close first; application work never holds up release-to-select feedback.
        DispatchQueue.main.async { [weak self] in self?.actions.perform(item) }
    }
    func frame(for wheel: HaloWheel) -> NSRect { controller(wheel).panel?.frame ?? .zero }
    func stop() { launcher.hide(); quitter.hide(); catalog.stop() }
}
