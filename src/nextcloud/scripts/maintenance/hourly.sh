#!/bin/bash
# Hourly maintenance tasks (search indexing, AI classification, IP whitelist refresh).

run_hourly_tasks() {
    log_info "Running hourly maintenance tasks..."
    run_step "Full-text search indexing" occ_cmd fulltextsearch:index --no-interaction
    run_step "Recognize classify" occ_cmd recognize:classify --no-interaction
    run_step "Recognize cluster faces" occ_cmd recognize:cluster-faces --no-interaction
    run_step "Bruteforce whitelist refresh" refresh_security_whitelist
}
