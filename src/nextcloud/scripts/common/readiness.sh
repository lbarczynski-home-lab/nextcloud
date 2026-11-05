#!/bin/bash
# Requires occ.sh and logger.sh to be sourced first.

readonly NC_CONFIG_FILE="/var/www/html/config/config.php"

is_nextcloud_ready() {
    [ -f "$NC_OCC_SCRIPT" ] && [ -f "$NC_CONFIG_FILE" ] || return 1

    local status
    status=$(occ_cmd status --output=json 2>/dev/null || echo "{}")
    printf '%s' "$status" | jq -e '.installed == true and .maintenance == false and .needsDbUpgrade == false' >/dev/null 2>&1
}

heal_pending_upgrade_if_needed() {
    [ -f "$NC_OCC_SCRIPT" ] && [ -f "$NC_CONFIG_FILE" ] || return 0

    local status
    status=$(occ_cmd status --output=json 2>/dev/null || echo "{}")
    if printf '%s' "$status" | jq -e '.installed == true and .needsDbUpgrade == true' >/dev/null 2>&1; then
        log_info "Detected pending database/app upgrade (needsDbUpgrade=true) — running occ upgrade in a fresh PHP process..."
        if occ_cmd upgrade --no-interaction; then
            occ_cmd maintenance:mode --off --no-interaction >/dev/null 2>&1 || true
        else
            log_error "Automatic occ upgrade failed."
        fi
    fi
}

wait_for_installation() {
    local max_attempts=60
    local attempt=0

    log_info "Waiting for Nextcloud base installation to complete..."
    while [ "$attempt" -lt "$max_attempts" ]; do
        # Once /entrypoint.sh has finished and exec'd apache2, heal any stuck app/DB upgrade
        # so healthcheck.sh and dependent worker containers never deadlock on needsDbUpgrade=true.
        if pgrep -x apache2 >/dev/null 2>&1; then
            heal_pending_upgrade_if_needed
        fi
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
