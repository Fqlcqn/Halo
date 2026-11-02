import AppKit
import ScreenCaptureKit

struct WindowPreview: Identifiable, @unchecked Sendable {
    // Immutable snapshot. AX messaging runs off the event-tap thread.
    let id: CGWindowID
    let image: CGImage
    let element: AXUIElement
    let app: NSRunningApplication

    func raise() async {
        guard !app.isTerminated else { return }
        let canRaise = await Task.detached {
            guard Self.attribute(element, kAXRoleAttribute) as? String == kAXWindowRole else { return false }
            if Self.attribute(element, kAXMinimizedAttribute) as? Bool == true {
                guard AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else { return false }
            }
            return AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
        }.value
        if canRaise && !app.isTerminated {
            await MainActor.run { _ = app.activate(options: []) }
            await Task.detached {
                _ = AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
                _ = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
            }.value
        }
    }

    private static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
        return result
    }

    private static func bounds(_ window: AXUIElement) -> CGRect? {
        guard let p = attribute(window, kAXPositionAttribute), let s = attribute(window, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
              AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    static func load(app: NSRunningApplication) async -> [Self] {
        guard !app.isTerminated, AXIsProcessTrusted(), CGPreflightScreenCaptureAccess(),
              let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false),
              !Task.isCancelled else { return [] }
        let process = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(process, 0.15)
        guard let windows = attribute(process, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        let eligible = content.windows.filter { $0.owningApplication?.processID == app.processIdentifier && $0.windowLayer == 0 && !$0.frame.isEmpty }
        // SC and AX have no shared public window-ID accessor. Accept only
        // one-to-one matches, even for identical browser titles or stacked windows.
        let matches = windows.compactMap { element -> (AXUIElement, SCWindow)? in
            guard let frame = bounds(element) else { return nil }
            let sameFrame = eligible.filter {
                abs($0.frame.minX - frame.minX) <= 1 && abs($0.frame.minY - frame.minY) <= 1 &&
                abs($0.frame.width - frame.width) <= 1 && abs($0.frame.height - frame.height) <= 1
            }
            let title = attribute(element, kAXTitleAttribute) as? String
            let titled = sameFrame.filter { title != nil && $0.title == title }
            let candidates = titled.isEmpty ? sameFrame.filter {
                title?.isEmpty != false || $0.title?.isEmpty != false
            } : titled
            guard candidates.count == 1 else { return nil }
            return (element, candidates[0])
        }
        var previews: [Self] = []
        for (element, window) in matches {
            guard !Task.isCancelled, !app.isTerminated else { return [] }
            guard matches.filter({ $0.1.windowID == window.windowID }).count == 1 else { continue }
            let config = SCStreamConfiguration()
            let scale = min(1, 256 / max(window.frame.width, window.frame.height))
            config.width = max(1, Int(window.frame.width * scale))
            config.height = max(1, Int(window.frame.height * scale))
            config.showsCursor = false
            config.ignoreShadowsSingleWindow = true
            let filter = SCContentFilter(desktopIndependentWindow: window)
            if let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) {
                previews.append(Self(id: window.windowID, image: image, element: element, app: app))
            }
        }
        return previews
    }
}
