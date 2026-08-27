# OmaSys pre-publication review brief

## Release candidate

- Name: OmaSys
- Version: 1.0.0
- Plugin ID: `omasys.task-manager`
- Kinds: `overlay`, `bar-widget`
- Marketplace category: System
- State: review only; not published or submitted

## Architecture

The bar widget runs the read-only system collector every three seconds and renders CPU, RAM, and GPU utilization. Clicking it asks the existing Omarchy shell to toggle the OmaSys overlay; it does not start a second Quickshell process.

While open, the overlay runs the system and process collectors every two seconds. `Model.js` parses, filters, sorts, formats, and calculates deltas for system CPU, per-process CPU, and network throughput. The overlay instance is unloaded when closed, so process sampling does not continue invisibly.

Process actions pass a fixed allowlisted action and numeric PID as separate argv entries to `process-action.sh`. Process names, arguments, and search text never enter a shell command. The helper rechecks ownership immediately before signaling.

## Security decisions to approve

1. OmaSys lists all visible processes but enables actions only when the selected process UID matches the logged-in UID.
2. All four signals require confirmation, including suspend and resume.
3. PID 1 is always blocked.
4. No privilege elevation is offered. Root- or service-owned processes remain read-only.
5. Force end is `SIGKILL`; the confirmation warns that unsaved data may be lost.
6. No process tree is signaled recursively.
7. Command lines are displayed transiently and never persisted or transmitted.

## Resource collection decisions to approve

- GPU: maximum utilization across NVIDIA devices reported by `nvidia-smi`, otherwise maximum readable DRM `gpu_busy_percent`; unsupported drivers show `N/A`.
- Temperature: highest readable thermal-zone temperature.
- Disk: usage of the root filesystem only.
- Network: aggregate receive/transmit bytes across all non-loopback interfaces.
- Processes: first 600 rows returned by `ps`, sorted in the UI after sampling.
- Per-process CPU: delta of accumulated CPU seconds across refreshes; the first sample falls back to `ps` CPU percentage.

## Known limitations

- Some Intel GPU drivers expose no unprivileged standard utilization file, so GPU may correctly show `N/A` without an optional vendor tool.
- Process CPU accumulation is reported by `ps` at one-second resolution, which can make very short samples look stepped.
- PID reuse cannot be eliminated completely between selection and confirmation; the helper narrows risk by verifying existence and owner at action time.
- The responsive layout is designed for a normal desktop display. A genuine running-session pass should verify unusually small or vertically oriented monitors before release.

## Automated evidence

- `omarchy plugin validate` passes.
- The root manifest contains both declared kinds and both existing entry points.
- Shell syntax checks pass for all helpers.
- Model parsing, GPU handling, live process CPU deltas, search, sorting, formatting, and state labels pass Node assertions.
- System and process collectors run successfully on the review machine.
- GPU collection reported a real AMD DRM utilization value on the review machine.
- The action helper rejects PID 1 and unsupported actions and successfully terminates only a disposable same-UID test process.
- No symlink exists in the repository.
- Qt's QML analyzer reports no OmaSys-specific unresolved type, property collision, or syntax error. Its remaining Quickshell metadata warnings reproduce on Omarchy's built-in clipboard overlay.

## Human decisions still required

- Final GitHub owner and public repository URL.
- Whether the manifest author should remain `OmaSys Contributors` or use a personal/organization name.
- Visual test and optional marketplace preview capture from an installed review session.
- Final permission to create the public repository and submit the marketplace listing.
