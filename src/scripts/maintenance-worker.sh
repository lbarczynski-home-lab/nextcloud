#!/bin/bash
set -eo pipefail

readonly CYCLE_INTERVAL_SECONDS=900
readonly FTS_SYNC_INTERVAL_CYCLES=4
readonly OCC_SCRIPT="/var/www/html/occ"
readonly CONFIG_FILE="/var/www/html/config/config.php"

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

run_preview_generation() {
    log_info "Executing background preview pre-generation..."
    occ_cmd preview:pre-generate >/dev/null 2>&1 || true
}

run_fulltextsearch_sync() {
    log_info "Executing periodic full-text search indexing..."
    occ_cmd fulltextsearch:index --no-interaction >/dev/null 2>&1 || true
}

main() {
    log_info "Maintenance worker started (preview: ${CYCLE_INTERVAL_SECONDS}s, search sync: every ${FTS_SYNC_INTERVAL_CYCLES} cycles)"

    local cycle_counter=0

    while true; do
        if is_nextcloud_ready; then
            run_preview_generation

            cycle_counter=$((cycle_counter + 1))
            if [ "$cycle_counter" -ge "$FTS_SYNC_INTERVAL_CYCLES" ]; then
                run_fulltextsearch_sync
                cycle_counter=0
            fi
        else
            log_info "Nextcloud is not ready or in maintenance mode. Skipping cycle."
        fi

        sleep "$CYCLE_INTERVAL_SECONDS"
    done
}

main "$@"
