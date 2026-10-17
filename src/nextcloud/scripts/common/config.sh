#!/bin/bash
# Requires occ.sh to be sourced first.

# Never overwrites a value that's already set — for settings an admin
# is expected to retune from the web UI after first setup.
set_default_if_unset() {
    local app="$1" key="$2" value="$3"
    local current
    current=$(occ_cmd config:app:get "$app" "$key" 2>/dev/null || true)
    if [ -z "$current" ]; then
        occ_cmd config:app:set "$app" "$key" --value="$value"
    fi
}

# Sets a list-valued system key to exactly the given values. Setting
# indices alone would leave stale trailing entries behind whenever the
# list shrinks, so anything past the new end is deleted afterwards.
set_system_list() {
    local key="$1"
    shift
    local idx=0
    local value
    for value in "$@"; do
        occ_cmd config:system:set "$key" "$idx" --value="$value"
        idx=$((idx + 1))
    done
    while occ_cmd config:system:get "$key" "$idx" >/dev/null 2>&1; do
        occ_cmd config:system:delete "$key" "$idx"
        idx=$((idx + 1))
    done
}
