#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-common.sh"

readonly TIMEOUT="${1:-3600}"

log_info "Task processing worker started (timeout: ${TIMEOUT}s)"
trap 'log_info "Termination signal received. Exiting..."; exit 0' SIGTERM SIGINT

while true; do
    if is_nextcloud_ready; then
        occ_cmd taskprocessing:worker -v -t "$TIMEOUT" || true
        log_info "Worker finished or timed out, restarting in 2 seconds..."
        sleep 2
    else
        log_info "Nextcloud is not ready or in maintenance mode. Retrying in 10 seconds..."
        sleep 10
    fi
done
