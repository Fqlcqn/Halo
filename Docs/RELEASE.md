# GitHub release checklist

Current version: **1.2.5 (17)**. Distribution is direct download, not the App Store.
The app is universal, hardened-runtime enabled, non-sandboxed, and ad-hoc signed.
It is not Developer ID signed, notarized, or independently security audited.

## Prepare

1. Review LICENSE, README, SECURITY, CONTRIBUTING, and CHANGELOG. Confirm rights
   to the app icon and other included assets. Application icons are obtained
   locally from installed apps, not bundled third-party marketing artwork.
2. Run `make verify`, `make install`, `make status`, and `make package`.
3. Complete the manual checklist in FIDELITY.md, especially first launch on a
   clean account, Accessibility deny/grant/revoke, Automation refusal, shortcut
   layouts, rapid wheel transitions, physical haptics, Spaces and monitors.
   Intel compilation is not a substitute for Intel-device testing.
4. Test the actual downloaded archive's Gatekeeper behavior on another Mac.
   Current builds require the per-app exception described in README, when
   macOS permits it. Signing/notarization are recommended for broad adoption.
   Do not claim an ad-hoc signature is Apple approval or publisher verification.
5. Create the official repository and enable private vulnerability reporting.
   Put a private contact method on the owner's profile before announcing it.
   Commit only tracked source/docs, never local Reference/Backups/Deployments.
6. Commit/push the 1.2.5 changes, then create tag/release v1.2.5 at that commit and attach Dist/Halo-1.2.5-macOS.zip,
   Dist/Halo-1.2.5-source.zip, and Dist/SHA256SUMS. Include the signing limitation,
   macOS 26 requirement, force-quit/Trash warning, and changes in release notes.
   This workspace does not create a repository or publish automatically.

A custom source-available license was chosen to allow private modifications and
preserve attribution while requiring permission for modified distribution.
It is not an OSI open-source license and does not prevent all copying. Have a
qualified lawyer review the custom terms before relying on their enforceability.

## Future signing / App Store

Use the same Xcode target with a Developer ID Application certificate and
secure timestamp, then notarize/staple and retest the exported archive. No
distribution certificate is bundled or stored in source.

App Store work is deferred. Sandbox compatibility needs a separate design
review: terminating other apps, Finder automation, and global shortcut capture
must not be assumed approved. Do not silently remove functionality or advertise
App Store readiness. See [Apple's sandbox guidance](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox).

## Toolchain note

This development Mac emits CoreDevice/CoreSimulator version-mismatch warnings.
Native macOS Debug and universal Release builds can complete; do not infer
that unrelated simulator/release tools are healthy from those successful builds.
