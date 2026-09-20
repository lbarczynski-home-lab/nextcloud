#!/bin/bash
# Idempotent app-config helper for settings an admin owns after first setup.
# Requires occ.sh to be sourced first.

# Sets app-config key to $3 only if it currently has no value — for
# settings an admin is expected to retune from the web UI afterwards
# (e.g. Recognize feature toggles). Never overwrites an existing value,
# so it stays correct on every restart without a one-time-only marker.
set_default_if_unset() {
    local app="$1" key="$2" value="$3"
    local current
    current=$(occ_cmd config:app:get "$app" "$key" 2>/dev/null || true)
    if [ -z "$current" ]; then
        occ_cmd config:app:set "$app" "$key" --value="$value"
    fi
}
