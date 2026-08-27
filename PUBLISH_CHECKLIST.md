# OmaSys publication checklist

This checklist mirrors the current [Omarchy Plugins publishing guide](https://omarchyplugins.com/publish.html). Do not submit OmaSys until every required item is complete.

## Repository

- [ ] Choose the final GitHub owner and confirm whether `omasys.task-manager` is the desired permanent namespace.
- [ ] Replace the review-stage author in `manifest.json` if needed.
- [ ] Create a public GitHub repository with `manifest.json` at its root.
- [ ] Confirm all files are committed and no symlinks exist.
- [ ] Confirm executable bits are preserved on `scripts/*.sh` and `tests/run.sh`.

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
- [ ] Optional: add a genuine preview captured from a running Omarchy session.

## Verification

- [ ] Run `omarchy plugin validate .` on the final commit.
- [ ] Run `./tests/run.sh` on the final commit.
- [ ] Install the final repository URL without `--enable`, review the staged checkout, then enable it.
- [ ] Verify CPU, RAM, and GPU values in the bar on AMD/Intel/NVIDIA hardware where available.
- [ ] Verify `GPU N/A` is graceful on a driver without a utilization interface.
- [ ] Verify filtering, sorting, pause/resume, refresh, and keyboard navigation.
- [ ] Verify TERM, KILL, STOP, and CONT against disposable processes owned by the test user.
- [ ] Verify an attempt to signal another user's process is rejected.
- [ ] Verify removal restores the prior bar layout and leaves no files outside the plugin checkout.
- [ ] Inspect `qs log -p "$OMARCHY_PATH/shell" --tail 100` for QML errors.

## Marketplace submission

- [ ] Open the official submission issue form.
- [ ] Provide the public repository URL, appropriate category (`System`), and accurate tags.
- [ ] Confirm automated validation is running against the intended current commit.
- [ ] Review the final listing text and optional preview before maintainer approval.
