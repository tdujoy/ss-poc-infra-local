#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_common.sh"

attempts="${1:-60}"
i=1
while [ "$i" -le "$attempts" ]; do
  unhealthy="$(compose ps --format '{{.Service}} {{.Status}}' | awk '/health: starting|unhealthy|starting|exited/ {print}')"
  compose ps --format 'table {{.Service}}\t{{.Status}}'
  if [ -z "$unhealthy" ]; then
    exit 0
  fi
  sleep 2
  i=$((i + 1))
done

echo "One or more services did not become healthy:" >&2
compose ps --format 'table {{.Service}}\t{{.Status}}' >&2
exit 1
