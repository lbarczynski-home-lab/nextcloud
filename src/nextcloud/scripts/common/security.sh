#!/bin/bash
# Detects the current public IP and refreshes the bruteforce/rate-limit
# whitelist. Shared between configure-nextcloud.sh (on every start) and
# maintenance-worker.sh (hourly, to pick up dynamic public IP changes
# without needing a restart). Requires occ.sh to be sourced first.

refresh_security_whitelist() {
    local public_ip
    public_ip=$(curl -s --max-time 5 https://api.ipify.org || curl -s --max-time 5 https://ifconfig.me || true)

    local whitelist_json='["127.0.0.1/32","10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"'
    if [ -n "$public_ip" ]; then
        whitelist_json="${whitelist_json},\"${public_ip}/32\""
    fi
    whitelist_json="${whitelist_json}]"

    occ_cmd config:app:set bruteforcesettings whitelist --value="$whitelist_json"
}
