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

    static func isUserWindow(role: String?, subrole: String?, hasControls: Bool, canRaise: Bool) -> Bool {
        guard role == kAXWindowRole, canRaise else { return false }
        return [kAXStandardWindowSubrole, kAXDialogSubrole, kAXFloatingWindowSubrole].contains(subrole ?? "") || hasControls
    }

    private static func isSelectable(_ element: AXUIElement) -> Bool {
        var actions: CFArray?
        let canRaise = AXUIElementCopyActionNames(element, &actions) == .success &&
            (actions as? [String])?.contains(kAXRaiseAction) == true
        let subrole = attribute(element, kAXSubroleAttribute) as? String
        let hasControls = [kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXZoomButtonAttribute]
            .contains { attribute(element, $0) != nil }
        return isUserWindow(role: attribute(element, kAXRoleAttribute) as? String,
                            subrole: subrole, hasControls: hasControls, canRaise: canRaise)
    }

    private static func liveWindowIDs(processID: pid_t) -> Set<CGWindowID> {
        let rows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(rows.compactMap { row in
            guard (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == processID,
                  (row[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (row[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0 > 0,
                  let id = row[kCGWindowNumber as String] as? NSNumber else { return nil }
            return id.uint32Value
        })
    }

    // Reject absent capture content, not legitimately blank/white/black windows.
    static func hasVisiblePixels(_ image: CGImage) -> Bool {
        var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: 32, height: 32,
                                          bitsPerComponent: 8, bytesPerRow: 128,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 32, height: 32))
            return stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] > 0 }
        }
    }

    static func retainingLiveWindows(_ previews: [Self], ids: Set<CGWindowID>, elements: [AXUIElement]) -> [Self] {
        var seenIDs: Set<CGWindowID> = []
        var seenElements: [AXUIElement] = []
        return previews.filter { preview in
            guard ids.contains(preview.id), elements.contains(where: { CFEqual($0, preview.element) }),
                  !seenIDs.contains(preview.id), !seenElements.contains(where: { CFEqual($0, preview.element) }) else { return false }
            seenIDs.insert(preview.id); seenElements.append(preview.element)
            return true
        }
    }

    static func load(app: NSRunningApplication) async -> [Self] {
        guard !app.isTerminated, AXIsProcessTrusted(), CGPreflightScreenCaptureAccess(),
              let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false),
              !Task.isCancelled else { return [] }
        let process = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(process, 0.15)
        guard let listed = attribute(process, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        let windows = listed.filter { isSelectable($0) }
        let liveIDs = liveWindowIDs(processID: app.processIdentifier)
        let eligible = content.windows.filter { $0.owningApplication?.processID == app.processIdentifier && $0.windowLayer == 0 && !$0.frame.isEmpty && liveIDs.contains($0.windowID) }
        // SC and AX have no shared public window-ID accessor. Accept only
        // one-to-one matches, even for identical browser titles or stacked windows.
        let records = windows.map { (element: $0, frame: bounds($0), title: attribute($0, kAXTitleAttribute) as? String) }
        let matches = records.compactMap { record -> (AXUIElement, SCWindow)? in
            func sameFrame(_ lhs: CGRect?, _ rhs: CGRect) -> Bool {
                guard let lhs else { return false }
                return abs(lhs.minX - rhs.minX) <= 2 && abs(lhs.minY - rhs.minY) <= 2 &&
                    abs(lhs.width - rhs.width) <= 2 && abs(lhs.height - rhs.height) <= 2
            }
            let byFrame = eligible.filter { sameFrame(record.frame, $0.frame) }
            let byTitle = eligible.filter { record.title?.isEmpty == false && $0.title == record.title }
            let both = byTitle.filter { sameFrame(record.frame, $0.frame) }
            if both.count == 1 { return (record.element, both[0]) }
            if byTitle.count == 1 && records.filter({ $0.title == record.title }).count == 1 &&
                (byFrame.isEmpty || byFrame.contains(where: { $0.windowID == byTitle[0].windowID })) {
                return (record.element, byTitle[0])
            }
            if byFrame.count == 1 && byTitle.isEmpty &&
                records.filter({ sameFrame($0.frame, byFrame[0].frame) }).count == 1 {
                return (record.element, byFrame[0])
            }
            return nil
        }
        let unique = matches.filter { candidate in matches.filter { $0.1.windowID == candidate.1.windowID }.count == 1 }
        guard unique.count >= 2 else { return [] }
        var previews: [Self] = []
        for (element, window) in unique {
            guard !Task.isCancelled, !app.isTerminated else { return [] }
            let config = SCStreamConfiguration()
            let scale = min(1, 512 / max(window.frame.width, window.frame.height))
            config.width = max(1, Int(window.frame.width * scale))
            config.height = max(1, Int(window.frame.height * scale))
            config.showsCursor = false
            config.ignoreShadowsSingleWindow = true
            let filter = SCContentFilter(desktopIndependentWindow: window)
            if let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config),
               hasVisiblePixels(image) {
                previews.append(Self(id: window.windowID, image: image, element: element, app: app))
            }
        }
        // Capturing is asynchronous: a transient surface or closed window may
        // disappear while other thumbnails are being produced. Check both
        // public identities again before exposing any sectors to the user.
        guard !Task.isCancelled, !app.isTerminated,
              let current = attribute(process, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        let validated = retainingLiveWindows(previews, ids: liveWindowIDs(processID: app.processIdentifier),
                                             elements: current.filter { isSelectable($0) })
        return validated.count >= 2 ? validated : []
    }
}
