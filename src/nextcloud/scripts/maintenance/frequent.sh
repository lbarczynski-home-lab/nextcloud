#!/bin/bash
# Frequent maintenance tasks (executed every 5 minutes).

run_frequent_tasks() {
    run_step "Background preview pre-generation" occ_cmd preview:pre-generate
    run_step "Memories metadata indexing" occ_cmd memories:index
}
