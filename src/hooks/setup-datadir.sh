#!/bin/sh
set -e

DATA_DIR="${NEXTCLOUD_DATA_DIR:-/var/nc-data}"

if [ -n "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
    chown -R www-data:root "$DATA_DIR" 2>/dev/null || true
    chmod 770 "$DATA_DIR" 2>/dev/null || true
fi
