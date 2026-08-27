# OmaSys security model

Omarchy shell plugins execute unsandboxed with the logged-in user's permissions. OmaSys is designed to keep that trust boundary small, visible, and reviewable.

## What the plugin reads

- `/proc/stat`, `/proc/meminfo`, `/proc/loadavg`, `/proc/uptime`, `/proc/net/dev`, `/proc/cpuinfo`, and `/proc/<pid>` metadata.
- `/sys/class/thermal/thermal_zone*/temp` when readable.
- `/sys/class/drm/card*/device/gpu_busy_percent` when exposed by the GPU driver.
- `/etc/os-release`, `df` output for `/`, `ps` output, hostname, kernel version, and online CPU count.
- `nvidia-smi` utilization output when that command is already installed.

Process command lines may contain sensitive arguments. OmaSys displays them locally in the task-manager UI but never writes or transmits them.

## What the plugin can change

Only explicit process signals selected in the UI:

- `SIGTERM` — request a clean exit.
- `SIGKILL` — force immediate termination.
- `SIGSTOP` — suspend execution.
- `SIGCONT` — resume execution.

Before signaling, `scripts/process-action.sh` validates the PID, rejects PID 1, confirms that the process still exists, and requires its owner UID to equal the current UID. The helper has no wildcard action, arbitrary signal parameter, shell-evaluated process data, privilege escalation, or recursive process-tree behavior.

PID reuse is inherently possible between displaying a row and sending a signal. OmaSys minimizes the window with a two-second refresh cadence, displays the current PID in every confirmation, and performs an ownership check immediately before signaling. Review the name and PID in the dialog before confirming.

## What the plugin does not do

- No `sudo`, `pkexec`, polkit request, setuid binary, or capability use.
- No network request, telemetry, update checker, analytics, or crash reporting.
- No file write, cache, database, log, credential access, or clipboard access.
- No install/remove hook, background daemon, systemd unit, cron job, or Hyprland binding.
- No arbitrary command construction from process names, arguments, filters, or payloads.

## Dependencies

The mandatory collectors use standard Omarchy/Linux commands. NVIDIA utilization is optional and invokes the already-installed `nvidia-smi` with a fixed, read-only query. No dependency is downloaded or installed by the plugin.

## Reporting a vulnerability

Do not include private command lines or system data in a public issue. Contact the repository owner privately after the publication owner and security contact have been chosen. Until then, keep findings in the private review channel for this pre-publication package.
