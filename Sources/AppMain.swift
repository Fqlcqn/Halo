import AppKit

@main @MainActor final class HaloAppDelegate: NSObject, NSApplicationDelegate {
    static var current: HaloAppDelegate?
    private var status: NSStatusItem?
    private var runtime: HaloRuntime?
    private(set) var store: PreferenceStore!
    private var wheels: WheelCoordinator?
    private var testDefaultsDomain: String?

    static func main() {
        let app = NSApplication.shared
        let delegate = HaloAppDelegate()
        current = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
#if DEBUG
        if args.contains("--glass-comparison") {
            NativeChecks.glassComparison(); return
        }
        if args.contains("--self-test") {
            Task { await NativeChecks.run(); NSApp.terminate(nil) }
            return
        }
#endif
        let preview = args.contains("--preview")
        var safe = args.contains("--safe-mode") || preview
        var defaults = UserDefaults.standard
#if DEBUG
        if args.contains("--ui-test") {
            safe = true
            let menu = NSMenu()
            let appMenu = NSMenu()
            let quit = NSMenuItem(title: "End safe test", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            quit.target = NSApp; appMenu.addItem(quit)
            let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item)
            NSApp.mainMenu = menu
            let domain = "Halo.Production.UITests.\(UUID().uuidString)"
            testDefaultsDomain = domain
            defaults = UserDefaults(suiteName: domain)!
            let original = PreferenceStore(defaults: .standard).value
            _ = PreferenceStore(defaults: defaults).save(original)
            // UI testing is bounded and cannot change the user's preferences.
            DispatchQueue.main.asyncAfter(deadline: .now() + 180) { NSApp.terminate(nil) }
        }
#endif
        store = PreferenceStore(defaults: defaults)
#if DEBUG
        if args.contains("--ui-test"), args.contains("--dense-preview") {
            var fixture = store.value
            fixture.launcherTargets = (0..<24).map {
                LauncherTarget(id: "fixture:\($0)", name: "Test App \($0 + 1)", bundleIdentifier: "com.apple.systempreferences")
            }
            _ = store.save(fixture)
        }
#endif
        let coordinator = WheelCoordinator(store: store, safeMode: safe)
        wheels = coordinator
        // Warm the small icon catalog before the first keyboard interaction.
        _ = coordinator.catalog.launcher(targets:store.value.launcherTargets)
        _ = coordinator.catalog.quitter()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status = item
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.labelColor.setFill()
            let ring = NSBezierPath(ovalIn: NSRect(x: 2.1, y: 2.1, width: 13.8, height: 13.8))
            ring.appendOval(in: NSRect(x: 5.3, y: 5.3, width: 7.4, height: 7.4))
            ring.windingRule = .evenOdd; ring.fill()
            return true
        }
        image.isTemplate = true; item.button?.image = image
        let input = HaloRuntime(driver: coordinator, defaults: defaults)!
        runtime = input
        coordinator.launcher.onKeyEvent = { [weak input] in input?.handleWheelKeyEvent($0) ?? false }
        coordinator.quitter.onKeyEvent = { [weak input] in input?.handleWheelKeyEvent($0) ?? false }
        input.connect(with: item, monitorInput: !safe)
        coordinator.launcher.onAccessibilitySelect = { [weak coordinator] index in
            guard let coordinator, coordinator.launcher.state.items.indices.contains(index) else { return }
            coordinator.launcher.hide(); coordinator.actions.perform(coordinator.launcher.state.items[index])
        }
        coordinator.quitter.onAccessibilitySelect = { [weak coordinator] index in
            guard let coordinator, coordinator.quitter.state.items.indices.contains(index) else { return }
            coordinator.quitter.hide(); coordinator.actions.perform(coordinator.quitter.state.items[index])
        }
        store.onChange = { [weak input, weak coordinator] in
            input?.cancel(); coordinator?.launcher.hide(); coordinator?.quitter.hide()
        }
        if preview {
            let kind = argument("--preview") ?? "launcher"
            let c = kind == "quitter" ? coordinator.quitter : coordinator.launcher
            c.state.glassFinish = argument("--glass").flatMap(Int.init).flatMap(WheelGlassFinish.init(rawValue:)) ?? store.value.glassFinish
            c.state.glassAmount = store.value.glassAmount
            let center = NSScreen.main.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? .zero
            c.show(items: kind == "quitter" ? coordinator.catalog.quitter() : coordinator.catalog.launcher(targets: store.value.launcherTargets), geometry: WheelGeometry(diameter: kind == "quitter" ? store.value.quitterDiameter : store.value.launcherDiameter, selectionDistance: store.value.selectionDistance, maximumSelectionDistance: store.value.maximumSelectionDistance, quitter: kind == "quitter", trashPosition: store.value.trashPosition, thickness: store.value.wheelThickness), center: center, trackMouse: false)
            if let selection = argument("--selection").flatMap(Int.init) { c.select(selection) }
            if let fixture = argument("--fixture-background"), let background = NSImage(contentsOfFile: fixture) {
                let x = argument("--fixture-x").flatMap(Double.init) ?? 959
                let y = argument("--fixture-y").flatMap(Double.init) ?? 544
                c.showFixture(background: background, centerPixels: CGPoint(x:x,y:y))
            }
            if let path = argument("--capture") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    do { try c.capture(to: URL(fileURLWithPath: path)); print("Captured \(path)") }
                    catch { print("Capture failed: \(error)") }
                    NSApp.terminate(nil)
                }
            }
        } else if store.value.showSettingsOnLaunch { input.showSettings(nil) }
#if DEBUG
        if args.contains("--ui-test"), let kind = argument("--keyboard-check") {
            NSApp.windows.filter { $0.title == "Halo Settings" }.forEach { $0.close() }
            let chord = kind == "quitter" ? input.engine.config.quitter! : input.engine.config.launcher!
            input.engine.update(chord, at: ProcessInfo.processInfo.systemUptime)
        }
#endif
    }

    private func argument(_ name: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: name), index+1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[index+1]
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if CommandLine.arguments.contains("--preview") { return false }
        runtime?.showSettings(nil); return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Close a diagnostic comparison immediately, without leaving an agent app.
        CommandLine.arguments.contains("--glass-comparison")
    }
    func applicationWillTerminate(_ notification: Notification) {
        runtime?.stop(); wheels?.stop()
        if let domain = testDefaultsDomain { UserDefaults.standard.removePersistentDomain(forName: domain) }
    }
}
