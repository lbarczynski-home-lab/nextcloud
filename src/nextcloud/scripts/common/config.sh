#!/bin/bash
# Requires occ.sh to be sourced first.

set_default_if_unset() {
    local app="$1"
    local key="$2"
    local default_value="$3"
    local current
    current=$(occ_cmd config:app:get "$app" "$key" 2>/dev/null || true)
    if [ -z "$current" ]; then
        occ_cmd config:app:set "$app" "$key" --value="$default_value" >/dev/null
    fi
}

# Sets a list-valued system key to exactly the given values. Deleting the
# parent array key first ensures sparse indices are cleared before writing 0..N-1.
set_system_list() {
    local key="$1"
    shift
    occ_cmd config:system:delete "$key" >/dev/null 2>&1 || true
    local idx=0
    local value
    for value in "$@"; do
        occ_cmd config:system:set "$key" "$idx" --value="$value"
        idx=$((idx + 1))
    done
}
