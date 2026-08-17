#!/bin/bash
set -eo pipefail

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

occ_cmd() {
    runuser -u www-data -- php /var/www/html/occ "$@"
}

validate_environment() {
    log_info "Validating required environment variables..."

    local required_vars=(
        OVERWRITEHOST
        TRUSTED_PROXIES
        NC_default_phone_region
        NEXTCLOUD_MAIN_USER
        REDIS_HOST
        REDIS_HOST_PORT
        REDIS_HOST_PASSWORD
        OIDC_CLIENT_ID
        OIDC_CLIENT_SECRET
        OIDC_PROVIDER_URL
        OPENAI_API_KEY
        OPENAI_API_BASE_URL
        SMTP_HOST
        SMTP_PORT
        SMTP_USERNAME
        SMTP_PASSWORD
        SMTP_FROM
        COTURN_SECRET
        COTURN_HOST
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ "${#missing_vars[@]}" -gt 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
}

wait_for_installation() {
    local max_attempts=60
    local attempt=0

    log_info "Waiting for Nextcloud base installation to complete..."
    while [ "$attempt" -lt "$max_attempts" ]; do
        if [ -f /var/www/html/occ ] && [ -f /var/www/html/config/config.php ]; then
            local status
            status=$(occ_cmd status --output=json 2>/dev/null || echo "{}")
            if echo "$status" | grep -q '"installed":true'; then
                log_info "Nextcloud installation detected and verified."
                return 0
            fi
        fi
        attempt=$((attempt + 1))
        sleep 5
    done

    log_error "Nextcloud installation timed out after $((max_attempts * 5)) seconds."
    return 1
}

configure_system() {
    log_info "Configuring system, network, and chunking parameters..."

    occ_cmd config:system:set default_phone_region --value="$NC_default_phone_region"
    occ_cmd config:system:set maintenance_window_start --type=integer --value=1
    occ_cmd config:system:set overwriteprotocol --value="https"
    occ_cmd config:system:set overwritehost --value="$OVERWRITEHOST"
    occ_cmd config:system:set overwrite.cli.url --value="https://${OVERWRITEHOST}"
    occ_cmd config:system:set hide_login_form --type=boolean --value=true
    occ_cmd config:system:set lost_password_link --value="disabled"
    occ_cmd config:system:set allow_user_to_change_display_name --type=boolean --value=false

    local idx=0
    for proxy in $TRUSTED_PROXIES; do
        occ_cmd config:system:set trusted_proxies "$idx" --value="$proxy"
        idx=$((idx + 1))
    done

    occ_cmd config:system:set forwarded_for_headers 0 --value="HTTP_CF_CONNECTING_IP"
    occ_cmd config:system:set forwarded_for_headers 1 --value="HTTP_X_FORWARDED_FOR"

    occ_cmd config:system:set max_chunk_size --type=integer --value=52428800
    occ_cmd config:app:set files max_chunk_size --value="52428800"
    occ_cmd config:app:set dav max_chunk_size --value="52428800"

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

configure_previews() {
    log_info "Configuring preview providers and dimensions..."

    occ_cmd config:system:set enable_previews --type=boolean --value=true
    occ_cmd config:system:set preview_max_x --type=integer --value=2048
    occ_cmd config:system:set preview_max_y --type=integer --value=2048
    occ_cmd config:system:set preview_max_filesize_image --type=integer --value=50

    local providers=(
        "OC\Preview\PNG"
        "OC\Preview\JPEG"
        "OC\Preview\GIF"
        "OC\Preview\BMP"
        "OC\Preview\XBitmap"
        "OC\Preview\MP3"
        "OC\Preview\TXT"
        "OC\Preview\MarkDown"
        "OC\Preview\PDF"
        "OC\Preview\Movie"
        "OC\Preview\HEIC"
        "OC\Preview\WebP"
        "OC\Preview\SVG"
    )

    local idx=0
    for provider in "${providers[@]}"; do
        occ_cmd config:system:set enabledPreviewProviders "$idx" --value="$provider"
        idx=$((idx + 1))
    done

    occ_cmd config:app:set previewgenerator squareSizes --value="64 128 256 512"
    occ_cmd config:app:set previewgenerator widthSizes --value="64 128 256 512 1024 1920"
    occ_cmd config:app:set previewgenerator heightSizes --value="64 128 256 512 1024 1080"
}

install_applications() {
    log_info "Installing and enabling required applications..."

    local apps=(
        user_oidc
        previewgenerator
        memories
        calendar
        contacts
        tasks
        notes
        deck
        mail
        spreed
        files_antivirus
        fulltextsearch
        fulltextsearch_elasticsearch
        files_fulltextsearch
        integration_openai
    )

    for app in "${apps[@]}"; do
        log_info " - Ensuring app is active: $app"
        occ_cmd app:install "$app" --no-interaction 2>/dev/null || occ_cmd app:enable "$app" --no-interaction 2>/dev/null || true
    done

    occ_cmd app:disable registration --no-interaction 2>/dev/null || true
    occ_cmd app:disable twofactor_totp --no-interaction 2>/dev/null || true
    occ_cmd app:disable user_ldap --no-interaction 2>/dev/null || true
}

configure_oidc() {
    log_info "Configuring Authelia OIDC identity provider (xbhl.online)..."

    occ_cmd user_oidc:provider "xbhl.online" \
        --clientid="$OIDC_CLIENT_ID" \
        --clientsecret="$OIDC_CLIENT_SECRET" \
        --discoveryuri="$OIDC_PROVIDER_URL" \
        --scope="openid profile email groups" \
        --mapping-uid="preferred_username" \
        --mapping-email="email" \
        --mapping-display-name="name" \
        --unique-uid=0 \
        --check-bearer=1 \
        --no-interaction

    occ_cmd config:system:set user_oidc default_token_endpoint_auth_method --value="client_secret_post"
    occ_cmd config:system:set user_oidc enrich_login_id_token_with_userinfo --type=boolean --value=true
    occ_cmd config:app:set user_oidc allow_multiple_user_backends --value="0"
}

configure_antivirus() {
    log_info "Configuring ClamAV Antivirus integration..."

    occ_cmd config:app:set files_antivirus av_mode --value="daemon"
    occ_cmd config:app:set files_antivirus av_host --value="clamav"
    occ_cmd config:app:set files_antivirus av_port --value="3310"
    occ_cmd config:app:set files_antivirus av_infected_action --value="only_log"
    occ_cmd config:app:set files_antivirus av_stream_max_length --value="104857600"
}

configure_fulltextsearch() {
    log_info "Configuring Elasticsearch Full-Text Search integration..."

    occ_cmd fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_Elasticsearch\\Platform\\ElasticSearchPlatform"}' --no-interaction
    occ_cmd fulltextsearch_elasticsearch:configure '{"elastic_host":"http://elasticsearch:9200","elastic_index":"nextcloud"}' --no-interaction

    (
        sleep 20
        log_info "Triggering initial full-text search indexing in background..."
        occ_cmd fulltextsearch:index --no-interaction >/dev/null 2>&1 || true
    ) &
}

configure_talk() {
    log_info "Configuring Nextcloud Talk STUN and Coturn TURN servers (${COTURN_HOST})..."

    occ_cmd config:app:set spreed stun_servers --value='["'"$COTURN_HOST"':3478","stun.nextcloud.com:443"]'
    occ_cmd config:app:set spreed turn_servers --value='[{"server":"'"$COTURN_HOST"':3478","secret":"'"$COTURN_SECRET"'","protocols":"udp,tcp"}]'
}

configure_ai() {
    log_info "Configuring OpenWebUI AI integration..."

    occ_cmd config:app:set integration_openai api_key --value="$OPENAI_API_KEY"
    occ_cmd config:app:set integration_openai api_url --value="$OPENAI_API_BASE_URL"
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

optimize_database() {
    log_info "Running database indexing and optimizations..."

    occ_cmd db:add-missing-indices --no-interaction || true
    occ_cmd db:add-missing-primary-keys --no-interaction || true
    occ_cmd db:add-missing-columns --no-interaction || true
}

ensure_admin_privileges() {
    log_info "Ensuring admin group exists and assigning ${NEXTCLOUD_MAIN_USER}..."

    occ_cmd group:add admin --no-interaction 2>/dev/null || true
    occ_cmd group:adduser admin "$NEXTCLOUD_MAIN_USER" --no-interaction 2>/dev/null || true

    (
        local attempts=0
        while [ "$attempts" -lt 120 ]; do
            if occ_cmd user:info "$NEXTCLOUD_MAIN_USER" >/dev/null 2>&1; then
                occ_cmd group:adduser admin "$NEXTCLOUD_MAIN_USER" --no-interaction 2>/dev/null || true
                log_info "User ${NEXTCLOUD_MAIN_USER} successfully assigned to admin group."
                break
            fi
            attempts=$((attempts + 1))
            sleep 10
        done
    ) &
}

main() {
    log_info "Starting Nextcloud bootstrap configuration..."

    validate_environment
    wait_for_installation

    configure_system
    configure_caching
    configure_previews

    install_applications

    configure_oidc
    configure_antivirus
    configure_fulltextsearch
    configure_talk
    configure_ai
    configure_smtp

    optimize_database
    ensure_admin_privileges

    log_info "Nextcloud configuration completed successfully."
}

main "$@"
