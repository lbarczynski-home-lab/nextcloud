#!/bin/bash
# Daily maintenance tasks (executed once per day between 01:00 and 05:00 UTC).

run_app_updates() {
    log_info "Checking and updating Nextcloud applications..."
    local exit_code=0
    if occ_cmd app:update --all --no-interaction; then
        log_info "Nextcloud applications update completed successfully."
    else
        exit_code=$?
        log_error "occ app:update --all exited with code ${exit_code} (possible in-process PHP class skew) — running occ upgrade in a fresh process..."
        if occ_cmd upgrade --no-interaction; then
            occ_cmd app:update --all --no-interaction || true
        fi
    fi
    heal_pending_upgrade_if_needed
}

run_daily_maintenance() {
    log_info "Running daily app updates, database schema checks, file cleanup, and repair..."
    run_app_updates
    run_step "Recognize download models" occ_cmd recognize:download-models --no-interaction
    run_step "Files cleanup" occ_cmd files:cleanup --no-interaction
    run_step "Database add missing indices" occ_cmd db:add-missing-indices --no-interaction
    run_step "Database add missing primary keys" occ_cmd db:add-missing-primary-keys --no-interaction
    run_step "Database add missing columns" occ_cmd db:add-missing-columns --no-interaction
    run_step "Maintenance repair" occ_cmd maintenance:repair --no-interaction
}

is_daily_maintenance_due() {
    local last_run_date="$1"
    local hour
    hour=$((10#$(date -u +%H)))
    [ "$hour" -ge "$DAILY_WINDOW_START_HOUR_UTC" ] &&
        [ "$hour" -lt "$DAILY_WINDOW_END_HOUR_UTC" ] &&
        [ "$last_run_date" != "$(date -u +%F)" ]
}
