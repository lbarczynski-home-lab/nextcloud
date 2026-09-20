#!/bin/bash
# Entry point for the background init sequence: wait for the base Nextcloud
# installer to finish, then run the one-time bootstrap (Tier 1) followed by
# the always-reconciled runtime configuration (Tier 2).
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-common.sh"

wait_for_installation
"$SCRIPT_DIR/bootstrap-once.sh"
"$SCRIPT_DIR/configure-nextcloud.sh"
