# Verification record

## September 30, 2026 — 1.2.0 (12)

- Passed 18,548 geometry/preferences/scroll/pending-quit checks and 3,863 native window/lifecycle checks, plus shortcut/runtime suites and harmless Trash simulations. Native tests exercise both instant and animated cycles, comma-key routing, live list identity preservation, and safe removal of the selected item.
- Dense-editor tests cover 8/16/24 apps across diameter/thickness endpoints, verifying the current remove control wins over adjacent sectors. Pending-quit fixtures cover immediate omission, rejection, bounded expiry, and overlapping deadlines. New preferences migrate from older exports and round-trip independently.
- A disposable safe UI session verified removal of the intended item from a 24-app launcher; inspected compact Pinned Trash controls and the fixed Apps header; changed Less animation and wheel haptics; verified Preview haptics remains independently enabled on Appearance. Appearance fits without scrolling. The test app was quit afterward; real preferences and live app/Trash actions were not changed.
- Packaging and installation use byte/signature verification, source freshness manifests, extracted-archive verification, and recoverable previous installations. Results live in local Build logs, build-manifest.json, Deployments receipts, and Dist/SHA256SUMS, not public personal files.
- Remaining manual acceptance: physical haptic feel, actual quit/cancel timing with disposable apps, clean-account permissions/Gatekeeper, real Fn input, multiple displays/Spaces, Intel hardware, and downloaded-archive launch. Automated checks do not certify these or guarantee security. This release is ad-hoc signed and not notarized.

## September 30, 2026 — 1.1.4 (11)

- Regression run: 18,126 pure geometry/preferences/scroll/burst checks and 3,860 native window/lifecycle checks, plus shortcut/runtime suites and harmless Trash simulations. The native checks now include 100 instant show/select/hide cycles, synchronous panel disappearance, and exactly-once selection consumption, alongside the existing animated-cycle and comma-key paths.
- New pure tests cover all four preview boundaries for finite and unlimited reach; live wheel geometry remains unchanged. Rapid-input tests distinguish a single fast open/release pair from repeated bursts and confirm recovery after quiet. Scroll tests cover accumulated trackpad steps, direction reversal, wheel notches, momentum suppression, and large-event pulse limiting.
- Isolated UI session: dragged Apps Launcher → Quitter → Launcher with stable header/window geometry, checked the new Hold/Toggle control, scrolled Launcher diameter 300 → 320 and back, changed preview background, inspected Advanced's creator credit, and changed the shared haptic toggle. All customization used a disposable defaults domain; the diagnostic app was quit afterward.
- Preview haptic calls are gated by enabled preferences and a newly selected non-nil sector; physical feedback/trackpad feel remains manual. No live app launch/termination, Finder close-all, or Trash operation was executed. Physical shortcut-spam timing, multi-display optical quality and sandbox feasibility remain acceptance work, not claims inferred from compilation.
- Glass adjustments are a restrained diffusion floor and softened vector rim, not higher-resolution screen capture or a private shader. Native compositor quality remains macOS-controlled; zero grain or exact iOS optical equality is not claimed. Privacy and distribution notes reflect the present implementation and Apple's public guidance.

## September 30, 2026 — 1.1.3 (10)

