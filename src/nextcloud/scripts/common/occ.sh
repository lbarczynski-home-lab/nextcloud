#!/bin/bash
# Wrapper for running Nextcloud's occ CLI as the web server user. No dependencies.

readonly NC_OCC_SCRIPT="/var/www/html/occ"

occ_cmd() {
    runuser -u www-data -- php "$NC_OCC_SCRIPT" "$@"
}

# Checks whether $1 is present (as a line) in the newline-separated list $2 —
# used to test app-id membership against a cached `occ app:list` snapshot
# without re-querying occ for every app.
list_contains() {
    grep -qx "$1" <<<"$2"
}
