import AppKit

@MainActor final class ActionService {
    let safeMode: Bool
    var forceQuitApps: (String?) -> Bool = { _ in true }
    private(set) var trashPending = false
    private var pending = PendingQuitTracker()
    var quitStateChanged: (() -> Void)?
    var pendingQuitIDs: Set<pid_t> { pending.active(at: ProcessInfo.processInfo.systemUptime) }
    init(safeMode: Bool) { self.safeMode = safeMode }

    func prepare(_ item: WheelItem) {
        guard !safeMode, case .quit(let application) = item.action,
              application.bundleIdentifier != "com.apple.finder", !application.isTerminated else { return }
        let pid = application.processIdentifier
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        pending.begin(pid, until: deadline)
        quitStateChanged?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.pending.expire(at: ProcessInfo.processInfo.systemUptime)
            self.quitStateChanged?()
        }
    }
    private func failedQuit(_ application: NSRunningApplication) {
        pending.remove(application.processIdentifier); quitStateChanged?()
    }

    func perform(_ item: WheelItem) {
        guard !safeMode else { print("SAFE PREVIEW: \(item.name), no action executed"); return }
        switch item.action {
        case .launch(let url, let bundleIdentifier):
            // Match the behavior users expect from an app switcher: a running
            // application is activated with all of its windows; only an app
            // that is not running is launched from disk.
            if let running = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated &&
                $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath() == url.standardizedFileURL.resolvingSymlinksInPath()
            }) {
                running.activate(options: [.activateAllWindows])
                return
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            // Launch the chosen copy if another variant with the same bundle
            // identifier is already running at a different location.
            configuration.createsNewApplicationInstance = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
            }
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { application, error in
                application?.activate(options: [.activateAllWindows])
                if let error { Task { @MainActor in Self.report("Could not open \(item.name)", detail: error.localizedDescription) } }
            }
        case .quit(let application):
            guard !application.isTerminated else { return }
            if !pendingQuitIDs.contains(application.processIdentifier) { prepare(item) }
            switch QuitDisposition.resolve(bundleIdentifier: application.bundleIdentifier, force: forceQuitApps(application.bundleIdentifier)) {
            case .closeFinderWindows:
                Task {
                    let error = await Task.detached(priority: .utility) {
                        Self.runScriptSource("tell application \"Finder\" to close every window")
                    }.value
                    if let error { Self.report("Could not close Finder windows", detail: error) }
                }
            case .normal:
                if !application.terminate() { failedQuit(application); Self.report("Could not quit \(item.name)", detail: "The application may need you to save a document or confirm quitting.") }
            case .force:
                if !application.forceTerminate() { failedQuit(application); Self.report("Could not force quit \(item.name)", detail: "macOS did not permit this action. You can use Apple menu → Force Quit.") }
            }
        case .emptyTrash:
            guard !trashPending else { return }
            guard let url = Bundle.main.url(forResource: "EmptyTrash", withExtension: "applescript") else {
                Self.report("Empty Trash is unavailable", detail: "The app's Trash script is missing."); return
            }
            trashPending = true
            Task {
                let error = await Task.detached(priority: .utility) { Self.runScript(url) }.value
                trashPending = false
                if let error { Self.report("Could not empty Trash", detail: error) }
            }
        }
    }

    /// All waiting and I/O is off the UI/event-tap thread. Does not retry a destructive action.
    nonisolated private static func runScript(_ url: URL) -> String? {
        runScriptArguments([url.path])
    }
    nonisolated private static func runScriptSource(_ source: String) -> String? {
        runScriptArguments(["-e", source])
    }
    nonisolated private static func runScriptArguments(_ arguments: [String]) -> String? {
        let process = Process()
        let errors = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = arguments
        process.standardError = errors; process.standardOutput = output
        do {
            try process.run()
            process.waitUntilExit()
            let detail = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Finder reported an error."
            return process.terminationStatus == 0 ? nil : detail
        } catch { return error.localizedDescription }
    }

    private static func report(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title; alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
