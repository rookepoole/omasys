# Contributing to OmaSys

OmaSys targets the current Omarchy Quattro shell contract. Keep changes small, reviewable, dependency-light, and consistent with Omarchy's theme primitives.

## Development loop

1. Work in a checkout outside `/usr/share/omarchy`.
2. Run `omarchy plugin validate .` and `./tests/run.sh`.
3. Add the local checkout with `omarchy plugin add "$PWD" --enable` on a disposable or review session.
4. Exercise keyboard and pointer behavior at multiple display sizes and scales.
5. Inspect `qs log -p "$OMARCHY_PATH/shell" --tail 100`.
6. Remove the test installation with `omarchy plugin remove omasys.task-manager`.

Never modify `/usr/share/omarchy`; packaged files are reference-only. Do not add install hooks, privilege escalation, dynamic shell evaluation, network telemetry, or persistent collection of process arguments.

## Release changes

Update `manifest.json`, `CHANGELOG.md`, documentation, and tests together. Complete `PUBLISH_CHECKLIST.md` against the exact commit proposed for marketplace submission.
