#!/bin/bash

readonly NC_OCC_SCRIPT="/var/www/html/occ"

occ_cmd() {
    runuser -u www-data -- php "$NC_OCC_SCRIPT" "$@"
}

list_contains() {
    grep -qx "$1" <<<"$2"
}
