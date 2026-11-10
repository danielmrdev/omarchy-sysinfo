#!/usr/bin/env bash
set -u

if [[ "${1:-}" == "--supervise" ]]; then
  shift
  # Keep timeout's direct child alive after TERM so its KILL escalation reaches the whole process group.
  trap 'while :; do sleep 1; done' TERM
  "$@"
  exit "$?"
fi

exec timeout --signal=TERM --kill-after=1s 5s bash "$0" --supervise bash "$@"
