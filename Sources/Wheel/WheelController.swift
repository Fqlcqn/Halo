import AppKit
import SwiftUI

enum WheelPresentation {
    static let revealDuration = 0.105
    static let hideDuration = 0.04
}

final class WheelPanel: NSPanel {
    var handleKey: ((NSEvent) -> Bool)?
    var requiresKeyboardFocus = true
    override var canBecomeKey: Bool { requiresKeyboardFocus }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) { _ = handleKey?(event) }
    override func keyUp(with event: NSEvent) { _ = handleKey?(event) }
}

@MainActor final class WheelController {
    let state = WheelState()
    private(set) var panel: NSPanel?
    private var generation = 0
    private var tracking: Timer?
    private var localPointerMonitor: Any?
    private var globalPointerMonitor: Any?
    private var canCommit = false
    var haptics = true
    var safeMode = false
    var dynamicIconMovement = false
    var windowPickerEnabled = false
    private var pull: WindowPull?
    private var previewTask: Task<Void, Never>?
    var loadPreviews: (NSRunningApplication) async -> [WindowPreview] = { await WindowPreview.load(app: $0) }
    private var preparedPreviews: [WindowPreview] = []
    private var previewOwner: String?
    private var lastMouse: CGPoint?
    var onAccessibilitySelect: ((Int) -> Void)?
    var onKeyEvent: ((NSEvent) -> Bool)?
    private let pointerLocation: () -> CGPoint

    init(pointerLocation: @escaping () -> CGPoint = { NSEvent.mouseLocation }) {
        self.pointerLocation = pointerLocation
    }

