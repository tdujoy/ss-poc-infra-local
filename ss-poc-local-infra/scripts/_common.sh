#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

PROFILES="--profile edge --profile core --profile broker --profile mail --profile obs --profile secrets --profile tools"

compose() {
  docker compose "$@"
}

wait_for_healthy() {
  service="$1"
  attempts="${2:-60}"
  i=1
  while [ "$i" -le "$attempts" ]; do
    container_id="$(compose ps -q "$service" 2>/dev/null || true)"
    if [ -n "$container_id" ]; then
      health="$(docker inspect "$container_id" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
      if [ "$health" = "healthy" ] || [ "$health" = "running" ]; then
        return 0
      fi
    fi
    sleep 2
    i=$((i + 1))
  done

  echo "Timed out waiting for $service to become healthy." >&2
  compose ps "$service" >&2 || true
  return 1
}
