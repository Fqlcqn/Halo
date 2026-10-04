# Changelog

## 1.2.4 (16) — safe default for Quitter, 2026-10-03

- Quitter now uses regular Quit by default, allowing apps to save or ask before closing. Advanced → Force quit apps remains available for users who deliberately want force quitting globally.
- Existing version 1 settings migrate to the new regular-Quit default; explicit per-app Quit/Force quit choices are preserved. Finder continues to close its windows rather than terminating.

## 1.2.3 (15) — two-item rotation and per-app quitting, 2026-10-03

- Opposite highlight sectors follow the pointer's side of travel, allowing full clockwise and counterclockwise rotations with one app plus Trash. The same geometry is used in previews.
- Apps → Quitter now offers per-app Use default, Quit, and Force quit choices for running apps or a chosen .app. Rules persist immediately by bundle identifier, survive export/import, and apply across app restarts. Existing settings retain the Advanced global default; Finder always closes windows.
- Updated local app and source packages. Automated checks do not exercise real force quit or Empty Trash; physical interaction remains a manual acceptance check.

## 1.2.2 (14) — slightly faster animated reveal, 2026-10-01

- Shortened the normal wheel reveal from 120 ms to 105 ms. It remains a visible smooth fade-and-expand while feeling more immediate; Less animation remains instant.
- Updated the verified app, documentation, source archive, app archive, and checksums.

## 1.2.1 (13) — smoother wheel reveal, 2026-10-01

- Default Launcher and Quitter appearance now fades and expands from 95% size over 120 ms, replacing the nearly instant 32 ms reveal. Closing uses a brief 40 ms fade.
- A separate presentation state establishes the collapsed frame before opening, including reused panels. Input and release-to-select remain available immediately; no animation wait is imposed on selection.
- Less animation and macOS Reduce Motion bypass the staged reveal. Generation guards cancel old reveals/hides during rapid changes, and release before reveal cancels without a flash.
- Updated the app to 1.2.1 (13), local installation, source/app packages, and checksums. Existing 1.2.0 release archives remain available locally; publishing 1.2.1 on GitHub is a separate action.

## 1.2.0 (12) — Halo public-source preparation, 2026-09-30

- Official app, executable, source folder, and installation are now Halo. The former hybrid project is preserved as Halo Legacy; approved baseline archives are untouched. The internal bundle identifier stays unchanged for preferences/permission continuity.
- Added Advanced → Less animation, off by default. It selects instant versus smooth show/hide explicitly; removed automatic burst-mode switching while preserving immediate input and generation/commit-once guards.
- Added a shared Preview haptics preference to both preview pages, off by default and independent of actual wheel feedback. Settings migration preserves existing customization.
- Compacted Pinned Trash controls. Crowded launcher editors use actual icon rectangles and give the visible remove button priority, avoiding adjacent-sector theft; hovered controls render above their neighbors.
- Quit requests remove their PID from the live Quitter immediately, including immediate reopening. Workspace notifications refresh an already-open wheel with a short removal/reflow animation. Rejected requests return immediately; still-running/cancelled requests return after two seconds. Finder remains close-windows-only.
- Added source-available licensing credited to Maneesh Getni, security/contribution guidance, first-launch/permission documentation, and a GitHub release checklist. Private modifications are permitted; modified distributions require permission.
- Unified installation at /Applications/Halo.app with verified backups and removal of the superseded Production copy after successful installation. Public app/source ZIP packaging uses an explicit allowlist and verifies extraction, signatures, hashes, and checksums. Private references and local history are excluded.
- No notarization, independent security audit, or clean-Mac acceptance is claimed. App Store submission is deferred; physical haptics and permission-upgrade behavior remain manual checks.

## 1.1.4 (11) — bounded previews and rapid-input polish, 2026-09-30

