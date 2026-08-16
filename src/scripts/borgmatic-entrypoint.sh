#!/bin/sh
set -e

echo "Starting Borgmatic initialization check..."

REPO_PATH="${BORG_REPO:?BORG_REPO is not set}"

if ! borgmatic info --repository "$REPO_PATH" >/dev/null 2>&1; then
    echo "Borg repository at $REPO_PATH not found or uninitialized. Initializing..."
    mkdir -p "$REPO_PATH"
    borgmatic init --encryption repokey --repository "$REPO_PATH"
    echo "Borg repository successfully initialized."
else
    echo "Borg repository at $REPO_PATH is already initialized and valid."
fi

echo "Starting Borgmatic daemon scheduler..."
exec borgmatic --stats --verbosity 1
