#!/usr/bin/env bash
set -eu

printf 'SYSV1\n'

read -r _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _guest _guest_nice < /proc/stat
cpu_total=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal))
cpu_idle_total=$((cpu_idle + cpu_iowait))
printf 'CPU\t%s\t%s\n' "$cpu_total" "$cpu_idle_total"

mem_total=$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo)
mem_available=$(awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo)
swap_total=$(awk '/^SwapTotal:/ { print $2; exit }' /proc/meminfo)
swap_free=$(awk '/^SwapFree:/ { print $2; exit }' /proc/meminfo)
printf 'MEM\t%s\t%s\t%s\t%s\n' "${mem_total:-0}" "${mem_available:-0}" "${swap_total:-0}" "${swap_free:-0}"

read -r load_1 load_5 load_15 _ < /proc/loadavg
printf 'LOAD\t%s\t%s\t%s\n' "$load_1" "$load_5" "$load_15"

read -r uptime_seconds _ < /proc/uptime
printf 'UPTIME\t%s\n' "${uptime_seconds%.*}"

df -Pk / | awk 'NR == 2 { printf "DISK\t%s\t%s\t%s\t%s\n", $2, $3, $4, $5 }'

awk -F '[:[:space:]]+' '
  NR > 2 && $2 != "lo" { rx += $3; tx += $11 }
  END { printf "NET\t%.0f\t%.0f\n", rx, tx }
' /proc/net/dev

gpu_percent=-1
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia_percent=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null \
    | awk 'BEGIN { max = -1 } /^[[:space:]]*[0-9]+/ { value = $1 + 0; if (value > max) max = value } END { print max }')
  case "$nvidia_percent" in
    ''|*[!0-9-]*) ;;
    *) gpu_percent=$nvidia_percent ;;
  esac
fi
if [ "$gpu_percent" -lt 0 ]; then
  for busy_file in /sys/class/drm/card*/device/gpu_busy_percent; do
    [ -r "$busy_file" ] || continue
    value=$(cat "$busy_file" 2>/dev/null || printf '%s' -1)
    case "$value" in
      ''|*[!0-9-]*) continue ;;
    esac
    if [ "$value" -gt "$gpu_percent" ]; then gpu_percent=$value; fi
  done
fi
printf 'GPU\t%s\n' "$gpu_percent"

temperature=-1
for temperature_file in /sys/class/thermal/thermal_zone*/temp; do
  [ -r "$temperature_file" ] || continue
  value=$(cat "$temperature_file" 2>/dev/null || printf '%s' -1)
  case "$value" in
    ''|*[!0-9-]*) continue ;;
  esac
  if [ "$value" -gt "$temperature" ]; then temperature=$value; fi
done
printf 'TEMP\t%s\n' "$temperature"

hostname_value=$(hostname 2>/dev/null || printf 'unknown')
kernel_value=$(uname -r 2>/dev/null || printf 'unknown')
distribution_value=$(awk -F= '
  $1 == "PRETTY_NAME" {
    value = substr($0, index($0, "=") + 1)
    gsub(/^"|"$/, "", value)
    print value
    exit
  }
' /etc/os-release 2>/dev/null || true)
cpu_model=$(awk -F: '
  /^model name|^Hardware|^Processor/ {
    value = $2
    sub(/^[[:space:]]+/, "", value)
    print value
    exit
  }
' /proc/cpuinfo)
cpu_threads=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0')
current_uid=$(id -u)

sanitize() { printf '%s' "$1" | tr '\t\r\n' '   '; }
printf 'META\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(sanitize "$hostname_value")" \
  "$(sanitize "$kernel_value")" \
  "$(sanitize "${distribution_value:-Linux}")" \
  "$(sanitize "${cpu_model:-Unknown CPU}")" \
  "$cpu_threads" \
  "$current_uid"
