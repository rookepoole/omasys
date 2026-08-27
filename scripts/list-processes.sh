#!/usr/bin/env bash
set -eu

limit=${1:-600}
case "$limit" in
  ''|*[!0-9]*) printf 'Invalid process limit\n' >&2; exit 2 ;;
esac
if [ "$limit" -lt 1 ] || [ "$limit" -gt 2000 ]; then
  printf 'Process limit must be between 1 and 2000\n' >&2
  exit 2
fi

LC_ALL=C ps -ww --no-headers \
  -eo pid=,ppid=,uid=,user=,stat=,ni=,pcpu=,pmem=,rss=,etimes=,cputimes=,comm=,args= \
  --sort=-pcpu | head -n "$limit" | cut -c1-4096
