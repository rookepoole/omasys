# OmaSys

OmaSys is a native task manager for the Omarchy Quattro shell. It adds a compact CPU, RAM, and GPU readout to the bar and opens a full system dashboard with live resource usage, searchable processes, sorting, and confirmed process controls.

![Status: review](https://img.shields.io/badge/status-review-orange)
![Omarchy: Quattro](https://img.shields.io/badge/Omarchy-Quattro-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

## Highlights

- Live CPU, memory, GPU, swap, root-disk, network, temperature, load, and uptime metrics.
- Bar widget with CPU, RAM, and GPU utilization; left-click opens OmaSys and right-click refreshes it.
- Up to 600 processes sampled every two seconds.
- Instant filtering by PID, user, executable name, or full command line.
- Sorting by CPU, memory, name, or PID.
- Resident-memory, state, age, parent PID, owner, nice value, and command-line details.
- Confirmed actions for clean end (`SIGTERM`), force end (`SIGKILL`), suspend (`SIGSTOP`), and resume (`SIGCONT`).
- Theme-native Omarchy UI with keyboard and pointer controls.
- No daemon, database, network access, telemetry, package hook, install hook, or privilege escalation.

## Requirements

- Omarchy 4.x with the Quattro shell plugin runtime.
- Bash, procps-ng (`ps`), coreutils, and Linux `/proc`/`/sys` interfaces. These are present on a normal Omarchy installation.
- Optional: `nvidia-smi` for NVIDIA GPU utilization. AMD and compatible DRM drivers are detected through `gpu_busy_percent`. Unsupported drivers display `GPU N/A` without failing the plugin.

## Review before installation

Omarchy plugins run unsandboxed inside the long-lived shell process. Review at least these files before enabling OmaSys:

- `manifest.json` — plugin identity, kinds, and entry points.
- `OmaSys.qml` — full overlay and process-control UI.
- `BarWidget.qml` — compact resource sampler and launcher.
- `scripts/collect-system.sh` — read-only system metrics.
- `scripts/list-processes.sh` — read-only process sampling.
- `scripts/process-action.sh` — current-user ownership check and signal allowlist.

The process-action helper accepts only `term`, `kill`, `stop`, or `cont`; rejects PID 1; verifies that `/proc/<pid>` belongs to the current UID; and never invokes `sudo`, `pkexec`, or another elevation mechanism.

## Validate this checkout

From the repository root:

```bash
omarchy plugin validate .
./tests/run.sh
```

Validation is read-only. The test suite creates one temporary `sleep` process owned by the current user and ends that test process through the same helper used by the UI.

## Install a reviewed local checkout

Use the repository path while reviewing a local checkout:

```bash
omarchy plugin add "$PWD" --enable
```

OmaSys declares `right` as its default bar section. Move it later if desired:

```bash
omarchy bar move omasys.task-manager --section right
```

After publication, installation will use the public repository URL:

```bash
omarchy plugin add https://github.com/OWNER/omasys.git --enable
```

`OWNER` intentionally remains a placeholder until the repository owner is chosen during the publication review.

## Open and control OmaSys

Click the bar readout, or summon it directly:

```bash
omarchy-shell shell toggle omasys.task-manager '{}'
```

Keyboard controls:

| Key | Action |
| --- | --- |
| Type | Filter processes |
| Escape | Clear the filter; close when the filter is empty |
| Up / Down | Move the selected process |
| Page Up / Page Down | Move by ten processes |
| Home / End | Jump to the first / last process |
| F5 | Refresh system and process data |
| Space | Pause / resume automatic updates |
| Delete | Confirm a clean end (`SIGTERM`) |
| Shift+Delete | Confirm a force end (`SIGKILL`) |
| Alt+S | Confirm suspend (`SIGSTOP`) |
| Alt+R | Confirm resume (`SIGCONT`) |

Right-clicking or double-clicking a process row opens the clean-end confirmation. Every signal path displays the exact process name and PID before acting.

## Safe removal

```bash
omarchy plugin remove omasys.task-manager
```

Removal deletes only the plugin checkout managed by Omarchy and its bar/config reference. OmaSys creates no services, hooks, caches, credentials, logs, or state files, so there is no secondary cleanup step.

## Data and privacy

OmaSys reads local kernel and process information only while its UI or bar widget is active. It does not transmit data, persist process lists, record command lines, or contact the network. See [SECURITY.md](SECURITY.md) for the detailed trust boundary.

## Publishing status

This repository is prepared for review and has not been submitted to the marketplace. Before publishing:

1. Choose the public GitHub owner and repository URL.
2. Confirm the author string in `manifest.json`.
3. Run the validation and tests on a clean Omarchy Quattro session.
4. Capture an honest preview from the running plugin, if desired.
5. Complete [PUBLISH_CHECKLIST.md](PUBLISH_CHECKLIST.md).

The marketplace publishing guide requires a public GitHub repository, a valid root manifest, README, license, and safe installation/removal. See the [Omarchy Plugins publishing guide](https://omarchyplugins.com/publish.html) and the [official Omarchy shell plugin reference](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md).

## License

MIT. See [LICENSE](LICENSE).
