#!/bin/bash
# Entry point for the background init sequence: wait for the base Nextcloud
# installer to finish, then reconcile the runtime configuration.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-common.sh"

wait_for_installation
"$SCRIPT_DIR/configure-nextcloud.sh"