- `make verify` passed: 18,089 geometry/preferences checks, 3,567 native window/preview/lifecycle checks, shortcut/runtime tests, and harmless Trash simulations.
- Automated checks cover tint validation and immediate fresh-defaults readback, migration from configurations without tint/quit-mode fields, and all Finder/regular/force quit routing combinations. Finder AppleScript is syntax-compiled only; no live Finder windows, apps, or Trash were closed by testing.
- Native pointer tests exercise arming on entry, scaled coordinate conversion beyond the preview bounds, 1200-point versus unlimited reach, and event-monitor teardown. Existing keyboard, native annulus, lifecycle, and 100 rapid-wheel-cycle regressions remain in the verification run.
- Isolated safe UI sessions verified both drag switches change preview mode, Appearance fits all controls without a scroll container, Color/Text background switching, glass detent updates, shortcut/Appearance confirmation dialogs and cancellation, and the regular/force quit toggle and explanatory text. UI test preferences do not alter the user's configuration. The midpoint change is in the drag-change handler, not just drag-end; physical continuous-drag feel remains a user acceptance check.
- Native color wells were present and RGB persistence is tested; full color-panel interaction was not conclusively verified by automation. Glass changes are deliberately limited to softer vector contour highlights. A trial blur on the glass layer was removed after it interfered with backdrop sampling. Native compositor resolution cannot be increased through a public sampling-quality control, so no zero-pixelation or exact iOS match is claimed.
- Version/build: 1.1.3 (10). Final signed release and Applications equality are recorded by `make install` / `make status`; previous installed bundles remain backed up. Diagnostic instances are closed after inspection.

## September 29, 2026 — 1.1.2 (9)

- The full regression suite passed after the scalable-material update: 18,076 geometry/preferences checks, native lifecycle/annulus checks, shortcut/runtime checks, and harmless Trash simulations.
- New pure checks cover all 21 glass stops, the 36–78 pt thickness stops, legacy preset migration, persistence, bounds rejection, proportional icon scaling, and hit-testing on every diameter/thickness combination.
- Safe UI inspection verified the Appearance preview switch and Apps switch remain accessible after the draggable control change. The preview now grows to actual size when possible; the largest wheel is proportionally scaled only when needed. No launch, quit, or Trash action was executed.
- Production installation below is generated from this source revision and will be checked by complete bundle hashes and codesign verification. Haptic feel, Fn/trackpad timing, and exact backdrop optics still require physical acceptance.

## September 29, 2026 — 1.1.1 (8)

- `make verify` passed: 17,081 geometry/preferences/detent checks, 3,560 native window/contour/lifecycle checks (including 100 rapid wheel cycles), shortcut/runtime suites, and harmless Trash simulations.
- New tests cover every slider stop in both directions, duplicate samples within a stop, endpoints, the Unlimited sentinel, and defaults. Native Core Graphics containment checks sample both sides of the continuous annulus at 240, 300, and 520 pt across 360 angles. Haptic requests follow the same tested value-change gate; physical feedback cannot be felt by automation.
- Live isolated UI checks covered all four pages, switching Appearance to Quitter, diameter stepping 300 → 320 → 520, dead-zone 82 → 80, reach Unlimited → 2000, and glass Translucent → Default. The largest Quitter preview remained contained. Final compact Appearance was inspected with all controls and Reset visible. Apps/Trash and Advanced layouts were checked; preview actions never execute real launch/quit/Trash operations.
- Rechecked actual comma delivery from a safe Launcher panel into the Settings window. Held shortcut state was supplied internally, not with physical Fn input. Existing native tests also cover the Quitter route.
- Active-window visual comparisons over colored/text content showed a continuous optical contour without the former 96 repeating lens joins, with progressively stronger diffusion and weaker glass contribution. The native effect changes when a window is inactive; visual QA must inspect an active wheel. Native optical sampling remains system-controlled, and this does not certify exact iOS rendering or all desktop/background combinations.
- Diagnostic processes are bounded. The final isolated UI session was quit with its debug-only Command-Q command; temporary settings were discarded. User customization was not reset. Final release provenance, signed bundle equality, and Applications deployment are checked with `make install` and `make status`.

