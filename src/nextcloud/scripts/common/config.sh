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
