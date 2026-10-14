import AppKit
import Carbon

/// A Dock click sends `aevt/rapp`, leaving window creation/restoration to the app.
/// Address the selected process, not its bundle ID or URL: this cannot launch an
/// exited Switcher item or accidentally reopen another installed copy.
enum ApplicationReopener {
    static func send(to processIdentifier: pid_t) -> String? {
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: processIdentifier),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(boolean: true), forKeyword: AEKeyword(kAEApplicationActivationExpected))
        do {
            // Do not wait for the target's UI, a reply, or a save/open dialog.
            _ = try event.sendEvent(options: [.noReply, .canInteract, .canSwitchLayer, .dontRecord], timeout: 1)
            return nil
        } catch { return error.localizedDescription }
    }
}
