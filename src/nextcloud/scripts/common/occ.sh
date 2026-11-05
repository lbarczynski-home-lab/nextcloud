#!/bin/bash

readonly NC_OCC_SCRIPT="/var/www/html/occ"

occ_cmd() {
    runuser -u www-data -- php "$NC_OCC_SCRIPT" "$@"
}

list_contains() {
    grep -Fqx -- "$1" <<<"$2"
}

is_app_present() {
    local app_id="$1"
    occ_cmd app:list --output=json 2>/dev/null |
        jq -e --arg app "$app_id" '((.enabled // {}) + (.disabled // {})) | has($app)' >/dev/null 2>&1
}
