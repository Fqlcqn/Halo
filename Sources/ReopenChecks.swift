#if DEBUG
import AppKit

/// Only these generated, disposable apps receive real activation/reopen events.
@MainActor enum ReopenChecks {
    private struct Snapshot: Decodable {
        let pid: Int32, reopens: Int, created: Int
        let visible: Bool, minimized: Bool, hidden: Bool
        let command: String
    }
    private struct Failure: Error { let message: String }
    static func run(manifest: URL) async throws -> Int {
        let paths = try JSONDecoder().decode([String].self, from: Data(contentsOf: manifest))
        guard paths.count == 2 else { throw Failure(message: "Missing fixture pair") }
        let urls = paths.map { URL(fileURLWithPath: $0) }
        guard let identity = Bundle(url: urls[0])?.bundleIdentifier,
              identity.hasPrefix("Halo.ReopenFixture."),
              urls.allSatisfy({ Bundle(url: $0)?.bundleIdentifier == identity }) else {
            throw Failure(message: "Refusing to test an ordinary application")
        }
        var apps: [NSRunningApplication] = []
        var checks = 0
        func expect(_ value: Bool, _ message: String) throws {
            guard value else { throw Failure(message: message) }; checks += 1
        }
        func snapshot(_ url: URL) -> Snapshot? {
            guard let data = try? Data(contentsOf: url.deletingLastPathComponent().appendingPathComponent("state.json")) else { return nil }
            return try? JSONDecoder().decode(Snapshot.self, from: data)
        }
        func wait(_ condition: () -> Bool) async throws {
            for _ in 0..<240 {
                if condition() { return }
                try await Task.sleep(for: .milliseconds(25))
            }
            throw Failure(message: "Timed out waiting for disposable reopen fixture")
        }
        func command(_ value: String, to url: URL) async throws {
            let token = UUID().uuidString + ":" + value
            try token.write(to: url.deletingLastPathComponent().appendingPathComponent("command"), atomically: true, encoding: .utf8)
            try await wait { snapshot(url)?.command == token }
        }
        func launchItem(_ url: URL) -> WheelItem {
            WheelItem(id: url.path, name: "Disposable reopen fixture", icon: nil, action: .launch(url, bundleIdentifier: identity))
        }
        let service = ActionService(safeMode: false)
        do {
            for url in urls {
                service.perform(launchItem(url))
                try await wait { snapshot(url) != nil }
                guard let state = snapshot(url), let app = NSRunningApplication(processIdentifier: state.pid) else {
                    throw Failure(message: "Fixture did not launch")
                }
                apps.append(app)
                try expect(app.bundleURL?.standardizedFileURL == url.standardizedFileURL, "Launch preserves the chosen app copy")
            }
            try expect(apps[0].processIdentifier != apps[1].processIdentifier, "Same-identifier copies run separately")
            for (index, url) in urls.enumerated() {
                let app = apps[index]
                let switchItem = WheelItem(id: "fixture:\(index)", name: "Disposable reopen fixture", icon: nil, action: .activate(app))
                for item in [launchItem(url), switchItem] {
                    try await command("close", to: url)
                    let before = snapshot(url)!
                    let otherBefore = snapshot(urls[1-index])!.reopens
                    service.perform(item)
                    try await wait { (snapshot(url)?.reopens ?? 0) == before.reopens + 1 && snapshot(url)?.visible == true }
                    try expect(snapshot(url)!.created == before.created + 1, "Windowless running app creates one window on reopen")
                    try expect(snapshot(urls[1-index])!.reopens == otherBefore, "Reopen targets the exact process, not the other installed copy")
                    let opened = snapshot(url)!
                    service.perform(item)
                    try await wait { snapshot(url)?.reopens == opened.reopens + 1 }
                    try expect(snapshot(url)!.created == opened.created, "Existing window is reused instead of creating a duplicate")
                    try await command("minimize", to: url)
                    try await wait { snapshot(url)?.minimized == true }
                    let minimized = snapshot(url)!
                    service.perform(item)
                    try await wait { snapshot(url)?.reopens == minimized.reopens + 1 && snapshot(url)?.minimized == false }
                    try expect(snapshot(url)!.created == minimized.created, "Minimized window restores without a new document")
                    try await command("hide", to: url)
                    try await wait { snapshot(url)?.hidden == true }
                    let hidden = snapshot(url)!
                    service.perform(item)
                    try await wait { snapshot(url)?.reopens == hidden.reopens + 1 && snapshot(url)?.hidden == false }
                    try expect(snapshot(url)!.created == hidden.created, "Hidden window is reused")
                    let safeBefore = snapshot(url)!.reopens
                    ActionService(safeMode: true).perform(item)
                    try await Task.sleep(for: .milliseconds(150))
                    try expect(snapshot(url)!.reopens == safeBefore, "Safe mode sends no reopen event")
                }
            }
            let stopped = apps[0]
            stopped.terminate()
            try await wait { stopped.isTerminated }
            service.perform(WheelItem(id: "stopped", name: "Exited fixture", icon: nil, action: .activate(stopped)))
            try await Task.sleep(for: .milliseconds(150))
            try expect(NSRunningApplication.runningApplications(withBundleIdentifier: identity).count == 1,
                       "Stale Switcher selection cannot relaunch an exited app")
        } catch {
            for app in apps where !app.isTerminated { app.terminate() }
            try? await wait { apps.allSatisfy(\.isTerminated) }
            throw error
        }
        for app in apps where !app.isTerminated { app.terminate() }
        try await wait { apps.allSatisfy(\.isTerminated) }
        print("PASS: \(checks) Dock-reopen checks against disposable app copies; all fixtures quit.")
        return checks
    }
}
#endif
