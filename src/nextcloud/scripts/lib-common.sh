#!/bin/bash
# Shared helpers sourced by the bootstrap, configuration, and worker scripts.

readonly NC_OCC_SCRIPT="/var/www/html/occ"
readonly NC_CONFIG_FILE="/var/www/html/config/config.php"

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

occ_cmd() {
    runuser -u www-data -- php "$NC_OCC_SCRIPT" "$@"
}

is_nextcloud_ready() {
    if [ ! -f "$NC_OCC_SCRIPT" ] || [ ! -f "$NC_CONFIG_FILE" ]; then
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

wait_for_installation() {
    local max_attempts=60
    local attempt=0

    log_info "Waiting for Nextcloud base installation to complete..."
    while [ "$attempt" -lt "$max_attempts" ]; do
        if is_nextcloud_ready; then
            log_info "Nextcloud installation detected and verified."
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 5
    done

    log_error "Nextcloud installation timed out after $((max_attempts * 5)) seconds."
    return 1
}
