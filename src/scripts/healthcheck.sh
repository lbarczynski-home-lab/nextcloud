#!/bin/sh
set -e

STATUS_URL="http://localhost:80/status.php"
DATA_DIR="${NEXTCLOUD_DATA_DIR:-/var/www/html/data}"
TEST_FILE="$DATA_DIR/.healthcheck.tmp"

STATUS_OUTPUT=$(curl -s -f "$STATUS_URL" 2>/dev/null) || {
    echo "Healthcheck failed: Unable to connect to Nextcloud status endpoint ($STATUS_URL)"
    exit 1
}

INSTALLED=$(echo "$STATUS_OUTPUT" | grep -o '"installed":true' || true)
MAINTENANCE=$(echo "$STATUS_OUTPUT" | grep -o '"maintenance":false' || true)

if [ -z "$INSTALLED" ]; then
    echo "Healthcheck failed: Nextcloud is not fully installed ($STATUS_OUTPUT)"
    exit 1
fi

if [ -z "$MAINTENANCE" ]; then
    echo "Healthcheck failed: Nextcloud is in maintenance mode ($STATUS_OUTPUT)"
    exit 1
fi

if [ ! -d "$DATA_DIR" ]; then
    echo "Healthcheck failed: Data directory does not exist ($DATA_DIR)"
    exit 1
fi

if ! touch "$TEST_FILE" 2>/dev/null; then
    echo "Healthcheck failed: Data directory is not writable ($DATA_DIR)"
    exit 1
fi

rm -f "$TEST_FILE"

echo "Nextcloud is healthy!"
exit 0