- Preview selection clears when the pointer exits its square. Removed the global preview pointer monitors; actual launcher/quitter reach remains unchanged. Apps previews request one haptic on each newly selected sector when enabled.
- Apps uses a fixed window, header and preview footprint for both modes. Add apps stays in place (disabled for Quitter); only wheel content animates. Shared drag-across switches now serve preview modes/backgrounds, all customization toggles, and General's Hold/Toggle controls, with keyboard/VoiceOver access and no blue focus outline.
- Every appearance slider accepts discrete mouse-wheel/trackpad scrolling. Trackpad deltas accumulate to a 12-point step, momentum is ignored, endpoints clamp, and only a changed setting requests haptics. Pages themselves still do not scroll.
- Three visibility transitions separated by at most 140 ms activate instant show/hide during rapid repetition. Normal open/release retains motion, quiet restores it, and existing commit-once/generation/no-flash safeguards remain. WindowServer adds no separate ordering animation.
- Further softened contour highlights and added a tiny native diffusion floor to reduce clear-glass edge harshness without rasterizing the glass or claiming a selectable optical resolution.
- Advanced credits “Maneesh Getni.” Updated release/acceptance notes and privacy manifest (35F9.1 for local elapsed-event timing). App Store sandbox and distribution-identity blockers remain explicit.

## 1.1.3 (10) — customization and interaction fixes, 2026-09-30

- Preview mode switches change while dragging across the midpoint, with no blue focus ring; keyboard and accessibility controls remain available.
- Slightly brightened Settings and added independent Settings/selection-sector tint pickers. White preserves the default color treatment. Tints export/import with other preferences.
- Added a correctly positioned Default glass marker and Color, Text, and Grid Appearance backgrounds beneath the production wheel renderer. Softened contour highlights without rasterizing or filtering the native refractive glass layer; optical sampling resolution remains controlled by macOS.
- Removed Settings scrolling; resized Appearance and Advanced to fit their controls. Both preview pages track beyond their bounds, respecting finite or unlimited reach in real wheel points, including scaled previews. Event monitors are removed with the page.
- Preferences persist synchronously in control setters; shortcut changes also flush immediately. Appearance, Apps, and shortcut resets require confirmation with Cancel as the default action.
- Advanced offers regular or force quit (existing force-quit default retained). Finder always closes all its windows instead of terminating. Finder window control requires macOS Automation permission and reports errors; it never falls back to terminating Finder.

## 1.1.2 (9) — scalable wheel material and thickness, 2026-09-29

- Appearance now uses a 21-step liquid-to-diffused glass control. The range stays biased toward clear, water-like glass; every step is persisted and has one haptic detent.
- Added a 36–78 pt Wheel thickness control (66 pt default). The ring and icon size scale together in the real wheels and previews.
- Replaced the two-state preview pickers with draggable Launcher/Quitter switches, retaining keyboard and accessibility actions.
- Enlarged the Appearance preview to use actual wheel scale whenever it fits, and removed the extra empty Launcher area in Apps by using a compact adaptive page.
- Kept every material light: more diffusion now means softer background detail rather than a dark overlay. Native macOS rendering remains responsible for optical sampling and refraction.

## 1.1.1 (8) — settings polish, continuous glass and consistent detents, 2026-09-29

- Settings fits each page: compact General/Advanced, aligned shortcut cards, a two-column Appearance page, and a bounded Apps editor. Both preview pickers use compact, unlabeled segmented controls.
- Appearance now previews Launcher or Quitter, including pinned Trash. A constant preview scale makes every diameter step visibly change size, including the largest diameters. Preview actions remain harmless.
- Replaced 96 overlapping native glass circles with one continuous, oppositely wound elliptical annulus passed to Apple's public glassEffect API. This removes the repeated lens joins visible over text, keeps both boundaries and the open center, and eliminates 96 native glass subviews. No screen capture, private filters, bitmap upscaling or additional rendering timers.
- Presets now change native backdrop diffusion and lens visibility rather than adding white tint: Very Liquid uses lightly attenuated clear glass; Default combines moderate regular-material blur with clear lensing; Translucent uses full regular-material diffusion with a subdued glass edge. Thin half-point outlines and Reduce Transparency support remain.
- Every slider uses exact stops: diameter 20 pt, dead zone 2 pt, reach 100 pt plus Unlimited, and three glass positions. A single change gate couples each accepted stop to one haptic request; repeats inside a stop do nothing. Legacy saved values are not silently rounded on load, and feedback respects the existing toggle.
- Added exhaustive annulus/slider regression coverage and a clean Command-Q exit for isolated UI tests. Physical trackpad feel and subjective glass fidelity still require user acceptance; this is not an App Store certification.

