#if DEBUG
import AppKit
import SwiftUI

/// Native tests use safe wheel items; reopen integration acts only on disposable fixture apps.
@MainActor enum NativeChecks {
    static func glassComparison() {
        let items = ApplicationCatalog().launcher(targets: LauncherTarget.original)
        let states = WheelGlassFinish.allCases.map { finish in
            let state = WheelState()
            state.geometry = WheelGeometry(diameter: 240)
            state.items = items; state.glassFinish = finish; state.revealed = true
            return state
        }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 930, height: 370), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Halo Glass Comparison — safe preview"
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: ZStack {
            LinearGradient(colors: [.cyan, .blue, .indigo, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 15) {
                ForEach(0..<12) { row in
                    HStack(spacing: 14) {
                        ForEach(0..<10) { _ in
                            Text(row.isMultiple(of: 2) ? "GLASS 012345" : "Background detail")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                    VStack(spacing: 8) {
                        Text(state.glassFinish.title).font(.headline)
                        WheelView(state: state)
                    }
                }
            }
        }.frame(width: 930, height: 370).environment(\.colorScheme, .dark))
        host.sizingOptions = []; panel.contentView = host
        panel.center(); panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Every visual diagnostic is bounded and leaves no test app running.
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) {
            panel.close(); NSApp.terminate(nil)
        }
    }

