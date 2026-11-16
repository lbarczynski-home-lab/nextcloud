#!/bin/bash
# Requires occ.sh to be sourced first.

refresh_security_whitelist() {
    local public_ip
    public_ip=$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null || true)

    local whitelist_json='["127.0.0.1/32","10.0.0.0/8","172.16.0.0/12"'
    if [[ "$public_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        whitelist_json="${whitelist_json},\"${public_ip}/32\""
    fi
    whitelist_json="${whitelist_json}]"

    occ_cmd config:app:set bruteforcesettings whitelist --value="$whitelist_json"
}
