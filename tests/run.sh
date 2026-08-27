#!/usr/bin/env bash
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

printf 'Validating manifest...\n'
omarchy plugin validate "$repo_dir"

printf 'Checking shell syntax...\n'
bash -n "$repo_dir/scripts/collect-system.sh" \
  "$repo_dir/scripts/list-processes.sh" \
  "$repo_dir/scripts/process-action.sh"

printf 'Checking system collector...\n'
system_output=$($repo_dir/scripts/collect-system.sh)
printf '%s\n' "$system_output" | grep -q '^SYSV1$'
for section in CPU MEM LOAD UPTIME DISK NET GPU TEMP META; do
  printf '%s\n' "$system_output" | grep -q "^${section}"
done

printf 'Checking process collector...\n'
process_output=$($repo_dir/scripts/list-processes.sh 10)
test -n "$process_output"

printf 'Checking model helpers...\n'
node "$repo_dir/tests/model.test.js"

printf 'Checking process-action guardrails...\n'
if "$repo_dir/scripts/process-action.sh" term 1 >/dev/null 2>&1; then
  printf 'process-action unexpectedly accepted PID 1\n' >&2
  exit 1
fi
sleep 30 &
test_pid=$!
cleanup() { kill "$test_pid" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
if "$repo_dir/scripts/process-action.sh" arbitrary "$test_pid" >/dev/null 2>&1; then
  printf 'process-action unexpectedly accepted an unsupported action\n' >&2
  exit 1
fi
action_output=$($repo_dir/scripts/process-action.sh term "$test_pid")
printf '%s\n' "$action_output" | grep -q '^OK'
wait "$test_pid" 2>/dev/null || true
trap - EXIT INT TERM

printf 'All OmaSys tests passed.\n'
