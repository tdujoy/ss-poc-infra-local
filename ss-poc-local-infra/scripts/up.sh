#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_common.sh"

# shellcheck disable=SC2086
compose $PROFILES up -d
"$SCRIPT_DIR/setup-garage.sh"
"$SCRIPT_DIR/unseal-vault.sh"
"$SCRIPT_DIR/health.sh"
