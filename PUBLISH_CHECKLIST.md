# OmaSys publication checklist

This checklist mirrors the current [Omarchy Plugins publishing guide](https://omarchyplugins.com/publish.html). Do not submit OmaSys until every required item is complete.

## Repository

- [x] Choose the final GitHub owner (`rookepoole`) and permanent namespace (`omasys.task-manager`).
- [x] Set the manifest author to Rooke Poole.
- [x] Create the public `rookepoole/omasys` GitHub repository with `manifest.json` at its root.
- [x] Confirm all release files are committed and no symlinks exist.
- [x] Confirm executable bits are preserved on `scripts/*.sh` and `tests/run.sh`.

## Required files and behavior

- [x] Schema-version-1 `manifest.json` in the repository root.
- [x] Namespaced plugin ID.
- [x] Human-readable name, version, author, and description.
- [x] Declared `overlay` and `bar-widget` kinds with matching entry points.
- [x] README.
- [x] MIT license.
- [x] Safe installation through `omarchy plugin add`.
- [x] Safe removal through `omarchy plugin remove`; no residual state.
- [x] No install hook, sudo, pkexec, telemetry, or network access.
- [x] Destructive actions require confirmation and are current-UID only.
- [x] Review the live UI; omit a public preview to avoid publishing local process and command-line data.

## Verification

- [x] Run `omarchy plugin validate .` on the release tree.
- [x] Run `./tests/run.sh` on the release tree.
- [x] Install the final repository URL without `--enable`, review and test the staged checkout, then enable it.
- [x] Verify CPU, RAM, and real AMD DRM GPU values in the bar and overlay; vendor-independent and NVIDIA parsing are covered by model tests.
- [x] Verify `GPU N/A` is graceful through collector/model tests when no utilization interface is available.
- [x] Verify filtering, sorting, pause/resume, refresh, empty-state feedback, and keyboard navigation.
- [x] Verify TERM, KILL, STOP, and CONT against disposable processes owned by the test user.
- [x] Verify an attempt to signal another user's process is rejected.
- [x] Verify removal clears the plugin checkout/config reference, then reinstall and restore its prior bar placement.
- [x] Inspect the running Quickshell log for OmaSys-specific QML errors.

## Marketplace submission

- [x] Open and submit the official issue form: [marketplace issue #2697](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/2697).
- [x] Provide the canonical public repository URL, category (`System`), and tags (`Bar`, `Quickshell`, `System`).
- [ ] Confirm automated validation is running against the intended current commit.
- [x] Review the final listing text before maintainer approval; no preview asset was submitted.
