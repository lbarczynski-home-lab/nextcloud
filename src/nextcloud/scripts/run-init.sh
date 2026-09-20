#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logger.sh"
source "$SCRIPT_DIR/common/occ.sh"
source "$SCRIPT_DIR/common/readiness.sh"

wait_for_installation
"$SCRIPT_DIR/configure-nextcloud.sh"
