# Halo

Hold. Point. Release.

A customizable Liquid Glass app launcher and quitter for macOS.
Made by **Maneesh Getni**.

Hold a shortcut, point at an app, and release. Open apps, bring running apps'
windows forward, or quit them. Customize apps, wheel size, glass, colors,
shortcuts, animation, and haptics.

## Install

Requires **macOS 26+**, Apple silicon or Intel. Download `Halo-1.2.6-macOS.zip`
from this repository's Releases, unzip, move Halo.app to Applications, and open
it. Quit older Halo copies first. There is no account, subscription, telemetry,
or automatic updater.

This release is **ad-hoc signed, not Developer ID signed or notarized**.
macOS may block downloads. Only if you trust the source, follow
[Apple's per-app Open Anyway instructions](https://support.apple.com/en-us/102445).
Do not disable system-wide security protections. Managed Macs may disallow
exceptions. Checksums detect changes; they do not establish publisher identity.

## First launch

Halo lives in the menu bar, not the Dock. Settings opens initially; the ring
menu-bar icon always provides access, even without shortcut permissions.

1. Grant Halo Accessibility in System Settings → Privacy & Security →
   Accessibility to enable global shortcuts. Quit and reopen Halo if needed.
2. Hold **Fn / Globe** for Launcher or **Fn + Control** for Quitter. Point at an
   app and release to act. Release in the center or press Escape to cancel.
   Press **comma** while either wheel is visible to open Settings.
3. In Apps, add .app bundles, drag icons to reorder, and hover × to remove.
   Switching wheels commits the departing selection: keep the pointer centered
   to switch without acting.
4. If Globe triggers an unwanted system action, change its action in macOS
   Keyboard settings or record different shortcuts in Halo → General.

Quitter shows running apps. **Regular Quit is the default**, so apps can save or
ask before closing. Turn on Force quit apps in Advanced only when you want it
globally; it can discard unsaved work. Apps → Quitter lets you choose an app and
override that default with Quit or Force quit; Use default removes the override. Rules follow
the app's bundle identifier, including other installed copies with that identity.
Finder closes its windows instead of terminating.
Quitter spaces running apps evenly by default and rearranges them as apps quit.
Enable **Apps → Quitter → Stable app positions** to match Launcher directions
and remember other apps' directions instead. In that optional mode, an app
that exits leaves an empty space until you close the wheel. Turning the option
off keeps remembered positions available if you enable it again.
**Empty Trash permanently deletes contents**; hide it in Apps → Quitter if
unwanted. Finder actions may request Automation permission. Declining permission
leaves Settings usable and affected actions report errors.

Less animation in Advanced shows/hides wheels instantly; it is off by default.
The default reveal gently fades and expands into place while accepting selection immediately.
Each preview has its own Preview haptics control, independent of wheel haptics.
Settings save as controls change. Exported settings may contain local paths and
bookmarks; review before sharing.

## Build and verify

Use Xcode with macOS SDK 26 or newer and command-line tools. Open Halo.xcodeproj
with the Halo scheme, or use the same build path through Make:

```sh
make verify    # Logic, input, persistence, harmless fixtures, native windows
make release   # Universal Build/Release/Halo.app + provenance manifest
make install   # Back up old installation and install /Applications/Halo.app
make status    # Verify source freshness, signature, and installed bytes
make package   # App and source ZIPs with SHA256SUMS in Dist/
```

`make preview` opens safe Settings without global input capture or live actions.
Quit it when done. Release builds omit self-test and isolated UI-test entry points. All app code
is compiled from native Swift/Objective-C source, without injecting or patching
another app. See [verification](Docs/VERIFICATION.md),
[release checklist](Docs/RELEASE.md), and [changelog](CHANGELOG.md).

The internal identifier remains `com.maneesh.halo.production` for existing
preferences and permissions. Display name, executable, and installed bundle are
now **Halo**. Ad-hoc signed updates may still require permission reapproval.

## Contributing, security, and license

See [CONTRIBUTING.md](CONTRIBUTING.md) for bugs and proposals; report
vulnerabilities privately following [SECURITY.md](SECURITY.md).

Halo is **source-available, not open source**. Use, study, private modifications,
and sharing unmodified official copies are allowed with attribution. Modified
or rebranded distributions require Maneesh Getni's written permission.
See [LICENSE](LICENSE).
