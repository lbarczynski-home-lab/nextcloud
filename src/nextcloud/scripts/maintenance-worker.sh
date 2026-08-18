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
    runuser -u www-data -- php "$CRON_SCRIPT" >/dev/null 2>&1 || true
}

run_preview_generation() {
    log_info "Executing background preview pre-generation..."
    occ_cmd preview:pre-generate >/dev/null 2>&1 || true
}

run_memories_indexing() {
    log_info "Executing Memories metadata indexing..."
    occ_cmd memories:index >/dev/null 2>&1 || true
}

run_recognize_ai() {
    log_info "Executing Recognize AI models and classification..."
    occ_cmd recognize:download-models --no-interaction >/dev/null 2>&1 || true
    occ_cmd recognize:classify --no-interaction >/dev/null 2>&1 || true
    occ_cmd recognize:cluster-faces --no-interaction >/dev/null 2>&1 || true
}

run_fulltextsearch_sync() {
    log_info "Executing periodic full-text search indexing..."
    occ_cmd fulltextsearch:index --no-interaction >/dev/null 2>&1 || true
}

run_daily_maintenance() {
    log_info "Executing periodic database optimization, file cleanup, and repair..."
    occ_cmd recognize:recrawl --no-interaction >/dev/null 2>&1 || true
    occ_cmd files:cleanup --no-interaction >/dev/null 2>&1 || true
    occ_cmd db:optimize --no-interaction >/dev/null 2>&1 || true
    occ_cmd maintenance:repair --include-expensive --no-interaction >/dev/null 2>&1 || true
}

run_all_maintenance() {
    log_info "Starting full on-demand maintenance suite..."
    run_system_cron
    run_preview_generation
    run_memories_indexing
    occ_cmd recognize:recrawl --no-interaction >/dev/null 2>&1 || true
    run_recognize_ai
    run_fulltextsearch_sync
    run_daily_maintenance
    log_info "Full maintenance suite completed successfully."
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

    log_info "Maintenance worker started (preview: ${CYCLE_INTERVAL_SECONDS}s, search sync: every ${FTS_SYNC_INTERVAL_CYCLES} cycles, db cleanup: every ${DAILY_MAINTENANCE_CYCLES} cycles)"

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
