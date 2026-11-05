#!/bin/bash
set -euo pipefail

token_input=""
output_file=""

while getopts "t:o:" opt; do
  case $opt in
    t) token_input="$OPTARG" ;;
    o) output_file="$OPTARG" ;;
    *) echo "Usage: $0 -t <token> -o <output_file>" >&2; exit 1 ;;
  esac
done

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed." >&2
    exit 1
fi

if [ -z "$token_input" ] || [ -z "$output_file" ]; then
    echo "Error: Both token (-t) and output file (-o) are required." >&2
    exit 1
fi

decoded_payload=$(printf '%s' "$token_input" | base64 -d)

account_tag=$(printf '%s' "$decoded_payload" | jq -er '.a | select(type == "string" and length > 0)')
tunnel_id=$(printf '%s' "$decoded_payload" | jq -er '.t | select(type == "string" and length > 0)')
tunnel_secret=$(printf '%s' "$decoded_payload" | jq -er '.s | select(type == "string" and length > 0)')

mkdir -p "$(dirname "$output_file")"
jq -n \
  --arg at "$account_tag" \
  --arg tid "$tunnel_id" \
  --arg ts "$tunnel_secret" \
  '{AccountTag: $at, TunnelID: $tid, TunnelSecret: $ts}' > "$output_file"
