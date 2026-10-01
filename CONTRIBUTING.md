# Contributing

Halo is made by Maneesh Getni. Read LICENSE before sharing forks or modified
apps. Private experimentation and patches proposed to this project are welcome;
independent modified distributions require written permission.

For bugs, include Halo/macOS versions, hardware/display scale, relevant settings,
expected behavior, and a minimal reproduction. Do not attach personal exports,
screenshots, or credentials. Describe the problem when proposing a feature.
Report vulnerabilities privately as described in SECURITY.md.

Keep changes focused: code in Sources/, assets in Resources/, tests in Tests/,
version metadata in Configuration/Info.plist, behavior notes in CHANGELOG.md.
Run `make verify` and `make release`. Use the existing single Xcode build path.
No private frameworks, injected code, or reference binaries. Never automate
real force quit or Empty Trash. Close diagnostic apps when finished.

Contributors retain copyright in their contributions and submit under LICENSE
unless separately agreed. Review and acceptance remain with the maintainer.
