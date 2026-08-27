# Changelog

All notable changes to OmaSys are documented here.

## 1.0.1 - 2026-08-27

### Security

- Force every plugin-owned QML `Text` sink to render plain text so process, filter, diagnostic, and host metadata cannot be interpreted as rich-text markup or initiate resource loads.
- Replace the shell-provided confirmation dialog with a theme-compatible local dialog that preserves literal process names with plain-text rendering.

### Tests

- Add a regression check that requires `Text.PlainText` on every native QML `Text` sink and prevents reintroduction of the unsafe shared confirmation dialog.

## 1.0.0 - 2026-08-27

### Added

- CPU, RAM, and GPU bar widget with threshold highlighting.
- Full Omarchy-native task-manager overlay.
- CPU, GPU, memory, swap, root filesystem, network, thermal, load, and uptime metrics.
- Searchable and sortable process table with detailed metadata.
- Confirmed TERM, KILL, STOP, and CONT actions restricted to current-user processes.
- Keyboard navigation, update pause, and manual refresh.
- Clear no-results feedback for filters that match no running process.
- Manifest, documentation, security model, test suite, and publication checklist.