    static func run() async {
        var checks = 0
        func expect(_ condition: Bool, _ message: String) { precondition(condition, message); checks += 1 }
        func settle() async { try? await Task.sleep(for: .milliseconds(100)) }
        for diameter in [240.0, 300, 520] {
            let contour = GlassAnnulus(thickness: 66).path(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
            let center = diameter / 2
            expect(!contour.contains(CGPoint(x: center, y: center)), "Glass center stays open")
            for angle in stride(from: 0.0, to: 2 * .pi, by: .pi / 180) {
                for (radius, inside) in [(center - 33, true), (center - 67, false), (center + 1, false)] {
                    expect(contour.cgPath.contains(CGPoint(x: center + radius * cos(angle), y: center + radius * sin(angle))) == inside,
                           "Annulus diameter \(diameter), radius \(radius), angle \(angle), expected inside \(inside)")
                }
            }
        }
        let controller = WheelController()
        controller.safeMode = true
        let items = (0..<8).map { WheelItem(id:"fixture:\($0)",name:"Fixture \($0)",icon:NSImage(size:NSSize(width:58,height:58)),action:.launch(URL(fileURLWithPath:"/nonexistent-harmless-fixture.app"), bundleIdentifier: "fixture.\($0)")) }
        let center = NSScreen.main.map { CGPoint(x:$0.frame.midX,y:$0.frame.midY) } ?? CGPoint(x:400,y:400)
        // Synthetic positions and in-process events only: never move the real
        // cursor, post system input, or select a live application.
        var pointer = center
        var samples = 0
        let responsive = WheelController(pointerLocation: { samples += 1; return pointer })
        responsive.safeMode = true
        let focus = NSWindow(contentRect: NSRect(x: center.x, y: center.y, width: 160, height: 100),
                             styleMask: [.titled], backing: .buffered, defer: false)
        focus.isReleasedWhenClosed = false
        focus.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        await settle()
        expect(focus.isKeyWindow, "Focus fixture starts key")
        for instant in [false, true] {
            for quitter in [false, true] {
                focus.makeKeyAndOrderFront(nil)
                pointer = center
                responsive.show(items: items, geometry: WheelGeometry(quitter: quitter), center: center,
                                instant: instant, requiresKeyboardFocus: false)
                expect(focus.isKeyWindow && responsive.panel?.isKeyWindow == false,
                       "Authorized wheel preserves focus (instant=\(instant), quitter=\(quitter), focusKey=\(focus.isKeyWindow), wheelKey=\(responsive.panel?.isKeyWindow == true))")
                expect(responsive.panel?.canBecomeKey == false, "Clicking an authorized wheel cannot take key focus")
                expect(responsive.state.selected == nil, "Stationary contact starts neutral")
                for type in [NSEvent.EventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged] {
                    pointer = CGPoint(x: center.x + 120, y: center.y)
                    let event = NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: [.function, .control],
                                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                                  windowNumber: responsive.panel!.windowNumber, context: nil,
                                                  eventNumber: 0, clickCount: 0, pressure: 0)!
                    NSApp.sendEvent(event)
                    expect(responsive.state.selected == (quitter ? 6 : 2),
                           "Move/drag selects in the delivery turn before a timer or reveal, using desktop coordinates")
                    pointer = center
                    NSApp.sendEvent(event)
                    expect(responsive.state.selected == nil, "Returning to center clears selection immediately")
                }
                pointer = CGPoint(x: center.x - 120, y: center.y)
                responsive.updateSelection()
                expect(responsive.takeSelection()?.id == (quitter ? "fixture:2" : "fixture:6"),
                       "Final synchronous sample selects the latest position")
                responsive.hide()
                let before = samples
                responsive.updateSelection()
                expect(samples == before, "A closing visible panel cannot sample or select again")
                await settle()
                expect(samples == before, "Hidden sessions remove all pointer monitors and polling")
            }
        }
        pointer = center
        responsive.show(items: items, geometry: WheelGeometry(), center: center, requiresKeyboardFocus: true)
        expect(responsive.panel?.isKeyWindow == true, "Permission fallback still accepts native keyboard focus")
        responsive.hide(immediately: true)
        focus.makeKeyAndOrderFront(nil)
        for _ in 0..<50 {
            responsive.show(items: items, geometry: WheelGeometry(), center: center, requiresKeyboardFocus: false)
            responsive.hide(immediately: true)
        }
        responsive.show(items: items, geometry: WheelGeometry(), center: center, requiresKeyboardFocus: false)
        pointer = CGPoint(x: center.x + 120, y: center.y)
        await settle()
        expect(responsive.state.selected == 2, "Fallback timer catches movement without a delivered event after rapid reopen")
        responsive.hide(immediately: true)
        // Exercise the actual overlay and pointer lifecycle with synthetic
        // thumbnails. The fixture never captures or raises a user's window.
        let pixels = CGContext(data: nil, width: 40, height: 24, bitsPerComponent: 8, bytesPerRow: 160,
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        pixels.setFillColor(red: 1, green: 0, blue: 1, alpha: 1)
        pixels.fill(CGRect(x: 0, y: 0, width: 40, height: 24))
        let snapshot = pixels.makeImage()!
        let app = NSRunningApplication.current
        let pair = (1...2).map { WindowPreview(id: CGWindowID($0), image: snapshot,
                                               element: AXUIElementCreateApplication(app.processIdentifier), app: app) }
        expect(WindowPreview.isUserWindow(role: kAXWindowRole, subrole: kAXStandardWindowSubrole, hasControls: false, canRaise: true),
               "Ordinary windows remain selectable without relying on title or image content")
        expect(!WindowPreview.isUserWindow(role: kAXWindowRole, subrole: kAXUnknownSubrole, hasControls: false, canRaise: true),
               "Auxiliary surfaces without user-window semantics are omitted")
        expect(!WindowPreview.isUserWindow(role: kAXWindowRole, subrole: kAXStandardWindowSubrole, hasControls: true, canRaise: false),
               "A window without the required focus action never becomes a dead sector")
        expect(WindowPreview.isUserWindow(role: kAXWindowRole, subrole: kAXUnknownSubrole, hasControls: true, canRaise: true),
               "Custom windows with standard controls remain supported")
        expect(!WindowPreview.isUserWindow(role: kAXGroupRole, subrole: kAXStandardWindowSubrole, hasControls: true, canRaise: true),
               "Non-window accessibility elements are rejected")
        let transparent = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        expect(!WindowPreview.hasVisiblePixels(transparent.makeImage()!), "Empty transparent captures are omitted")
        for gray in [0.0, 1.0] {
            transparent.setFillColor(gray: gray, alpha: 1)
            transparent.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
            expect(WindowPreview.hasVisiblePixels(transparent.makeImage()!), "Real solid black or white window content is retained")
        }
        let candidates = (1...4).map { WindowPreview(id: CGWindowID($0), image: snapshot,
                                                     element: AXUIElementCreateApplication(pid_t($0)), app: app) }
        expect(WindowPreview.retainingLiveWindows(candidates, ids: [1, 2, 3], elements: candidates.map(\.element)).map(\.id) == [1, 2, 3],
               "A fourth surface removed during capture leaves exactly three sectors")
        expect(WindowPreview.retainingLiveWindows(candidates, ids: [1, 2, 3, 4], elements: candidates.prefix(3).map(\.element)).map(\.id) == [1, 2, 3],
               "A stale AX window is removed even if its capture surface remains")
        expect(WindowPreview.retainingLiveWindows(candidates + [candidates[0]], ids: [1, 2, 3, 4], elements: candidates.map(\.element)).count == 4,
               "Repeated window identities cannot create duplicate sectors")
        responsive.windowPickerEnabled = true
        responsive.loadPreviews = { _ in pair }
        let target = WheelItem(id: "preview-fixture", name: "Fixture", icon: nil, action: .activate(app))
        pointer = center
        responsive.show(items: [target] + Array(items.prefix(7)), geometry: WheelGeometry(selectionDistance: 86, maximumSelectionDistance: 2000), center: center, instant: true, requiresKeyboardFocus: false)
        pointer.y += 123
        responsive.updateSelection()
        try? await Task.sleep(for: .milliseconds(200))
        expect(responsive.state.selected == 0 && responsive.state.arc == nil, "Ordinary hover keeps app selection")
        // A separate outward stroke can now start on the visible ring.
        for _ in 0..<4 {
            pointer.y += 13
            responsive.updateSelection()
            try? await Task.sleep(for: .milliseconds(7))
        }
        expect(responsive.state.arc?.count == 2 && responsive.panel!.frame.width > 400, "Outward pull reveals two native sectors")
        let arc = responsive.state.arc!
        for i in pair.indices {
            let angle = arc.center(i)
            pointer = CGPoint(x: center.x + 185*cos(angle), y: center.y - 185*sin(angle))
            responsive.updateSelection()
            expect(responsive.state.previewIndex == i, "Arc hit testing follows visible preview")
        }
        // Inspect unselected image pixels away from the center of the sector.
        pointer = CGPoint(x: center.x + 180, y: center.y)
        responsive.updateSelection()
        await settle()
        if let view = responsive.panel?.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            for i in pair.indices {
                for (fraction, radius) in [(0.0, (arc.outer + arc.inner)/2), (0.39, arc.inner + 4), (-0.39, arc.outer - 4)] {
                    let angle = arc.center(i) + arc.width * fraction
                    let x = Int((0.5 + radius*cos(angle)/view.bounds.width) * Double(bitmap.pixelsWide))
                    let y = Int((0.5 + radius*sin(angle)/view.bounds.height) * Double(bitmap.pixelsHigh))
                    let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
                    expect((color?.redComponent ?? 0) > 0.85 && (color?.blueComponent ?? 0) > 0.85 &&
                           (color?.greenComponent ?? 1) < 0.65, "Thumbnail fills curved sector, including near its corners")
                }
            }
        }
        // The SelectionBand is drawn above opaque image content. Compare the
        // same point before and after selection, using the existing native view.
        if let view = responsive.panel?.contentView {
            let angle = arc.center(0)
            let radius = (arc.inner + arc.outer)/2
            func greenAtCenter() -> CGFloat {
                let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let x = Int((0.5 + radius*cos(angle)/view.bounds.width) * Double(bitmap.pixelsWide))
                let y = Int((0.5 + radius*sin(angle)/view.bounds.height) * Double(bitmap.pixelsHigh))
                return bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!.greenComponent
            }
            let unselected = greenAtCenter()
            pointer = CGPoint(x: center.x + radius*cos(angle), y: center.y - radius*sin(angle))
            responsive.updateSelection()
            await settle()
            expect(abs(greenAtCenter() - unselected) > 0.04, "Selecting a preview visibly highlights its image")
        }
        pointer = center
        responsive.updateSelection()
        expect(responsive.state.arc == nil && responsive.state.selected == nil, "Retreat cancels picker and center release")
        responsive.hide(immediately: true)
        for stoppingRadius in [84.0, 123.0, 185.0, 940.0] {
            pointer = center
            let reach = 100.0
            responsive.show(items: [target] + Array(items.prefix(7)),
                            geometry: WheelGeometry(selectionDistance: 86, maximumSelectionDistance: reach),
                            center: center, instant: true, requiresKeyboardFocus: false)
            pointer.y += stoppingRadius
            responsive.updateSelection()
            try? await Task.sleep(for: .milliseconds(200))
            if stoppingRadius < 86 {
                expect(responsive.state.selected == nil && responsive.takeSelection() == nil,
                       "Inner-edge tracking preserves neutral release inside the ordinary dead zone")
            }
            pointer.y += 50
            responsive.updateSelection()
            expect(responsive.state.arc?.count == 2, "A second push can start at the inner edge, cross finite reach or start far outside")
            if stoppingRadius + 50 < 150 {
                pointer.y += 2
                responsive.updateSelection()
                expect(responsive.state.arc != nil, "An arc opened inside the rim stays open while moving toward its previews")
            }
            pointer.y = center.y + 1100
            responsive.updateSelection()
            pointer.y = center.y + 185
            responsive.updateSelection()
            expect(responsive.state.arc != nil && responsive.state.previewIndex != nil, "Long inward movement can select a preview")
            pointer.y = center.y + 150
            responsive.updateSelection()
            expect(responsive.state.arc != nil && responsive.state.previewIndex == nil, "Gap and exact launcher rim keep arc open")
            pointer.y = center.y + 149
            responsive.updateSelection()
            expect(responsive.state.arc == nil, "Crossing inside the launcher rim collapses the arc")
            responsive.hide(immediately: true)
        }
        pointer = center
        let compact = WheelGeometry(diameter: 240, selectionDistance: 86, thickness: 78)
        responsive.show(items: [target], geometry: compact, center: center, instant: true, requiresKeyboardFocus: false)
        pointer.y += compact.innerDiameter / 2
        responsive.updateSelection()
        try? await Task.sleep(for: .milliseconds(200))
        expect(responsive.state.selected == nil, "Thick compact wheel can track at its inner edge while ordinary selection stays neutral")
        for _ in 0..<4 {
            pointer.y += 12
            responsive.updateSelection()
            try? await Task.sleep(for: .milliseconds(7))
        }
        expect(responsive.state.arc?.count == 2, "A compact wheel retains the same pull while crossing its app-selection dead zone")
        responsive.hide(immediately: true)
        responsive.loadPreviews = { _ in [pair[0]] }
        pointer = center
        responsive.show(items: [target], geometry: WheelGeometry(), center: center, instant: true, requiresKeyboardFocus: false)
        pointer.y += 190
        responsive.updateSelection()
        try? await Task.sleep(for: .milliseconds(200))
        pointer.y += 55
        responsive.updateSelection()
        expect(responsive.state.arc == nil && responsive.takeSelection()?.id == target.id,
               "A single window always takes the ordinary launcher path")
        responsive.hide(immediately: true)
        // Simulate a capture API finishing after cancellation, then reopening
        // the same app. No capture permission or user-window action is needed.
        var pending: [CheckedContinuation<[WindowPreview], Never>] = []
        responsive.loadPreviews = { _ in await withCheckedContinuation { pending.append($0) } }
        for _ in 0..<2 {
            pointer = center
            responsive.show(items: [target], geometry: WheelGeometry(), center: center, instant: true, requiresKeyboardFocus: false)
            pointer.y += 123
            responsive.updateSelection()
            try? await Task.sleep(for: .milliseconds(80))
            if pending.count == 1 { responsive.hide(immediately: true) }
        }
        expect(pending.count == 2, "Both rapid same-app requests reach the delayed capture fixture")
        pending[1].resume(returning: pair)
        try? await Task.sleep(for: .milliseconds(160))
        pointer.y += 52
        responsive.updateSelection()
        expect(responsive.state.arc?.count == 2, "The latest capture supplies the reopened arc")
        let currentSession = responsive.state.previewSession
        pending[0].resume(returning: candidates)
        await settle()
        expect(responsive.state.arc?.count == 2 && responsive.state.previews.map(\.id) == pair.map(\.id),
               "Late canceled four-window capture cannot add phantom sectors to the current two-window arc")
        responsive.hide(immediately: true)
        responsive.loadPreviews = { _ in pair }
        pointer = center
        responsive.show(items: [target], geometry: WheelGeometry(), center: center, instant: true, requiresKeyboardFocus: false)
        pointer.y += 123
        responsive.updateSelection()
        try? await Task.sleep(for: .milliseconds(200))
        pointer.y += 52
        responsive.updateSelection()
        expect(responsive.state.arc?.count == 2 && responsive.state.previewSession != currentSession,
               "Every new arc receives an independent rendering identity")
        responsive.hide(immediately: true)
        focus.close()
        for _ in 0..<100 {
            controller.show(items: items, geometry: WheelGeometry(), center: center, trackMouse: false, instant: true)
            expect(controller.state.revealed && controller.state.instantTransitions, "Less animation reveals immediately")
            expect(controller.state.presentationReady, "Less animation bypasses presentation staging")
            controller.select(1)
            expect(controller.takeSelection() != nil && controller.takeSelection() == nil, "Instant selection commits at most once")
            controller.hide()
            expect(controller.panel?.isVisible == false, "Less animation hides synchronously")
        }
        controller.show(items:items,geometry:WheelGeometry(),center:center,trackMouse:false)
        expect(controller.state.revealed, "Wheel reveal is available in the same run-loop turn")
        expect(!controller.state.instantTransitions, "Ordinary show restores smooth animation")
        expect(controller.state.presentationReady == NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
               "Animated reveal begins with the collapsed presentation while input is ready")
        controller.select(3)
        controller.replaceItems(Array(items.dropFirst()))
        expect(controller.state.selected == 2 && controller.state.items[2].id == "fixture:3", "Live refresh preserves the selected app by identity")
        controller.replaceItems(items.filter { $0.id != "fixture:3" })
        expect(controller.state.selected == nil, "Removing a selected app does not select its neighbor")
        controller.replaceItems(items)
        let stableSlots = [
            WheelLayoutSlot(id: "fixture:0", angle: -.pi / 2),
            WheelLayoutSlot(id: "fixture:1", angle: 0),
            WheelLayoutSlot(id: "fixture:2", angle: .pi / 2),
            WheelLayoutSlot(id: "fixture:3", angle: .pi)
        ]
        controller.show(items: Array(items.prefix(4)), geometry: WheelGeometry(), layoutSlots: stableSlots, center: center, trackMouse: false, instant: true)
        expect(controller.state.selectedIndex(dx: cos(.pi) * 120, dy: -sin(.pi) * 120) == 3, "Fixed session slots select their assigned app direction")
        controller.replaceItems([items[0], items[2], items[3]])
        expect(controller.state.layoutSlots == stableSlots, "Live removal retains every Quitter session slot")
        expect(controller.state.selectedIndex(dx: 120, dy: 0) == nil, "An exited app leaves an inert empty direction")
        expect(controller.state.selectedIndex(dx: cos(.pi) * 120, dy: -sin(.pi) * 120) == 2, "Remaining apps do not reindex after a live removal")
        controller.show(items: Array(items.prefix(4)), geometry: WheelGeometry(quitter: true), center: center, trackMouse: false, instant: true)
        expect(controller.state.layoutSlots.isEmpty, "Reopening in automatic mode clears stable slots")
        controller.replaceItems([items[0], items[2], items[3]])
        for index in controller.state.items.indices {
            expect(controller.state.angle(for: index) == controller.state.geometry.angle(index: index, count: 3),
                   "Automatic live removal evenly redistributes the remaining apps")
        }
        controller.show(items: items, geometry: WheelGeometry(), center: center, trackMouse: false, instant: true)
        controller.select(1)
        expect(controller.takeSelection()?.id == "fixture:1", "Fast selections commit without waiting for reveal animation")
        controller.hide()
        await settle()
        expect(controller.panel?.isVisible == false && !controller.state.revealed, "A cancelled reveal must not flash back")
        expect(controller.takeSelection() == nil, "Cancelled wheel cannot commit")
        controller.show(items:items,geometry:WheelGeometry(),center:center,trackMouse:false)
        controller.hide()
        controller.show(items:items,geometry:WheelGeometry(),center:center,trackMouse:false)
        await settle()
        expect(controller.panel?.isVisible == true && controller.state.revealed, "An old hide must not close a new session")
        expect(controller.state.presentationReady, "The current animated reveal advances after layout")
        expect(controller.panel?.frame.size == NSSize(width:356,height:356), "Exact panel geometry")
        expect(controller.panel?.hasShadow == false && controller.panel?.isOpaque == false, "Transparent, shadowless panel")
        expect(controller.panel?.level == .statusBar, "Reference overlay window level")
        for finish in WheelGlassFinish.allCases {
            controller.state.glassFinish = finish
            await settle()
            expect(controller.panel?.frame.size == NSSize(width:356,height:356), "Glass finishes preserve wheel geometry")
        }
        controller.state.glassFinish = .standard
        expect(controller.takeSelection() == nil, "Neutral release does nothing")
        controller.select(3)
        expect(controller.takeSelection()?.id == "fixture:3", "Selected item commits")
        expect(controller.takeSelection() == nil, "A session can commit only once")
        controller.hide()
        await settle()
        let domain = "Halo.Production.NativeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let runtime = HaloRuntime(driver: nil, defaults: defaults)!
        let settings = HaloSettingsController(runtime: runtime)!
        settings.present()
        await settle()
        let window = settings.window!
        expect(window.styleMask.contains(.titled) && window.styleMask.contains(.fullSizeContentView), "Settings uses native window chrome with full-size glass")
        expect(!window.ignoresMouseEvents && window.isKeyWindow, "Settings activates and receives mouse events")
        let root = window.contentView!
        for x in stride(from: 30.0, through: 570.0, by: 30) {
            for y in stride(from: 30.0, through: 450.0, by: 30) {
                let hit = root.hitTest(NSPoint(x: x, y: y))
                expect(hit != nil, "Blank settings regions have a native hit target")
            }
        }
        expect(root.mouseDownCanMoveWindow, "Settings background supports window dragging")
        let moved = NSPoint(x: window.frame.origin.x + 30, y: window.frame.origin.y + 20)
        window.setFrameOrigin(moved)
        window.orderOut(nil); settings.present()
        expect(window.frame.origin == moved, "Reopening Settings preserves its dragged position")
        window.close()
        runtime.engine.config.switcherEnabled = true
        for chord in [runtime.engine.config.launcher!, runtime.engine.config.quitter!, runtime.engine.config.switcher!] {
            runtime.engine.update([], at: 1)
            runtime.engine.update(chord, at: 2)
            await settle()
            runtime.engine.update(chord.union([NSNumber(value: 43)]), at: 3)
            await settle()
            expect(runtime.settingsVisible, "Either wheel's comma effect reaches the real Settings controller")
            let opened = NSApp.windows.first { $0.title == "Halo Settings" && $0.isVisible }
            expect(opened?.isKeyWindow == true, "Shortcut presents Settings as the key window")
            opened?.close()
            runtime.engine.update([], at: 4)
        }
        runtime.stop()
        // Exercise the actual key panel route with the global event tap absent.
        // The prior tests only called the shortcut engine and missed this path.
        let keyStore = PreferenceStore(defaults: defaults)
        let driver = WheelCoordinator(store: keyStore, safeMode: true)
        let localRuntime = HaloRuntime(driver: driver, defaults: defaults)!
        driver.launcher.onKeyEvent = { localRuntime.handleWheelKeyEvent($0) }
        driver.quitter.onKeyEvent = { localRuntime.handleWheelKeyEvent($0) }
        driver.switcher.onKeyEvent = { localRuntime.handleWheelKeyEvent($0) }
        localRuntime.engine.config.switcherEnabled = true
        driver.requiresKeyboardFocus = { false }
        for wheel in [HaloWheel.launcher, HaloWheel.quitter, HaloWheel.switcher] {
            driver.showWheel(wheel)
            expect(driver.controller(wheel).panel?.canBecomeKey == false,
                   "Every coordinator route honors focus-preserving input")
        }
        for wheel in [HaloWheel.launcher, HaloWheel.quitter, HaloWheel.switcher] {
            driver.controller(wheel).hide(immediately: true)
        }
        driver.requiresKeyboardFocus = { true }
        for wheel in [HaloWheel.launcher, HaloWheel.quitter, HaloWheel.switcher] {
            localRuntime.engine.update([], at: 10)
            let chord = localRuntime.engine.config.chord(for: wheel)! as! Set<NSNumber>
            localRuntime.engine.update(chord, at: 11)
            await settle()
            let keyPanel = driver.controller(wheel).panel as! WheelPanel
            expect(keyPanel.isKeyWindow, "Visible wheel owns ordinary keyboard delivery without activating another app")
            let comma = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: keyPanel.windowNumber, context: nil, characters: ",", charactersIgnoringModifiers: ",", isARepeat: false, keyCode: 43)!
            keyPanel.keyDown(with: comma)
            await settle()
            expect(localRuntime.settingsVisible && NSApp.keyWindow?.title == "Halo Settings", "Native comma route opens Settings with Fn absent in the key snapshot")
            let up = NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: keyPanel.windowNumber, context: nil, characters: ",", charactersIgnoringModifiers: ",", isARepeat: false, keyCode: 43)!
            expect(localRuntime.handleWheelKeyEvent(up), "Native Settings key-up is consumed")
            NSApp.keyWindow?.close()
            localRuntime.engine.update([], at: 12)
        }
        localRuntime.stop()
        for stable in [false, true, false] {
            var preferences = keyStore.value
            preferences.stableQuitterPositions = stable
            preferences.showsTrash = true
            expect(keyStore.save(preferences), "Quitter layout mode saves")
            driver.showWheel(.quitter)
            expect(driver.quitter.state.layoutSlots.isEmpty == !stable,
                   "Actual coordinator uses fixed slots only when stable layout is enabled")
            if !stable {
                for index in driver.quitter.state.items.indices {
                    expect(driver.quitter.state.angle(for: index) == driver.quitter.state.geometry.angle(index: index, count: driver.quitter.state.items.count),
                           "Automatic mode returns to evenly spaced angles after disabling stable mode")
                }
            }
            driver.hideWheel(.quitter)
        }
        var switcherPreferences = keyStore.value
        switcherPreferences.switcherDiameter = 410; switcherPreferences.lessAnimation = true
        switcherPreferences.haptics = false; switcherPreferences.dynamicIconMovement = true
        switcherPreferences.selectionDistance = 60; switcherPreferences.maximumSelectionDistance = 500
        switcherPreferences.glassAmount = 0.7; switcherPreferences.wheelThickness = 48
        expect(keyStore.save(switcherPreferences), "Switcher appearance fixture saves")
        for stable in [false, true, false] {
            switcherPreferences.stableSwitcherPositions = stable
            expect(keyStore.save(switcherPreferences), "Switcher layout saves")
            driver.showWheel(.launcher); driver.showWheel(.quitter); driver.showWheel(.switcher)
            let state = driver.switcher.state
            expect(driver.launcher.panel?.isVisible == false && driver.quitter.panel?.isVisible == false,
                   "Switcher exclusively owns visible wheel")
            expect(state.geometry.diameter == 410 && state.geometry.selectionDistance == 60 && state.geometry.maximumSelectionDistance == 500,
                   "Switcher uses customized geometry")
            expect(state.instantTransitions && !driver.switcher.haptics && driver.switcher.dynamicIconMovement && state.glassAmount == 0.7,
                   "Shared behavior and appearance apply to Switcher")
            let expectedPIDs = Set(driver.catalog.quitter(showsTrash: false).map(\.id))
            expect(Set(state.items.map(\.id)) == expectedPIDs, "Switcher contains all eligible running apps without Trash")
            for item in state.items {
                if case .activate(let app) = item.action { expect(!app.isTerminated, "Switcher activates a live process") }
                else { expect(false, "Switcher cannot launch, quit or empty Trash") }
            }
            expect(state.items.isEmpty || state.layoutSlots.isEmpty == !stable, "Switcher supports both layout modes")
            driver.hideWheel(.switcher)
            expect(driver.switcher.takeSelection() == nil, "Hidden Switcher cannot commit")
        }
        driver.stop()
        controller.hide(immediately: true)
        expect(!window.isVisible && controller.panel?.isVisible == false, "All test windows are closed")
        expect(controller.panel?.isVisible == false, "Hide finishes and removes panel")
        for _ in 0..<100 {
            controller.show(items:items,geometry:WheelGeometry(),center:center,trackMouse:false)
            controller.select(2)
            controller.hide()
        }
        await settle()
        expect(controller.panel?.isVisible == false && controller.state.selected == nil, "100 rapid show/select/cancel cycles leave no stale panel or selection")
        controller.show(items:[],geometry:WheelGeometry(),center:center,trackMouse:false)
        controller.select(0)
        await settle()
        expect(controller.takeSelection() == nil, "Empty catalog is safe")
        controller.hide()
        await settle()
        if let index = CommandLine.arguments.firstIndex(of: "--reopen-fixtures"), index + 1 < CommandLine.arguments.count {
            do { _ = try await ReopenChecks.run(manifest: URL(fileURLWithPath: CommandLine.arguments[index + 1])) }
            catch { preconditionFailure("Reopen fixtures failed: \(error)") }
        }
        print("PASS: \(checks) native window/lifecycle checks, including 100 rapid cycles. No user-app or Trash actions executed.")
    }
}
#endif
