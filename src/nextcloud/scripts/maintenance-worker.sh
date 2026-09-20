#!/bin/bash
set -eo pipefail

readonly CYCLE_INTERVAL_SECONDS=900
readonly FTS_SYNC_INTERVAL_CYCLES=4
readonly DAILY_MAINTENANCE_CYCLES=96
readonly OCC_SCRIPT="/var/www/html/occ"
readonly CRON_SCRIPT="/var/www/html/cron.php"
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

execute_maintenance_step() {
    local desc="$1"
    shift
    local output
    local exit_code=0

    if output=$("$@" 2>&1); then
        return 0
    else
        exit_code=$?
        log_error "${desc} failed (exit code: ${exit_code})"
        if [ -n "$output" ]; then
            printf '%s\n' "$output" >&2
        fi
        return 0
    fi
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

run_system_cron() {
    log_info "Executing Nextcloud system cron..."
    execute_maintenance_step "Nextcloud system cron" runuser -u www-data -- php "$CRON_SCRIPT"
}

run_preview_generation() {
    log_info "Executing background preview pre-generation..."
    execute_maintenance_step "Background preview pre-generation" occ_cmd preview:pre-generate
}

run_memories_indexing() {
    log_info "Executing Memories metadata indexing..."
    execute_maintenance_step "Memories metadata indexing" occ_cmd memories:index
}

run_recognize_ai() {
    log_info "Executing Recognize AI models and classification..."
    execute_maintenance_step "Recognize download models" occ_cmd recognize:download-models --no-interaction
    execute_maintenance_step "Recognize classify" occ_cmd recognize:classify --no-interaction
    execute_maintenance_step "Recognize cluster faces" occ_cmd recognize:cluster-faces --no-interaction
}

run_fulltextsearch_sync() {
    log_info "Executing periodic full-text search indexing..."
    execute_maintenance_step "Full-text search indexing" occ_cmd fulltextsearch:index --no-interaction
}

run_app_updates() {
    log_info "Checking and updating Nextcloud applications..."
    local exit_code=0
    if occ_cmd app:update --all --no-interaction; then
        log_info "Nextcloud applications update completed successfully."
    else
        exit_code=$?
        log_error "Failed to update one or more Nextcloud applications (exit code: ${exit_code})."
    fi
}

run_daily_maintenance() {
    log_info "Executing periodic app updates, database optimization, file cleanup, and repair..."
    run_app_updates
    execute_maintenance_step "Recognize recrawl" occ_cmd recognize:recrawl --no-interaction
    execute_maintenance_step "Files cleanup" occ_cmd files:cleanup --no-interaction
    execute_maintenance_step "Database optimization" occ_cmd db:optimize --no-interaction
    execute_maintenance_step "Database add missing indices" occ_cmd db:add-missing-indices --no-interaction
    execute_maintenance_step "Maintenance repair" occ_cmd maintenance:repair --include-expensive --no-interaction
    execute_maintenance_step "Find duplicate files" occ_cmd duplicates:find-all --no-interaction
}

run_all_maintenance() {
    log_info "Starting full on-demand maintenance suite..."
    run_system_cron
    run_preview_generation
    run_memories_indexing
    execute_maintenance_step "Recognize recrawl" occ_cmd recognize:recrawl --no-interaction
    run_recognize_ai
    run_fulltextsearch_sync
    run_daily_maintenance
    log_info "Full maintenance suite completed."
}

main() {
    if [ "${1:-}" = "--now" ] || [ "${1:-}" = "--once" ]; then
        if ! is_nextcloud_ready; then
            log_error "Nextcloud is not ready or in maintenance mode. Aborting."
            exit 1
        fi
        run_all_maintenance
        exit 0
    fi

    log_info "Maintenance worker started (preview: ${CYCLE_INTERVAL_SECONDS}s, search sync: every ${FTS_SYNC_INTERVAL_CYCLES} cycles, daily maintenance & app updates: every ${DAILY_MAINTENANCE_CYCLES} cycles)"

    local fts_counter=0
    local daily_counter=0

    while true; do
        if is_nextcloud_ready; then
            run_preview_generation
            run_memories_indexing
            run_recognize_ai

            fts_counter=$((fts_counter + 1))
            if [ "$fts_counter" -ge "$FTS_SYNC_INTERVAL_CYCLES" ]; then
                run_fulltextsearch_sync
                fts_counter=0
            fi

            daily_counter=$((daily_counter + 1))
            if [ "$daily_counter" -ge "$DAILY_MAINTENANCE_CYCLES" ]; then
                run_daily_maintenance
                daily_counter=0
            fi
        else
            log_info "Nextcloud is not ready or in maintenance mode. Skipping cycle."
        fi

        sleep "$CYCLE_INTERVAL_SECONDS"
    done
}

main "$@"
