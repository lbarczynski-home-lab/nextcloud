#!/bin/bash
set -eo pipefail

readonly OCC_SCRIPT="/var/www/html/occ"
readonly CONFIG_FILE="/var/www/html/config/config.php"
readonly TIMEOUT="${1:-3600}"

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

occ_cmd() {
    runuser -u www-data -- php "$OCC_SCRIPT" "$@"
}

is_nextcloud_ready() {
    if [ ! -f "$OCC_SCRIPT" ] || [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi

    local status
    status=$(occ_cmd status --output=json 2>/dev/null || echo "{}")

    local installed
    installed=$(echo "$status" | grep -o '"installed":true' || true)

    local maintenance
    maintenance=$(echo "$status" | grep -o '"maintenance":false' || true)

    [ -n "$installed" ] && [ -n "$maintenance" ]
}

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
