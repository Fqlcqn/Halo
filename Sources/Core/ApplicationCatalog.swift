import AppKit

@MainActor final class ApplicationCatalog {
    private var launcherCache: [WheelItem] = []
    private var cachedTargets: [LauncherTarget] = []
    private var updated = Date.distantPast
    private var observers: [NSObjectProtocol] = []
    private var quitterIcons: [pid_t: NSImage] = [:]
    private var launcherIcons: [String: NSImage] = [:]
    var runningAppsChanged: (() -> Void)?

    init() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updated = .distantPast; self?.runningAppsChanged?() }
            })
        }
    }

    func launcher(targets: [LauncherTarget]) -> [WheelItem] {
        if targets == cachedTargets, Date().timeIntervalSince(updated) < 30 { return launcherCache }
        launcherCache = targets.compactMap { target in
            guard let url = Self.url(for: target) else { return nil }
            let icon = launcherIcons[url.path] ?? NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 256, height: 256)
            launcherIcons[url.path] = icon
            return WheelItem(id: target.id, name: target.name, icon: icon, action: .launch(url, bundleIdentifier: target.resolvedBundleIdentifier))
        }
        cachedTargets = targets
        let paths = Set(launcherCache.compactMap { item -> String? in
            if case .launch(let url, _) = item.action { return url.path }; return nil
        })
        launcherIcons = launcherIcons.filter { paths.contains($0.key) }
        updated = Date()
        return launcherCache
    }

    static func url(for target: LauncherTarget) -> URL? {
        if let data = target.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale),
               FileManager.default.fileExists(atPath: url.path), Bundle(url: url)?.bundleIdentifier == target.resolvedBundleIdentifier { return url }
        }
        if let path = target.applicationPath {
            let url = URL(fileURLWithPath: path)
            // A missing explicit variant must not silently launch a different copy.
            return Bundle(url: url)?.bundleIdentifier == target.resolvedBundleIdentifier ? url : nil
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.resolvedBundleIdentifier)
    }

    func quitter(showsTrash: Bool = true, excluding: Set<pid_t> = []) -> [WheelItem] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != ownPID && !excluding.contains($0.processIdentifier) && $0.bundleIdentifier != Bundle.main.bundleIdentifier &&
            $0.activationPolicy == .regular && !$0.isTerminated && !($0.localizedName ?? "").isEmpty
        }.sorted {
            if ($0.processIdentifier == frontPID) != ($1.processIdentifier == frontPID) { return $0.processIdentifier == frontPID }
            return ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending
        }
        let trash = WheelItem(id: "action:empty-trash", name: "Empty Trash", icon: nil, action: .emptyTrash)
        let livePIDs = Set(running.map(\.processIdentifier))
        quitterIcons = quitterIcons.filter { livePIDs.contains($0.key) }
        return (showsTrash ? [trash] : []) + running.map { app in
            let icon = quitterIcons[app.processIdentifier] ?? app.icon ?? app.bundleURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
            icon?.size = NSSize(width: 256, height: 256)
            quitterIcons[app.processIdentifier] = icon
            return WheelItem(id: "pid:\(app.processIdentifier)", name: app.localizedName ?? "Application", icon: icon, action: .quit(app))
        }
    }

    func stop() {
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }
}