## 1.1.0 (7) — live wheel customization and native keyboard capture, 2026-09-29

- Visible wheels now take keyboard focus through a nonactivating key panel. Comma reaches the existing cancel-and-open-Settings route even when macOS falls back to a global monitor that cannot consume another app's typing. Global event-tap handling remains in place. Opening Settings never commits the highlighted launch/quit/Trash action.
- Enlarged Settings to 860 × 760 pt, grouped and shortened Appearance/Advanced controls, and kept editor drags separate from window background dragging. Smooth size sliders give haptic detents at 25 pt for diameters and 5 pt for the dead zone; the Haptic feedback preference controls them.
- Apps now shows the real renderer: hover × removes Launcher items, drag inserts at another position with animated equal spacing, and context-menu/accessibility actions provide an alternative. Native Add Apps supports multiple .app bundles. Empty/missing-app states and the 24-item limit are handled. Dense wheels adapt icon size to avoid overlap.
- Chosen applications retain their exact path, bundle identifier and a file bookmark. Distinct copies with the same bundle ID can coexist; missing explicit copies are not silently replaced by another variant. Old bundle-ID-only preferences migrate unchanged.
- Added a harmless Quitter preview with Show Trash, fixed-sector highlight, and four pinned positions. The actual Quitter uses the same saved choices and hit-testing geometry.
- Replaced a masked glass disc / flat clear shape with an annulus merged inside NSGlassEffectContainerView. Native clear lenses now form both contours for every finish; tint is applied once over the merged face. The separate face inset is 0.75 pt instead of the previous 5 pt, with 0.5 pt outlines. Reduce Transparency still uses a solid ring.
- Cached Launcher icons across reorder operations. The editor uses event-driven pointer tracking and never invokes launch, quit, or Trash actions.
- Added isolated, auto-terminating UI diagnostics and native key-panel routing tests, plus variant persistence, pinned geometry, dense icons, and identity-based reorder coverage.

## 1.0.4 (6) — faster wheel input and all-window app activation, 2026-09-28

- Launcher selection now activates every window of an application that is already running, providing an app-switcher/Alt-Tab style workflow. Applications that are not running continue to launch normally and are activated after launch.
- Wheel reveal and the first pointer sample now happen synchronously when a tracked wheel is shown, so the first hover is available without waiting for a deferred state update or timer tick.
- Shortened the wheel collapse handoff to one display frame and tightened reveal/collapse animation durations while preserving generation guards against stale sessions.
- Added native self-test coverage for same-turn wheel reveal and retained the rapid-cycle, stale-hide, selection, and no-action regression checks.

## 1.0.3 (5) — visible-wheel Settings shortcut routing, 2026-09-28

- Made comma handling at the event-tap boundary direct and idempotent whenever Launcher or Quitter is active/visible. It now schedules Settings on the main AppKit queue in addition to the shortcut engine effect, so Fn flag snapshots and event-tap timing cannot drop the request.
- Tracks comma key-down/up explicitly, consumes key repeats and the matching key-up, clears buffered prefix input, and resets safely on sleep, permission recovery, or shutdown.
- Kept the pure shortcut-engine Settings route and regression coverage; no wheel action is committed when comma opens Settings.

## 1.0.2 (4) — wheel glass finishes, 2026-09-28

