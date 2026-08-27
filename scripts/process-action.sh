#!/usr/bin/env bash
set -eu

action=${1:-}
pid=${2:-}

case "$pid" in
  ''|*[!0-9]*) printf 'ERROR\tInvalid PID\n'; exit 2 ;;
esac
if [ "$pid" -le 1 ]; then
  printf 'ERROR\tPID 1 and invalid PIDs are protected\n'
  exit 2
fi
if [ ! -d "/proc/$pid" ]; then
  printf 'ERROR\tProcess %s no longer exists\n' "$pid"
  exit 3
fi

current_uid=$(id -u)
process_uid=$(stat -Lc '%u' "/proc/$pid" 2>/dev/null || printf '%s' -1)
if [ "$process_uid" != "$current_uid" ]; then
  printf 'ERROR\tProcess %s is not owned by the current user\n' "$pid"
  exit 4
fi

case "$action" in
  term) signal=TERM; label='End request sent' ;;
  kill) signal=KILL; label='Force-end request sent' ;;
  stop) signal=STOP; label='Suspend request sent' ;;
  cont) signal=CONT; label='Resume request sent' ;;
  *) printf 'ERROR\tUnsupported action\n'; exit 2 ;;
esac

if kill "-$signal" -- "$pid" 2>/dev/null; then
  printf 'OK\t%s to PID %s\n' "$label" "$pid"
else
  printf 'ERROR\tCould not signal PID %s\n' "$pid"
  exit 5
fi
