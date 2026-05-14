#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_common.sh"

VAULT_INIT_FILE="${VAULT_INIT_FILE:-vault/.vault-init.json}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to read $VAULT_INIT_FILE." >&2
  exit 1
fi

compose --profile secrets up -d vault

status_json="$(compose exec -T vault vault status -format=json 2>/dev/null || true)"

if echo "$status_json" | jq -e '.initialized == false' >/dev/null 2>&1; then
  umask 077
  compose exec -T vault vault operator init -key-shares=1 -key-threshold=1 -format=json > "$VAULT_INIT_FILE"
  chmod 600 "$VAULT_INIT_FILE"
  status_json="$(compose exec -T vault vault status -format=json 2>/dev/null || true)"
  echo "Initialized Vault and wrote local init material to $VAULT_INIT_FILE."
fi

if [ ! -f "$VAULT_INIT_FILE" ]; then
  echo "Vault is initialized, but $VAULT_INIT_FILE is missing. Unseal manually with your saved key." >&2
  exit 1
fi

if echo "$status_json" | jq -e '.sealed == false' >/dev/null 2>&1; then
  echo "Vault is already unsealed."
else
  unseal_key="$(jq -r '.unseal_keys_b64[0]' "$VAULT_INIT_FILE")"
  compose exec -T vault vault operator unseal "$unseal_key" >/dev/null
  echo "Vault unsealed."
fi

compose exec -T vault vault status
