#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logger.sh"
source "$SCRIPT_DIR/common/lock.sh"
source "$SCRIPT_DIR/common/occ.sh"
source "$SCRIPT_DIR/common/readiness.sh"
source "$SCRIPT_DIR/common/security.sh"

readonly CYCLE_INTERVAL_SECONDS=300
readonly HOURLY_INTERVAL_CYCLES=12
readonly DAILY_WINDOW_START_HOUR_UTC=1
readonly DAILY_WINDOW_END_HOUR_UTC=5

hourly_counter=0
last_daily_run_date=""

run_step() {
    local desc="$1"
    shift
    local output
    local exit_code=0

    log_info "${desc}..."
    if ! output=$("$@" 2>&1); then
        exit_code=$?
        log_error "${desc} failed (exit code: ${exit_code})"
        [ -n "$output" ] && printf '%s\n' "$output" >&2
    fi
    return 0
}

source "$SCRIPT_DIR/maintenance/frequent.sh"
source "$SCRIPT_DIR/maintenance/hourly.sh"
source "$SCRIPT_DIR/maintenance/daily.sh"
source "$SCRIPT_DIR/maintenance/rescan.sh"

run_periodic_cycle() {
    run_frequent_tasks

    hourly_counter=$((hourly_counter + 1))
    if [ "$hourly_counter" -ge "$HOURLY_INTERVAL_CYCLES" ]; then
        run_hourly_tasks
        hourly_counter=0
    fi

    if is_daily_maintenance_due "$last_daily_run_date"; then
        run_daily_maintenance
        last_daily_run_date=$(date -u +%F)
    fi
}

main() {
    local run_once=0
    local force=0
    local arg
    for arg in "$@"; do
        case "$arg" in
        --now | --once) run_once=1 ;;
        --force) force=1 ;;
        esac
    done

    if [ "$run_once" -eq 1 ]; then
        if ! acquire_lock "$force"; then
            [ "$force" -eq 1 ] && exit 1
            exit 0
        fi
        heal_pending_upgrade_if_needed
        if ! is_nextcloud_ready; then
            log_error "Nextcloud is not ready or in maintenance mode. Aborting."
            release_lock
            exit 1
        fi
        run_full_library_rescan
        release_lock
        exit 0
    fi

    log_info "Maintenance worker started (frequent: ${CYCLE_INTERVAL_SECONDS}s, hourly: every ${HOURLY_INTERVAL_CYCLES} cycles, daily: ${DAILY_WINDOW_START_HOUR_UTC}:00-${DAILY_WINDOW_END_HOUR_UTC}:00 UTC)"

    while true; do
        if is_nextcloud_ready; then
            if acquire_lock 0; then
                run_periodic_cycle
                release_lock
            fi
        else
            log_info "Nextcloud is not ready or in maintenance mode. Skipping cycle."
        fi
        sleep "$CYCLE_INTERVAL_SECONDS"
    done
}

main "$@"
