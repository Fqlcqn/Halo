# Local deployment

The official maintained app is Halo. The internal identifier remains
`com.maneesh.halo.production` to preserve existing preferences and permissions.

Run `make install` after documenting a change. It builds a universal release,
checks source and app hashes, stages and verifies the app, then replaces
/Applications/Halo.app. Known previous Halo/Halo Production copies are backed
up under Backups/Installed. The superseded Applications/Halo Production.app is
removed only after the new app and recovery copy verify. Unknown identities
and symlink destinations are rejected. Receipts live in Deployments/.

Quit running Halo copies before updating; otherwise the running process is
still the previous executable. After installation, run `make status`.
Backups and receipts are private local history and never public release inputs.

`make package` generates app/source archives and checksums in Dist. Packaging
extracts the app again, verifies its signature and file hashes, and checks the
source allowlist. It does not upload, notarize, or contact GitHub.
