#!/bin/sh
set -e

STATUS_URL="http://127.0.0.1:80/status.php"
DATA_DIR="${NEXTCLOUD_DATA_DIR:-/var/nc-data}"

STATUS_OUTPUT=$(curl -sf -H "Host: localhost" "$STATUS_URL" 2>/dev/null) || {
    echo "Healthcheck failed: Unable to connect to Nextcloud status endpoint ($STATUS_URL)"
    exit 1
}

if ! printf '%s' "$STATUS_OUTPUT" | jq -e '.installed == true and .maintenance == false and .needsDbUpgrade == false' >/dev/null 2>&1; then
    echo "Healthcheck failed: Nextcloud is not ready ($STATUS_OUTPUT)"
    exit 1
fi

if [ ! -d "$DATA_DIR" ] || ! runuser -u www-data -- test -w "$DATA_DIR" 2>/dev/null; then
    echo "Healthcheck failed: Data directory is missing or not writable ($DATA_DIR)"
    exit 1
fi

echo "Nextcloud is healthy!"
exit 0
