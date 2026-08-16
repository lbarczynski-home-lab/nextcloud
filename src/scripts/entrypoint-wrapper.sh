#!/bin/bash
set -e

if [ -f /scripts/init-nextcloud.sh ]; then
    /scripts/init-nextcloud.sh &
fi

exec /entrypoint.sh "$@"
