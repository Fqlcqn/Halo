#if DEBUG
import AppKit
import SwiftUI

/// Integration tests enter the real window/animation controller, but never invoke live actions.
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
        for chord in [runtime.engine.config.launcher!, runtime.engine.config.quitter!] {
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
        for wheel in [HaloWheel.launcher, HaloWheel.quitter] {
            localRuntime.engine.update([], at: 10)
            let chord = wheel == .launcher ? localRuntime.engine.config.launcher! : localRuntime.engine.config.quitter!
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
        localRuntime.stop(); driver.stop()
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
        print("PASS: \(checks) native window/lifecycle checks, including 100 rapid cycles. No real app or Trash actions executed.")
    }
}
#endif
