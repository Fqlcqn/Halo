import AppKit

/// Disposable, file-controlled app used only by the native integration suite.
/// It never opens user files and exits automatically if the harness disappears.
@main @MainActor final class ReopenFixture: NSObject, NSApplicationDelegate {
    struct Snapshot: Codable {
        let pid: Int32
        let reopens: Int
        let created: Int
        let visible: Bool
        let minimized: Bool
        let hidden: Bool
        let command: String
    }
    private var window: NSWindow?
    private var reopens = 0, created = 0
    private var command = ""
    private var timer: Timer?
    private var directory: URL { Bundle.main.bundleURL.deletingLastPathComponent() }
    static func main() {
        let app = NSApplication.shared
        let delegate = ReopenFixture()
        app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        publish()
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { NSApp.terminate(nil) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        reopens += 1
        if let window {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            created += 1
            let next = NSWindow(contentRect: NSRect(x: 120, y: 120, width: 240, height: 100),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            next.title = "Halo disposable reopen fixture"; next.isReleasedWhenClosed = false
            window = next; next.makeKeyAndOrderFront(nil)
        }
        publish(); return false
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    private func poll() {
        let next = (try? String(contentsOf: directory.appendingPathComponent("command"), encoding: .utf8)) ?? ""
        if next != command {
            command = next
            switch next.split(separator: ":").last {
            case "close": window?.close(); window = nil
            case "minimize": window?.miniaturize(nil)
            case "hide": NSApp.hide(nil)
            default: break
            }
        }
        publish()
    }
    private func publish() {
        let snapshot = Snapshot(pid: ProcessInfo.processInfo.processIdentifier, reopens: reopens, created: created,
            visible: window?.isVisible == true, minimized: window?.isMiniaturized == true,
            hidden: NSApp.isHidden, command: command)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: directory.appendingPathComponent("state.json"), options: .atomic)
        }
    }
}
