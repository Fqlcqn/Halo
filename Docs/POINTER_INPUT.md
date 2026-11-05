# Pointer input investigation

## November 4, 2026 — same keys with Halo quit

The user repeated the same angled-thumb contact with Halo fully quit. The pause still occurred, especially with Fn+Control held. Occasionally motion began immediately, then stopped after roughly a centimeter. This establishes that the reported pause can occur independently of Halo. It does not identify the exact macOS contact-classification or hardware cause.

The existing focus-preserving, non-consuming mouse path remains in place. No public per-app trackpad setting in this project bypasses macOS contact recognition. Changing Halo's hover timer or injecting cursor movement would not recover contact data that macOS has not delivered.

When convenient, try a recorded shortcut that does not use Fn in General, or the existing Toggle activation mode so the keys can be released before touching the trackpad. These are workarounds to evaluate, not verified fixes. This release leaves the user's shortcuts, activation modes and system trackpad preferences unchanged.

The separate accidental arrow-key activation has a concrete software cause and fix in 1.4.6. Apple's [function modifier documentation](https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.struct/function) includes navigation keys. Halo now tracks physical Fn transitions separately instead of treating that flag on ordinary keys as a held Fn key.

## Report and evidence

The reported symptom is a roughly half-second pause of the actual macOS cursor
when a sideways left thumb contacts the trackpad just after opening any wheel.
An upright finger works immediately, and ordinary desktop thumb movement works.
This is different from the pointer moving while Halo's highlight lags.

Source inspection found no cursor warp, cursor association/disassociation, mouse
motion suppression, movement threshold on the cursor, or half-second input gate.
The shortcut tap observes keys, modifier changes and left-button events; it does
not intercept mouse movement. The 40 ms shortcut subset-release guard applies
to changing wheels, not pointer motion. Reveal already permits selection before
its 105 ms animation completes. Selection haptics occur on sector changes, not
when an initially centered wheel opens.

Every wheel did unconditionally call `makeKey()` on its nonactivating panel,
even with a working global event tap. This changed keyboard focus at the same
time the thumb contact began, despite the tap already handling all wheel keys.
That unnecessary transition is removed in the authorized path. It is a plausible
contributor, not a proven explanation for the physical cursor pause.

Apple documents that the trackpad maps contacts to mouse events and can withhold
mouse movement during a recognized scroll gesture. These system-level decisions
are distinct from Halo's hover selection. No contact trace was captured in this
investigation, so palm/thumb rejection or gesture classification is not asserted
as the diagnosed cause. See Apple's [trackpad event guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html).

## Implementation

- All three wheels preserve keyboard focus when `HaloRuntime.inputReady` reports
  an enabled event tap. Their panels cannot become key on click in that path.
  The keyboard-monitor fallback retains the native key panel for comma/Escape.
- Local and global mouse move/drag monitors sample selection immediately. A
  120 Hz common-mode timer remains a fallback. Neither monitor consumes motion.
  AppKit requires both monitors to cover this app and other apps; see Apple's
  [event monitoring guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html).
- All paths sample the current desktop pointer rather than queued, window-relative
  coordinates. Unchanged positions skip work. Closing stops monitors and polling;
  generation and revealed-state checks reject stale work. Commit still samples
  the latest pointer synchronously before choosing an item.
- No system trackpad settings, contact filtering, force-click behavior, pointer
  speed, user shortcuts, dead zones, animations or haptic preferences change.
- A separate regression uncovered during click-path testing blocked the next
  shortcut after clicking to confirm a wheel with no keys held. Confirmation now
  waits for release only when keys remain held; all three wheel routes are tested.

## Verification and physical acceptance

Native tests use an injected pointer source and unposted AppKit events. They
exercise immediate movement and all three drag types without waiting for a timer,
neutral return, focus preservation, fallback keyboard focus, animation on/off,
all coordinator routes, final sampling, 50 rapid tracked cycles, polling fallback,
and cleanup. Existing tests cover comma, Escape, Hold/Toggle, release orders,
handoffs, and harmless action fixtures. None simulates a physical thumb.

On the installed app, repeat the original sideways-thumb motion immediately
after Launcher, Quitter and Switcher open. Stay in the center or use Escape to
avoid committing an action. Compare thumb contact begun before versus after the
shortcut, and verify comma, Escape, toggle clicks and wheel handoffs.

If the actual arrow still pauses, compare the same thumb placement with the same
modifier keys held after quitting Halo, then reopen `/Applications/Halo.app`.
This controls for keyboard-related trackpad filtering; ordinary desktop movement
without the chord does not. Also compare opening from the menu without holding
keys. The result determines the next investigation rather than assuming a slower
selection timer or changing system-wide trackpad settings. Physical acceptance
of the reported freeze remains pending until tested by the user.
