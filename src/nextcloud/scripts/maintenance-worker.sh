#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logger.sh"
source "$SCRIPT_DIR/common/occ.sh"
source "$SCRIPT_DIR/common/readiness.sh"
source "$SCRIPT_DIR/common/security.sh"

readonly CYCLE_INTERVAL_SECONDS=300
readonly HOURLY_INTERVAL_CYCLES=12
readonly DAILY_MAINTENANCE_CYCLES=288
readonly CRON_SCRIPT="/var/www/html/cron.php"

# Must live on the shared ./scripts bind mount, not a container-local path
# like /var/run — otherwise `docker exec nextcloud .../maintenance-worker.sh
# --now` wouldn't see the lock held by the always-on worker container.
readonly LOCK_FILE="/scripts/.nextcloud-maintenance.lock"
readonly LOCK_PID_FILE="${LOCK_FILE}.pid"

acquire_lock() {
    local force="$1"

    exec 9>"$LOCK_FILE"

    if flock -n 9; then
        echo $$ >"$LOCK_PID_FILE"
        trap 'rm -f "$LOCK_PID_FILE"' EXIT
        return 0
    fi

    if [ "$force" -eq 1 ]; then
        local holder_pid
        holder_pid=$(cat "$LOCK_PID_FILE" 2>/dev/null || true)
        if [ -n "$holder_pid" ] && kill -0 "$holder_pid" 2>/dev/null; then
            log_info "Forcing takeover: terminating previous maintenance run (PID ${holder_pid})..."
            kill "$holder_pid" 2>/dev/null || true
            sleep 2
            kill -9 "$holder_pid" 2>/dev/null || true
        fi
        flock 9
        echo $$ >"$LOCK_PID_FILE"
        trap 'rm -f "$LOCK_PID_FILE"' EXIT
        return 0
    fi

    log_info "Another maintenance run is already in progress — skipping."
    exit 0
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

run_recognize_classification() {
    log_info "Executing Recognize AI classification..."
    execute_maintenance_step "Recognize classify" occ_cmd recognize:classify --no-interaction
    execute_maintenance_step "Recognize cluster faces" occ_cmd recognize:cluster-faces --no-interaction
}

run_recognize_model_update() {
    log_info "Checking for updated Recognize AI models..."
    execute_maintenance_step "Recognize download models" occ_cmd recognize:download-models --no-interaction
}

run_fulltextsearch_sync() {
    log_info "Executing periodic full-text search indexing..."
    execute_maintenance_step "Full-text search indexing" occ_cmd fulltextsearch:index --no-interaction
}

run_security_whitelist_refresh() {
    log_info "Refreshing bruteforce/rate-limit IP whitelist (covers dynamic public IP changes)..."
    execute_maintenance_step "Bruteforce whitelist refresh" refresh_security_whitelist
}

run_hourly_tasks() {
    log_info "Executing hourly maintenance tasks (search sync, AI recognition, security whitelist)..."
    run_fulltextsearch_sync
    run_recognize_classification
    run_security_whitelist_refresh
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
    log_info "Executing daily app updates, database optimization, file cleanup, and repair..."
    run_app_updates
    run_recognize_model_update
    execute_maintenance_step "Files cleanup" occ_cmd files:cleanup --no-interaction
    execute_maintenance_step "Database optimization" occ_cmd db:optimize --no-interaction
    execute_maintenance_step "Database add missing indices" occ_cmd db:add-missing-indices --no-interaction
    execute_maintenance_step "Database add missing primary keys" occ_cmd db:add-missing-primary-keys --no-interaction
    execute_maintenance_step "Database add missing columns" occ_cmd db:add-missing-columns --no-interaction
    execute_maintenance_step "Maintenance repair" occ_cmd maintenance:repair --include-expensive --no-interaction
}

# recognize:recrawl requeues the ENTIRE library for AI reprocessing on every
# call (not just what changed) — hourly recognize:classify already handles
# new files, so scheduling recrawl would mean the whole library gets
# reprocessed on a loop forever. duplicates:find-all does a full-library
# hash scan (upstream's own default cadence for this is every 5 days, and
# it has known OOM reports on large libraries). Neither belongs in the
# periodic schedule — only run via --now, when actually needed.
run_full_library_rescan() {
    log_info "Running full-library rescan (Recognize recrawl + duplicate scan)..."
    execute_maintenance_step "Recognize recrawl" occ_cmd recognize:recrawl --no-interaction
    execute_maintenance_step "Find duplicate files" occ_cmd duplicates:find-all --no-interaction
}

run_all_maintenance() {
    log_info "Starting full on-demand maintenance suite..."
    run_system_cron
    run_preview_generation
    run_memories_indexing
    run_hourly_tasks
    run_daily_maintenance
    run_full_library_rescan
    log_info "Full maintenance suite completed."
}

main() {
    local run_once=0
    local force=0
    for arg in "$@"; do
        case "$arg" in
        --now | --once) run_once=1 ;;
        --force) force=1 ;;
        esac
    done

    acquire_lock "$force"

    if [ "$run_once" -eq 1 ]; then
        if ! is_nextcloud_ready; then
            log_error "Nextcloud is not ready or in maintenance mode. Aborting."
            exit 1
        fi
        run_all_maintenance
        exit 0
    fi

    log_info "Maintenance worker started (light tasks: ${CYCLE_INTERVAL_SECONDS}s, hourly tasks: every ${HOURLY_INTERVAL_CYCLES} cycles, daily maintenance: every ${DAILY_MAINTENANCE_CYCLES} cycles)"

    local hourly_counter=0
    local daily_counter=0

    while true; do
        if is_nextcloud_ready; then
            run_preview_generation
            run_memories_indexing

            hourly_counter=$((hourly_counter + 1))
            if [ "$hourly_counter" -ge "$HOURLY_INTERVAL_CYCLES" ]; then
                run_hourly_tasks
                hourly_counter=0
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