    func show(items: [WheelItem], geometry: WheelGeometry, layoutSlots: [WheelLayoutSlot] = [], center: CGPoint? = nil, trackMouse: Bool = true, instant: Bool = false, requiresKeyboardFocus: Bool = true) {
        generation += 1
        let ticket = generation
        stopPointerTracking()
        resetPicker()
        canCommit = true
        lastMouse = nil
        var reset = Transaction(); reset.disablesAnimations = true
        let immediate = instant || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        withTransaction(reset) {
            state.instantTransitions = instant
            state.revealed = false; state.selected = nil
            state.presentationReady = immediate
            state.selectionHasOrigin = false
            state.selectionAngle = geometry.startAngle
            state.geometry = geometry; state.items = items; state.layoutSlots = layoutSlots
            state.motion.lift = dynamicIconMovement ? 0 : 8
        }
        let origin = center ?? pointerLocation()
        let frame = NSRect(x: origin.x - geometry.panelSize/2, y: origin.y - geometry.panelSize/2, width: geometry.panelSize, height: geometry.panelSize)
        if panel == nil {
            let window = WheelPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.becomesKeyOnlyIfNeeded = true
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
        // The event tap already owns keyboard routing when authorized. Taking
        // key focus as a contact starts is unnecessary in that path. Keep the
        // key panel only for the monitor fallback (which cannot consume keys
        // delivered to another app). Also prevent clicks from taking focus.
        if let window = panel as? WheelPanel {
            if !requiresKeyboardFocus && window.isKeyWindow { window.resignKey() }
            window.requiresKeyboardFocus = requiresKeyboardFocus
        }
        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()
        if trackMouse && requiresKeyboardFocus { panel?.makeKey() }
        // Make the wheel interactive immediately. The first hover should not
        // wait for a deferred SwiftUI state update or the first timer tick.
        withTransaction(reset) { state.revealed = true }
        // Render the collapsed state before advancing appearance. Otherwise
        // SwiftUI can coalesce reset/reveal and skip the animation on reuse.
        panel?.contentView?.needsLayout = true
        panel?.contentView?.layoutSubtreeIfNeeded()
        if trackMouse { updateSelection() }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == ticket else { return }
            if !immediate && self.state.revealed { self.state.presentationReady = true }
            // Pick up a pointer move that occurred between orderFront and the
            // first timer tick without changing the animation timing.
            if trackMouse { self.updateSelection() }
        }
        if trackMouse {
            let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            // AppKit invokes both monitor callbacks on the main thread. Always
            // sample the current desktop position, not a queued event's old
            // location or window-relative coordinates. Never consume motion.
            localPointerMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                MainActor.assumeIsolated {
                    if self?.generation == ticket { self?.updateSelection() }
                }
                return event
            }
            globalPointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
                MainActor.assumeIsolated {
                    if self?.generation == ticket { self?.updateSelection() }
                }
            }
            // Fallback for coalesced/missed events and movement across windows.
            let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    if self?.generation == ticket { self?.updateSelection() }
                }
            }
            tracking = timer; RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopPointerTracking() {
        tracking?.invalidate(); tracking = nil
        if let localPointerMonitor { NSEvent.removeMonitor(localPointerMonitor) }
        if let globalPointerMonitor { NSEvent.removeMonitor(globalPointerMonitor) }
        localPointerMonitor = nil; globalPointerMonitor = nil
    }

    func updateSelection() {
        guard state.revealed, let panel, panel.isVisible else { return }
        let mouse = pointerLocation()
        guard mouse != lastMouse else { return }
        lastMouse = mouse
        let dx = mouse.x-panel.frame.midX, dy = mouse.y-panel.frame.midY
        let index = state.selectedIndex(dx: dx, dy: dy)
        let distance = hypot(dx, dy)
        let direction = atan2(-dy, dx)
        if let arc = state.arc {
            if distance >= arc.inner - 18 {
                let target = arc.index(distance: distance, direction: direction)
                if target != state.previewIndex { state.previewIndex = target }
                return
            }
            resetPicker()
            resizePanel(expanded: false)
        }
        let lift = state.geometry.iconLift(distance: hypot(dx, dy), dynamic: dynamicIconMovement)
        if abs(state.motion.lift - lift) > 0.001 { state.motion.lift = lift }
        select(index, pointerAngle: direction)
        if windowPickerEnabled, let index, state.items.indices.contains(index) {
            trackPull(item: state.items[index], distance: distance)
        }
    }

    private func resetPicker() {
        previewTask?.cancel()
        previewTask = nil
        previewOwner = nil
        preparedPreviews = []
        pull = nil
        state.previews = []
        state.previewIndex = nil
        state.motion.stretch = 0
    }

    private func resizePanel(expanded: Bool) {
        guard let panel else { return }
        let side = expanded ? state.geometry.diameter + 2 * state.geometry.thickness + 20 : state.geometry.panelSize
        let frame = NSRect(x: panel.frame.midX - side/2, y: panel.frame.midY - side/2, width: side, height: side)
        panel.setFrame(frame, display: true)
    }

    private func trackPull(item: WheelItem, distance: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        if previewOwner != item.id {
            resetPicker()
            previewOwner = item.id
            let app: NSRunningApplication?
            switch item.action {
            case .activate(let running): app = running
            case .launch(let url, let id):
                app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
                    !$0.isTerminated && $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath() == url.standardizedFileURL.resolvingSymlinksInPath()
                }
            default: app = nil
            }
            guard let app else { return }
            pull = WindowPull(distance: distance, time: now)
            let load = loadPreviews
            previewTask = Task { [weak self] in
                // Moving through a sector need not start screen capture.
                try? await Task.sleep(for: .milliseconds(35))
                guard !Task.isCancelled else { return }
                let previews = await load(app)
                guard !Task.isCancelled, let self, self.previewOwner == item.id else { return }
                self.preparedPreviews = previews
                if previews.isEmpty { self.pull = nil; self.state.motion.stretch = 0 }
                self.openArcIfReady()
            }
        } else if pull != nil {
            let stretch = pull!.sample(distance: distance, time: now, rim: state.geometry.diameter / 2)
            if state.motion.stretch != stretch { state.motion.stretch = stretch }
            openArcIfReady()
        }
    }

    private func openArcIfReady() {
        guard state.revealed, pull?.requested == true, state.previews.isEmpty, !preparedPreviews.isEmpty else { return }
        resizePanel(expanded: true)
        withAnimation(state.instantTransitions ? nil : .spring(duration: 0.14, bounce: 0.08)) {
            state.previews = preparedPreviews
            state.motion.stretch = 0
        }
        if haptics && !safeMode { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
        lastMouse = nil
        updateSelection()
    }

    func select(_ index: Int?, pointerAngle: Double? = nil) {
        guard index != state.selected else { return }
        if previewOwner != nil { resetPicker() }
        if let index, state.items.indices.contains(index) {
            let target = state.angle(for: index)
            state.selectionHasOrigin = state.selected != nil
            state.selectionAngle += WheelGeometry.selectionDelta(from: state.selectionAngle, to: target, pointer: pointerAngle)
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
        resetPicker()
        resizePanel(expanded: false)
        let selectedID = state.selected.flatMap { state.items.indices.contains($0) ? state.items[$0].id : nil }
        let next = selectedID.flatMap { id in items.firstIndex { $0.id == id } }
        withAnimation(state.instantTransitions ? nil : .easeOut(duration: 0.12)) {
            state.items = items; state.selected = next
            if let next { state.selectionAngle += WheelGeometry.shortestDelta(from: state.selectionAngle, to: state.angle(for: next)) }
        }
        lastMouse = nil
    }

    func hide(immediately: Bool = false) {
        generation += 1
        let ticket = generation
        canCommit = false
        resetPicker()
        stopPointerTracking()
        if immediately || state.instantTransitions || !state.presentationReady || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { state.revealed = false; state.selected = nil }
            panel?.orderOut(nil); return
        }
        state.revealed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + WheelPresentation.hideDuration) { [weak self] in
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
    let launcher = WheelController(), quitter = WheelController(), switcher = WheelController()
    let catalog = ApplicationCatalog()
    let store: PreferenceStore
    let actions: ActionService
    var requiresKeyboardFocus: () -> Bool = { true }
    private struct QuitterSession {
        let slots: [WheelLayoutSlot]
        let activeIdentifiers: Set<String>

        func visibleItems(from items: [WheelItem]) -> [WheelItem] {
            items.filter { $0.isTrash || activeIdentifiers.contains($0.layoutIdentifier) }
        }
    }
    private var quitterSession: QuitterSession?
    private var switcherSession: QuitterSession?
    private func transitionIsInstant() -> Bool {
        let instant = store.value.lessAnimation
        launcher.state.instantTransitions = instant; quitter.state.instantTransitions = instant; switcher.state.instantTransitions = instant
        return instant
    }
    init(store: PreferenceStore, safeMode: Bool) {
        self.store = store; self.actions = ActionService(safeMode: safeMode)
        self.actions.forceQuitApps = { [weak store] id in store?.value.shouldForceQuit(id) ?? false }
        super.init()
        launcher.safeMode = safeMode; quitter.safeMode = safeMode; switcher.safeMode = safeMode
        actions.quitStateChanged = { [weak self] in self?.refreshQuitter() }
        catalog.runningAppsChanged = { [weak self] in self?.refreshQuitter(); self?.refreshSwitcher() }
    }
    private func refreshQuitter() {
        guard quitter.state.revealed else { return }
        // Stable mode retains empty slots; automatic mode reflows running apps.
        let items = catalog.quitter(showsTrash: store.value.showsTrash, excluding: actions.pendingQuitIDs)
        quitter.replaceItems(quitterSession?.visibleItems(from: items) ?? items)
    }

    private func refreshSwitcher() {
        guard switcher.state.revealed else { return }
        let items = catalog.switcher()
        switcher.replaceItems(switcherSession?.visibleItems(from: items) ?? items)
    }

    static func stableLayout(items: [WheelItem], preferences: HaloPreferences, geometry: WheelGeometry, switching: Bool = false) -> QuitterLayoutPlan {
        let launcherCount = preferences.launcherTargets.count
        var launcherAngles: [String: Double] = [:]
        for (index, target) in preferences.launcherTargets.enumerated() {
            // One stable bundle identity has one launcher position. The first
            // configured copy wins deterministically if an unusual duplicate exists.
            launcherAngles[target.resolvedBundleIdentifier] = launcherAngles[target.resolvedBundleIdentifier]
                ?? WheelGeometry().angle(index: index, count: launcherCount)
        }
        let fixedSlots = items.filter(\.isTrash).map {
            WheelLayoutSlot(id: $0.layoutIdentifier, angle: geometry.startAngle)
        }
        let requests = items.filter { !$0.isTrash }.map { item in
            let identifier = item.layoutIdentifier
            let persistentID = item.stableIdentifier
            return QuitterLayoutRequest(identifier: identifier,
                                        launcherAngle: persistentID.flatMap { launcherAngles[$0] },
                                        rememberedAngle: persistentID.flatMap { (switching ? preferences.switcherPreferredAngles : preferences.quitterPreferredAngles)[$0] }.map(QuitterLayoutPlanner.angle(forNormalizedTurn:)),
                                        persistsAngle: persistentID != nil)
        }
        let iconSize = geometry.itemSize(count: max(1, items.count))
        let ratio = min(0.99, (iconSize + 6) / max(1, 2 * geometry.iconRadius))
        return QuitterLayoutPlanner.plan(requests: requests, fixedSlots: fixedSlots,
            minimumSeparation: 2 * asin(ratio))
    }

    private func newQuitterSession(items: [WheelItem], preferences: HaloPreferences, geometry: WheelGeometry, switching: Bool = false) -> QuitterSession {
        let plan = Self.stableLayout(items: items, preferences: preferences, geometry: geometry, switching: switching)
        if !plan.newlyRememberedAngles.isEmpty {
            var next = preferences
            for (identifier, angle) in plan.newlyRememberedAngles {
                if switching { next.switcherPreferredAngles[identifier] = angle }
                else { next.quitterPreferredAngles[identifier] = angle }
            }
            // Discovery is a local persistence detail, not a user-edited
            // appearance change; do not cancel the wheel that just opened.
            _ = store.save(next, notify: false)
        }
        return QuitterSession(slots: plan.slots, activeIdentifiers: Set(items.map(\.layoutIdentifier)))
    }
    func controller(_ wheel: HaloWheel) -> WheelController { wheel == .launcher ? launcher : wheel == .switcher ? switcher : quitter }
    func showWheel(_ wheel: HaloWheel) {
        let instant = transitionIsInstant()
        let isQuitter = wheel == .quitter
        if isQuitter == false { quitterSession = nil }
        if wheel != .switcher { switcherSession = nil }
        for other in [HaloWheel.launcher, .quitter, .switcher] where other != wheel { controller(other).hide(immediately: true) }
        let preferences = store.value
        let c = controller(wheel)
        c.state.glassFinish = preferences.glassFinish
        c.state.glassAmount = preferences.glassAmount
        c.state.selectionTint = preferences.selectionTint
        c.state.highlightsTrash = preferences.highlightsTrash
        c.windowPickerEnabled = !isQuitter && !c.safeMode && preferences.windowPreviews && CGPreflightScreenCaptureAccess() && AXIsProcessTrusted()
        c.haptics = preferences.haptics
        c.dynamicIconMovement = preferences.dynamicIconMovement
        let geometry = WheelGeometry(diameter: wheel == .switcher ? preferences.switcherDiameter : isQuitter ? preferences.quitterDiameter : preferences.launcherDiameter, selectionDistance: preferences.selectionDistance, maximumSelectionDistance: preferences.maximumSelectionDistance, quitter: isQuitter, trashPosition: preferences.trashPosition, thickness: preferences.wheelThickness)
        if isQuitter {
            let items = catalog.quitter(showsTrash: preferences.showsTrash, excluding: actions.pendingQuitIDs)
            let session = preferences.stableQuitterPositions ? newQuitterSession(items: items, preferences: preferences, geometry: geometry) : nil
            quitterSession = session
            c.show(items: items, geometry: geometry, layoutSlots: session?.slots ?? [], instant: instant, requiresKeyboardFocus: requiresKeyboardFocus())
        } else if wheel == .switcher {
            let items = catalog.switcher()
            let session = preferences.stableSwitcherPositions ? newQuitterSession(items: items, preferences: preferences, geometry: geometry, switching: true) : nil
            switcherSession = session
            c.show(items: items, geometry: geometry, layoutSlots: session?.slots ?? [], instant: instant, requiresKeyboardFocus: requiresKeyboardFocus())
        } else {
            c.show(items: catalog.launcher(targets: preferences.launcherTargets), geometry: geometry, instant: instant, requiresKeyboardFocus: requiresKeyboardFocus())
        }
    }
    func hideWheel(_ wheel: HaloWheel) {
        let c = controller(wheel)
        if c.state.revealed { _ = transitionIsInstant() }
        c.hide()
        if wheel == .quitter { quitterSession = nil }
        if wheel == .switcher { switcherSession = nil }
    }
    func commitWheel(_ wheel: HaloWheel) {
        let c = controller(wheel)
        if c.state.revealed { _ = transitionIsInstant() }
        c.updateSelection()
        if !c.state.previews.isEmpty {
            let target = c.state.previewIndex.flatMap { c.state.previews.indices.contains($0) ? c.state.previews[$0] : nil }
            c.hide()
            if wheel == .switcher { switcherSession = nil }
            if let target, !actions.safeMode { Task { await target.raise() } }
            return
        }
        let item = c.takeSelection()
        c.hide()
        if wheel == .quitter { quitterSession = nil }
        if wheel == .switcher { switcherSession = nil }
        guard let item else { return }
        actions.prepare(item)
        if store.value.haptics && !actions.safeMode { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
        // Close first; application work never holds up release-to-select feedback.
        DispatchQueue.main.async { [weak self] in self?.actions.perform(item) }
    }
    func frame(for wheel: HaloWheel) -> NSRect { controller(wheel).panel?.frame ?? .zero }
    func stop() { quitterSession = nil; switcherSession = nil; launcher.hide(); quitter.hide(); switcher.hide(); catalog.stop() }
}
