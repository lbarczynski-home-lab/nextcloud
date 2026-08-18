#!/bin/sh
set -e

JOB_CLASS="${1:?Usage: $0 <job-class> [timeout-seconds]}"
TIMEOUT="${2:-3600}"

echo "Background job worker started (class: ${JOB_CLASS}, timeout: ${TIMEOUT}s)"

while true; do
    php /var/www/html/occ background-job:worker -t "$TIMEOUT" "$JOB_CLASS" || true
    echo "Background job worker restarting..."
    sleep 1
done
