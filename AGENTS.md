# Halo workspace

Read README.md and Docs/FIDELITY.md. This native reconstruction is the canonical
maintained Halo project. The older hybrid project is preserved separately as
Halo Legacy; its baseline ZIP and manifest must not be changed.

- Editable app code belongs in Sources/, resources in Resources/, tests in Tests/,
  and metadata in Configuration/Info.plist. Record changes in CHANGELOG.md.
- Public APIs and typed source only. No fixed offsets, injected libraries,
  binary patches, or compiled reference code in builds.
- Use the single generated Xcode target. Run make verify, make release, and
  make status. Use make install to update /Applications/Halo.app; do not edit
  installed bundles directly. make package creates allowlisted public artifacts.
- Never run real force quit or Empty Trash in automation. Safe fixtures only.
  Quit diagnostic apps immediately after testing.
- Do not infer notarization, App Store eligibility, clean-Mac acceptance, or
  physical haptic/shortcut acceptance from automated test success.
- Reference, Backups, Deployments, Build, and Dist are local-only, Git-ignored
  directories. Never upload private references or installation history.
- Preserve the internal com.maneesh.halo.production identifier for existing
  preferences/permissions unless a tested migration is explicitly authorized.
