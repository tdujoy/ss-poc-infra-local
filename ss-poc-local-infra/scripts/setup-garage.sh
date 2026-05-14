#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_common.sh"

GARAGE_BUCKET="${GARAGE_BUCKET:-st-poc-local}"
GARAGE_KEY_NAME="${GARAGE_KEY_NAME:-st-poc-local-app}"
GARAGE_NODE_ZONE="${GARAGE_NODE_ZONE:-local}"
GARAGE_NODE_CAPACITY="${GARAGE_NODE_CAPACITY:-1GB}"
KEY_FILE="garage/.garage-${GARAGE_KEY_NAME}.txt"

compose --profile core up -d garage
wait_for_healthy garage 60

node_id="$(compose exec -T garage /garage status | awk '/^[0-9a-f][0-9a-f]/ {print $1; exit}')"
if [ -z "$node_id" ]; then
  echo "Could not find a healthy Garage node ID." >&2
  compose exec -T garage /garage status >&2 || true
  exit 1
fi

if compose exec -T garage /garage layout show | grep -q "$node_id"; then
  echo "Garage node $node_id is already assigned in the layout."
else
  current_version="$(compose exec -T garage /garage layout show | awk '/Current cluster layout version:/ {print $5; exit}')"
  next_version=$((current_version + 1))
  compose exec -T garage /garage layout assign "$node_id" -z "$GARAGE_NODE_ZONE" -c "$GARAGE_NODE_CAPACITY"
  compose exec -T garage /garage layout apply --version "$next_version"
fi

if compose exec -T garage /garage bucket info "$GARAGE_BUCKET" >/dev/null 2>&1; then
  echo "Garage bucket $GARAGE_BUCKET already exists."
else
  compose exec -T garage /garage bucket create "$GARAGE_BUCKET"
fi

if compose exec -T garage /garage key info "$GARAGE_KEY_NAME" >/dev/null 2>&1; then
  echo "Garage key $GARAGE_KEY_NAME already exists."
  if [ ! -f "$KEY_FILE" ]; then
    echo "Warning: $KEY_FILE is missing; Garage cannot show an existing secret key again." >&2
  fi
else
  umask 077
  compose exec -T garage /garage key create "$GARAGE_KEY_NAME" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "Wrote Garage key material to $KEY_FILE."
fi

compose exec -T garage /garage bucket allow "$GARAGE_BUCKET" --key "$GARAGE_KEY_NAME" --read --write
compose exec -T garage /garage bucket info "$GARAGE_BUCKET"
