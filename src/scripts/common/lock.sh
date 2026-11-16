#!/bin/bash
# Shared cross-container lock (stored on the shared /var/www/html/config volume)
# used by both configure-nextcloud.sh and maintenance-worker.sh so configuration
# reconciliation and maintenance tasks never run concurrently.
# Requires logger.sh to be sourced first.

readonly NC_LOCK_FILE="/var/www/html/config/.nextcloud-maintenance.lock"
readonly NC_LOCK_TIMEOUT=300

acquire_lock() {
    local wait_for_lock="${1:-0}"

    exec 9>"$NC_LOCK_FILE"
    if [ "$wait_for_lock" -eq 1 ]; then
        if ! flock -w "$NC_LOCK_TIMEOUT" 9; then
            log_error "Timed out after ${NC_LOCK_TIMEOUT}s waiting for lock ($NC_LOCK_FILE)."
            exec 9>&-
            return 1
        fi
        return 0
    fi

    if ! flock -n 9; then
        log_info "Another configuration or maintenance operation is in progress — skipping."
        exec 9>&-
        return 1
    fi
    return 0
}

release_lock() {
    exec 9>&- 2>/dev/null || true
}
