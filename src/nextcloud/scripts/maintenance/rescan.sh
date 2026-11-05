#!/bin/bash
# Heavy full-library scans (recrawl, duplicate hash scan, expensive repair).
# Only executed on-demand via `--now`, never in the periodic background loop.

readonly CRON_SCRIPT="/var/www/html/cron.php"

run_full_library_rescan() {
    log_info "Running on-demand full-library rescan..."
    run_step "Nextcloud system cron" runuser -u www-data -- php "$CRON_SCRIPT"
    run_frequent_tasks
    run_hourly_tasks
    run_daily_maintenance
    run_step "Recognize recrawl" occ_cmd recognize:recrawl --no-interaction
    run_step "Find duplicate files" occ_cmd duplicates:find-all --no-interaction
    run_step "Expensive maintenance repair" occ_cmd maintenance:repair --include-expensive --no-interaction
    log_info "Full maintenance suite completed."
}
