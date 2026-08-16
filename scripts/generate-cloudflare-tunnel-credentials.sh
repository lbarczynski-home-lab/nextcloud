#!/bin/bash
set -e

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

decoded_payload=$(echo "$token_input" | base64 -d)

account_tag=$(echo "$decoded_payload" | jq -r '.a')
tunnel_id=$(echo "$decoded_payload" | jq -r '.t')
tunnel_secret=$(echo "$decoded_payload" | jq -r '.s')

jq -n \
  --arg at "$account_tag" \
  --arg tid "$tunnel_id" \
  --arg ts "$tunnel_secret" \
  '{AccountTag: $at, TunnelID: $tid, TunnelSecret: $ts}' > "$output_file"
