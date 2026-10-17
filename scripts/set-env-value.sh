#!/bin/bash
# Replaces the KEY=... line of an env file with KEY=<value>, taking the
# value literally — unlike sed, secrets containing &, | or \ survive intact.
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <env_file> <key> <value>" >&2
    exit 1
fi

env_file="$1"
key="$2"
value="$3"

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

found=0
while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == "${key}="* ]]; then
        printf '%s=%s\n' "$key" "$value"
        found=1
    else
        printf '%s\n' "$line"
    fi
done <"$env_file" >"$tmp_file"

if [ "$found" -ne 1 ]; then
    echo "Error: ${key} not found in ${env_file}" >&2
    exit 1
fi

# Write back in place to keep the original file's permissions.
cat "$tmp_file" >"$env_file"
