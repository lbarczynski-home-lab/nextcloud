#!/bin/bash
# Wrapper for running Nextcloud's occ CLI as the web server user. No dependencies.

readonly NC_OCC_SCRIPT="/var/www/html/occ"

occ_cmd() {
    runuser -u www-data -- php "$NC_OCC_SCRIPT" "$@"
}
