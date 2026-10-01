# Security

Use the official repository's **Security → Report a vulnerability** feature if
enabled. Otherwise contact Maneesh Getni privately through the repository
owner's profile to arrange a secure reporting channel. Do not post exploit
details, credentials, personal screenshots, or exported preferences publicly.
Include Halo/macOS versions and a minimal harmless reproduction. No response
time or independent security certification is guaranteed.

## Security boundaries

- No accounts, telemetry, network service, auto-downloads, or self-updater.
- Accessibility enables global shortcut interception. Halo does not store typed
  text. Secure Input may prevent shortcuts from being intercepted.
- Finder Automation handles explicitly selected close-window/Trash actions.
  Force quit can lose work; Empty Trash is irreversible.
- The direct-download app is not sandboxed. Accessibility and Automation are
  powerful permissions; only grant them to builds you trust.
- Imported settings are size-limited and validated; app paths are not executed
  as shell commands. Still, import only trusted settings: configured apps can
  be launched when selected. Exports can contain local paths and bookmarks.
- System glass composites the backdrop without recording it to disk or
  requesting Screen Recording permission.
- Safe tests never execute live app or Trash actions. Preserve those safeguards.

Only the newest release is maintained. Ad-hoc signatures and checksums do not
prove publisher identity. Developer ID signing and notarization are recommended
for public distribution; the current package has neither. Never disable
Gatekeeper, SIP, or other system-wide protections as an installation workaround.
