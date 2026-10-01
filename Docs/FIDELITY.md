# Reference contract and verification

Reference: Halo 0.2.1 (6), copied from the former hybrid project's `Latest/Halo.app` at reconstruction time. That historical project is now Halo Legacy; its baseline is preserved separately. Current Halo is entirely source-built. Historical provenance and baseline hashes are in `VERIFICATION.md`. The complete original Swift source was **not** recovered; this is a reconstruction from public API behavior, executable inspection, and visual evidence.

## Measured/recovered constants

Version 1.1.2 extends the 1.1.1 continuous annular renderer with 21 light, liquid-biased glass levels and a 36–78 pt ring-thickness scale. Oppositely wound ellipses preserve both lens boundaries and the clear center without repeated circle joins. More diffusion is achieved with lighter native regular material rather than a dark overlay. The original cropped disc, the 96-circle intermediate renderer, and the 5-point inset veil below are historical, not current. Optical sampling remains system-controlled; no fixed-resolution or exact iOS compositor claim is made. Both Settings previews share production geometry and allow a draggable wheel-mode switch.

The table below records the reconstruction baseline. Requested changes in 1.0.1 supersede its timings: no reveal scheduling delay, 45 ms reveal, 25 ms collapse, 40 ms subset-release guard, and a 0.16/0.86 icon selection spring. Settings now uses native window behavior. Both handoff directions commit selection. Outer selection is unlimited by default, optionally bounded; dynamic 0–8 pt icon movement is optional. These deliberate changes are recorded in CHANGELOG.md.

| Property | Replica/reference value |
| --- | --- |
| Default diameter / clamp | 300 pt / 240–520 pt |
| Icon / radial padding / ring thickness | 58 / 4 / 66 pt |
| Icon-center radius | diameter ÷ 2 − 4 − 29 |
| Highlight inner diameter | max(80, diameter − 132) |
| Window size | diameter + 56 pt |
| Neutral selection distance | 86 pt default, clamped 40–86; original stored 1000 is clamped to 86 |
| Selection region | Closest angular sector; no ordinary outer cutoff (reference safety cutoff 65536 pt) |
| Angular origin | Launcher −90°, Quitter +90° |
| Selected icon displacement | 8 pt outward, no scale enlargement |
| Icon spring | response .24, damping .72 |
| Highlight spring | response .14, damping .98, blend .04; shortest route across angular seam |
| Highlight appear/disappear | ease-out .10 s |
| Reveal scheduling / reveal / collapse | .024 / .0625 / .03125 s |
| Closed scale | .95 |
| Glass | NSGlassEffectView clear; white tint .05; corner radius diameter ÷ 2 |
| Additional veil | White .045; 10-point-smaller circle and independent annular mask |
| Outer / inner stroke | white .09 / .06; 0.5 pt |
| Icon shadow | black .16, radius 5, y 2; selected .28, radius 8 |
| Highlight gradient | RGB (.96,.99,.98) @ .30; (.73,.91,.86) @ .40; (.56,.78,.74) @ .24 |
| Highlight effects | Screen blend, top radial white .18, white .28→.08 stroke 1.1, pale-green glow .22 blurred 14 |
| Fixed Trash band | white .08→.03 fill; white .22→.10 stroke 1.25; white .06 stroke 5 blurred 10 |
| Menu-bar glyph | 18 pt image; annulus at 2.1/13.8 outer and 5.3/7.4 inner |
| Haptics | Launcher selection levelChange/default; Quitter selection alignment/default; commit generic/now |

The unchanged editable shortcut state machine and Settings General layout were carried forward, replacing the executable-address interface with the explicit `HaloWheelDriver` protocol. The new wheel controller uses a 120 Hz pointer sampler only while visible; it is stopped on hide. The original used NSEvent mouse monitors. This is an intentional implementation difference, not a claimed recovery of original source.

## Evidence used

- `Reference/Working-Halo.mov`, 11.443 s, 2076×1318: launcher neutral and selected states, release action, switching into Quitter, dynamic app order, fixed bottom Trash sector, moving highlight.
- `Reference/Working-Launcher-Notes.png` and `Working-Launcher-Surfshark.png`: detailed glass, outlines, sector boundaries and icon displacement.
- `Reference/disassembly.txt`: public drawing calls, dimensions, colors, springs, app-order and selection math. `Scripts/inspect_reference.py` is an analysis utility only; it is never invoked by builds.
- Live native-window inspection using both standalone previews and the video's background as a fixture. A static view-cache export cannot reproduce native backdrop compositing.

## Remaining acceptance pass

Perform with the old Halo stopped and the replica authorized for Accessibility. These are not represented as already physically verified:

1. Hold/release Fn at neutral, then on each app; repeat rapidly. Verify no flash, duplicate launch, or stuck wheel.
2. Add/release Control while Fn stays held; check the 40 ms return guard and exactly one commit of the departing selection. Release both modifiers in either order; near-simultaneous releases within the guard must not flash Launcher. A longer pause while Fn remains held intentionally opens Launcher.
3. Record your own modifier and ordinary-key chords; try both Hold and Toggle, menu opens, comma, Escape, and recording cancellation.
4. Move across every sector and the wrap boundary; compare against the reference on the same desktop/display/scale. Test near each screen edge, across Spaces/full-screen apps, and on multiple monitors.
5. Check Force Touch haptics on the actual trackpad. AppKit can suppress them when the trackpad isn't touched.
6. Check active-app launching manually. Test force quit **only** with a disposable app/document, and Empty Trash **only** with deliberate disposable contents. This is destructive and is not automated.
7. Sleep/wake, permission denial/revocation/regrant, keyboard-layout changes, and clean-account install.
8. In 1.2.0, try Less animation off/on with rapid cycles. Quit a disposable app and immediately reopen Quitter; it should be omitted immediately. Cancel a normal quit/save prompt and confirm the app returns within two seconds. Preview haptics should be independent of actual wheel haptics on both pages. Test crowded launcher × removal, including corners near neighboring sectors.

Visual matching is close by inspection, not a certified pixel-perfect equivalence. Liquid Glass changes with wallpaper, window backdrop, OS build, display scaling and accessibility settings. Intel is compile-verified, not physically tested on an Intel Mac.
