#!/bin/bash
# Core system settings, Redis/APCu caching, SMTP mail, notify_push, and security baseline.

configure_system() {
    log_info "Configuring system, network, locale, and chunking parameters..."

    occ_cmd config:system:set default_language --value="${NC_default_language:?}"
    occ_cmd config:system:set default_locale --value="${NC_default_locale:?}"
    occ_cmd config:system:set default_phone_region --value="${NC_default_phone_region:?}"
    occ_cmd config:system:set maintenance_window_start --type=integer --value=1
    occ_cmd config:system:set overwriteprotocol --value="${OVERWRITEPROTOCOL:-https}"
    occ_cmd config:system:set overwritehost --value="$OVERWRITEHOST"
    occ_cmd config:system:set overwrite.cli.url --value="${OVERWRITECLIURL:-https://${OVERWRITEHOST}}"
    occ_cmd config:system:set hide_login_form --type=boolean --value=true
    occ_cmd config:system:set lost_password_link --value="disabled"
    occ_cmd config:system:set allow_user_to_change_display_name --type=boolean --value=false
    occ_cmd config:system:set serverid --type=integer --value=1
    occ_cmd config:system:delete server_id >/dev/null 2>&1 || true
    occ_cmd config:system:set trashbin_retention_obligation --value="$NEXTCLOUD_TRASHBIN_RETENTION_OBLIGATION"
    occ_cmd config:system:set versions_retention_obligation --value="$NEXTCLOUD_VERSIONS_RETENTION_OBLIGATION"

    occ_cmd twofactorauth:enforce --off --no-interaction 2>/dev/null || true

    local trusted_domains
    read -ra trusted_domains <<<"${NEXTCLOUD_TRUSTED_DOMAINS:-$OVERWRITEHOST}"
    set_system_list trusted_domains "localhost" "${trusted_domains[@]}"

    local trusted_proxies
    read -ra trusted_proxies <<<"$TRUSTED_PROXIES"
    set_system_list trusted_proxies "${trusted_proxies[@]}"

    set_system_list forwarded_for_headers "HTTP_CF_CONNECTING_IP" "HTTP_X_FORWARDED_FOR"

    occ_cmd config:system:delete max_chunk_size >/dev/null 2>&1 || true
    occ_cmd config:app:set files max_chunk_size --value="52428800"
    occ_cmd config:app:delete dav max_chunk_size >/dev/null 2>&1 || true

    occ_cmd background:cron
}

configure_caching() {
    log_info "Configuring APCu and Redis caching..."

    occ_cmd config:system:set filelocking.enabled --type=boolean --value=true
    occ_cmd config:system:set memcache.local --value="\OC\Memcache\APCu"
    occ_cmd config:system:set memcache.distributed --value="\OC\Memcache\Redis"
    occ_cmd config:system:set memcache.locking --value="\OC\Memcache\Redis"

    occ_cmd config:system:set redis host --value="$REDIS_HOST"
    occ_cmd config:system:set redis port --type=integer --value="$REDIS_HOST_PORT"
    occ_cmd config:system:set redis password --value="$REDIS_HOST_PASSWORD"
    occ_cmd config:system:set redis timeout --type=float --value=1.5
}

configure_smtp() {
    log_info "Configuring SMTP mail settings..."

    local from_user="${SMTP_FROM%@*}"
    local from_domain="${SMTP_FROM#*@}"

    occ_cmd config:system:set mail_smtpmode --value="smtp"
    occ_cmd config:system:set mail_smtphost --value="$SMTP_HOST"
    occ_cmd config:system:set mail_smtpport --type=integer --value="$SMTP_PORT"
    occ_cmd config:system:set mail_smtpauth --type=integer --value=1
    occ_cmd config:system:set mail_smtpauthtype --value="LOGIN"
    occ_cmd config:system:set mail_smtpname --value="$SMTP_USERNAME"
    occ_cmd config:system:set mail_smtppassword --value="$SMTP_PASSWORD"

    if [ "$SMTP_PORT" = "465" ]; then
        occ_cmd config:system:set mail_smtpsecure --value="ssl"
    else
        occ_cmd config:system:set mail_smtpsecure --value="tls"
    fi

    occ_cmd config:system:set mail_from_address --value="$from_user"
    occ_cmd config:system:set mail_domain --value="$from_domain"
}

configure_client_push() {
    log_info "Configuring Client Push (notify_push)..."
    occ_cmd notify_push:setup "https://${OVERWRITEHOST}/push" --no-interaction
}

configure_security_baseline() {
    log_info "Configuring Brute Force & Rate Limit Protection..."
    occ_cmd config:system:set ratelimit.protection.enabled --type=boolean --value=true
    occ_cmd config:app:set bruteforcesettings apply_allowlist_to_ratelimit --value="0"
    refresh_security_whitelist
}