- Added an Appearance slider with exactly three positions: Very Liquid, Default, Translucent. Applies to Launcher and Quitter; saves, exports, and imports with customization. Existing settings retain Default.
- Very Liquid uses Apple's untinted clear SwiftUI glass on an actual annulus, allowing native refraction on both the inner and outer contours, fine specular edges, and a lighter selection highlight. No screen recording or private graphics APIs.
- Default preserves the previous native material, tint, veil and outline values. Translucent gently blends a denser native material over it for more diffusion while retaining visible background/refraction.
- Respect Reduce Transparency with a solid legible ring. Glass selection adds no polling timers or screen capture. Appearance scrolls to accommodate the additional setting.
- Added safe, automatically terminating three-finish visual diagnostics, migration/persistence checks, and native lifecycle checks for all finishes.
- Deployment continues to update Halo Production. `make status` now tolerates removal of the optional duplicate `/Applications/Halo.app`; ordinary install does not recreate it.

## 1.0.1 (3) — main Applications replacement, 2026-09-29

- Added `make install-main` to replace `/Applications/Halo.app` with the verified Halo Production release when explicitly requested.
- The replaced app is retained under `Backups/Installed/`, and a timestamped main-app deployment receipt is written under `Deployments/`.

## 1.0.1 (3) — window interaction and responsive wheels, 2026-09-28

- Settings uses a native titled window with full-size glass, a continuous clickable backing, and dragging on blank areas/header. Reopening brings it forward at its existing position.
- Routed the Settings key directly from either active wheel before interpreting modifier snapshots; comma repeats and key-up are consumed without committing a selection. Escape and Settings remain cancellation actions.
- Both shortcut handoff directions now commit the departing wheel's selection. Stale queued sessions cannot reveal or commit against a newer session.
- Removed the 24 ms reveal wait, shortened reveal/collapse to 45/25 ms, and reduced the subset-release guard from 120 to 40 ms. Opposite panels are removed immediately at handoff; existing icon images are reused.
- Appearance now distinguishes the center dead zone from maximum selection distance (100–2000 pt, then ∞; unlimited remains the default).
- Added optional Dynamic icon movement: pointer radius drives 0–8 pt outward movement from dead-zone edge to wheel edge, capped thereafter. Off retains fixed selection lift. Motion updates only icon views, ignores stationary pointers, stops tracking when hidden, and respects Reduce Motion.
- Existing saved customization and exported files migrate with unlimited range and dynamic movement off. New settings persist and export normally.
- Verified synthetic keyboard routing, both modifier release orders inside the 40 ms guard, rapid queued sessions, native Settings hit targets/lifecycle, distance bounds, and preference migration. Live destructive actions were not exercised.

## 1.0.0 (2) — production workspace and install path, 2026-09-27

- Promoted the editable source reconstruction to the dedicated **Halo Production** workspace.
- Renamed the production artifact to `Halo Production.app` and assigned it the separate development identity `com.maneesh.halo.production`.
- Added `make install`, which verifies the universal release, installs `/Applications/Halo Production.app` atomically, retains an installed-app backup when replacing a prior production build, and writes a deployment receipt.
- Added `make status` verification for both the source/release manifest and the installed production app.
- The approved `/Applications/Halo.app` and its baseline remain untouched reference artifacts.

## 1.0.0 (1) — source reconstruction, 2026-09-27

- Reconstructed native Launcher/Quitter panels and rendering from the approved app, recording and screenshots.
- Replaced address-based wheel calls with an explicit typed driver; no inherited executable or dylib dependency.
- Preserved General Settings and the shortcut engine; tightened malformed configuration parsing.
- Added editable geometry, app catalog, asynchronous actions, cancellable window lifecycle, and isolated preferences.
- Implemented the existing placeholder customization pages while retaining the original defaults.
- Added safe previews, strict Swift 6 builds, universal release output, provenance checks, source snapshots and harmless regression tests.
- Kept the original application, baseline and maintained project unchanged. App Store compatibility remains a separate release decision.
