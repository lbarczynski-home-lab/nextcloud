#!/bin/bash
set -e

DATA_DIR="${NEXTCLOUD_DATA_DIR:-/var/nc-data}"
if [ -n "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
    # Top-level only: a recursive chown walks the whole NFS-backed library
    # on every start, and everything below is created by www-data anyway.
    chown www-data:root "$DATA_DIR" 2>/dev/null || true
    chmod 770 "$DATA_DIR" 2>/dev/null || true
fi

if [ -f /scripts/run-init.sh ]; then
    /scripts/run-init.sh &
fi

exec /entrypoint.sh "$@"