Rendering reference: [Apple's public custom-shape Liquid Glass API](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views). No private filters, screen recording, or fixed-resolution claims are used.

## September 29, 2026 — 1.1.0 (7)

- Safe regression pass: 16,941 geometry/preferences checks and 317 native window/lifecycle checks, alongside shortcut/runtime suites and harmless Trash simulations. The new tests deliver comma through actual WheelPanel key handling with no global tap, for both wheel types, including Fn-less key snapshots and swallowed key-up.
- In a bounded --ui-test session, computer-use comma presses opened the real Settings window from both visible Launcher and Quitter panels. These sessions supplied the held chord internally; the physical Fn key/trackpad combination remains a hardware acceptance check.
- Live UI checks: dragged Notes into the first slot; removed it with the visible ×; added an installed .app through the native picker; saw the wheel reflow; changed Trash from bottom to top and hid it; changed glass and diameter through accessible controls. Test changes used a disposable defaults domain, not the user's saved configuration.
- The old running debug process reported version 1.0.3. It was stopped before checking rebuilt copies. A passing installed bundle check alone does not replace an already-running process.
- A live patterned-background comparison showed native lensing at the merged inner and outer contours. Removed per-piece tint after this check exposed additive whitening; face tint is now applied once. The native contour approximates an annulus with 96 overlapping circles (sub-point contour error at supported diameters). Appearance depends on actual backdrop/OS rendering; no pixel-identical iOS claim.
- Current release checks and installed-file hashes are recorded by make install and make status. All diagnostic processes are closed after checking. No live launch, force quit, or Empty Trash action was executed.

Implementation references: [Apple custom Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [native glass containers](https://developer.apple.com/documentation/appkit/nsglasseffectcontainerview), and [Apple remove-app controls](https://support.apple.com/en-mt/guide/iphone/iph248b543ca/ios). Removal here changes only the wheel configuration; it never uninstalls an app.

## September 28, 2026 — 1.0.4 (6)

- `make verify` passed: shortcut/configuration checks, 16,932 geometry/persistence checks, harmless Trash simulations, and 311 native lifecycle checks including same-turn reveal and 100 rapid wheel cycles.
- Release compilation passed with the production source path. Launcher actions now resolve the target bundle identifier, activate all windows for running apps, and activate newly opened apps after launch; no live app launch, force-quit, or Trash action was used as an automated test.
- Wheel tracking samples the pointer immediately after ordering the panel front, then continues at 120 Hz while visible. The collapse order-out is guarded and scheduled one display frame later to avoid stale flashes during handoff.
- The host Xcode installation continues to emit its known CoreDevice/CoreSimulator compatibility warnings; they do not fail the macOS build or native self-test.

## September 28, 2026 — 1.0.3 (5)

- Synthetic event-tap checks pass for comma from both Launcher and Quitter, including a comma event with and without Fn flags, repeated key-downs, consumed key-up, and no selection commit. The direct main-queue fallback is idempotent.
- The installed build is version 1.0.3 (5) after `make install`; future status checks compare its complete bundle hash to the release manifest.

## September 28, 2026 — 1.0.2 (4)

- `make verify` passed with 16,932 geometry/persistence checks, the shortcut/runtime suites, harmless Trash simulations, and 310 native lifecycle checks including all three glass finishes.
- A live native comparison over patterned/colorful content showed refraction at both contours of Very Liquid, preserved Default, and the softened Translucent preset. Static view-cache exports were not used as evidence of backdrop appearance.
- Exercised all three slider positions in the actual Appearance UI; labels and accessibility values updated correctly. Restored Default after the check. Appearance controls remain reachable in the scrollable pane.
- New and legacy preference files preserve Default, and every preset round-trips through persistence. Native glass uses public SwiftUI/AppKit APIs; no additional pointer timers, screen recording, or private filters were added.
- Debug and universal Release are generated from the same sources. Applications deployment is verified by exact file hashes and signing. The removed optional `/Applications/Halo.app` duplicate is not recreated. Historical backups and the approved baseline remain historical artifacts.
- Test processes were closed after inspection. The native macOS material responds to desktop content and accessibility preferences; an exact iPhone compositor match is not claimed.

## September 28, 2026 — 1.0.1 (3)

- `make verify` passed: shortcut/configuration checks, event routing, harmless Trash simulations, 16,928 geometry/persistence checks, and 307 native window/lifecycle checks.
- Real runtime input handlers were called with unposted keyboard events. Comma was checked from Launcher and Quitter, with and without Fn in the comma event's modifier snapshot, including repeat/key-up consumption. A separate native integration check followed both engine Settings effects through to an active Settings window.
- Both release orders were tested at gaps of 0–39 ms. Returning deliberately after 40 ms opens Launcher. 100 queued shortcut sessions and 100 native wheel cycles left no stale selection/window; invisible sessions did not commit.
- Settings has a native hit target across a 285-point grid, activates as the key window, preserves position on reopening, and closes after testing. Safe-mode visual inspection confirmed full-height glass and all Appearance controls fitting in the window. The dynamic toggle and finite/∞ slider endpoint were exercised and restored to their starting values.
- Dynamic lift boundaries, monotonic movement, finite/unlimited selection, legacy preference migration, relaunch persistence, and JSON round trips passed.
- Test apps were terminated after inspection. No live force-quit, Trash, or application-launch action was executed. Physical Fn timing and subjective animation/haptic feel still require the user's keyboard/trackpad trial.
- Release/deployment hashes are recorded by `make install` in `Build/Release/build-manifest.json` and `Deployments/`; `make status` checks the installed app against the release.

## September 27, 2026 — reconstruction

## Passed

- Native Debug build and optimized universal **arm64 + x86_64** Release build through the shared Xcode target. Swift 6 strict concurrency and compiler warnings treated as errors.
- 16,661 geometry/selection/layout/persistence assertions: all sectors and wrap boundaries for 1–64 items in both orientations, neutral and outer boundaries, clamping, invalid values, save/reload, duplicate app rejection, corrupt preference recovery.
- Inherited shortcut-state regression suite: exact chords, hold/toggle, Fn/Control transitions, Settings, cancellation, recording suppression, rapid release and config replacement.
- Rebuilt runtime handoff tests, using a disposable defaults domain and no event tap/input posting.
- 12 native panel/controller checks, including 100 rapid show/select/cancel cycles, cancelled reveals, stale-hide invalidation, empty lists, transparent panel geometry, neutral release and once-only commit.
- Four harmless Finder-script simulations: empty, success, cancellation and error. The live script is syntax-compiled, never executed against Finder by the test suite.
- Live native Settings General/Appearance/Apps inspection and Launcher/Quitter previews. Compared Launcher on the recording's background against the supplied frames/screenshots. Checked the Trash anchor/selected appearance and dynamic Quitter ordering.
- Ad-hoc code signature verification. Dependency inspection: only platform libraries, no `HaloLatency.dylib` or reference-binary dependency. Reference images/video are not bundled.
- Parent project `make doctor`, `make test`, `make status` all still pass. Installed and maintained app contents still match, with current parent sources unchanged.

## Preservation checks

| Artifact | SHA-256 |
| --- | --- |
| Parent Baseline/Halo-0.1.3.zip | `03f3bac4622940234645345badc1705c444892dde9c1b319dc6be068e7c73843` |
| Parent Baseline/manifest.json | `711d1ff66c3a470cfaf138b801d362f421570f2cb9076b60d13414bd2413b2f8` |
| Parent Latest and Applications executable | `109019b36b8d2820caa47c52046cc69b98347dfac7801c0df952792f91bdb7e1` |

The current rebuilt artifact's source/app hashes are generated by `make release` in `Build/Release/build-manifest.json`. `make status` checks that those exact bytes still match. Source snapshots include their own manifest, not the local reference binaries or recordings.

## Not claimed

No live Empty Trash or force-quit test was performed. Global permission recovery, physical Fn/trackpad behavior, all Spaces/display arrangements and a clean-machine/Intel acceptance pass remain manual. Visual inspection is not a pixel-perfect guarantee. No App Store approval, sandbox compatibility, Developer ID distribution signature or notarization is claimed.

Host tooling currently reports a CoreDevice symbol mismatch and an out-of-date CoreSimulator framework. This does not prevent the tested native macOS builds, but should be resolved before depending on additional release tooling. No system tooling was modified to hide those warnings.
