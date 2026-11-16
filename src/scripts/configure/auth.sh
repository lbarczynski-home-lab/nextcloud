#!/bin/bash
# Authelia OIDC provider and initial admin group assignment.

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
        --no-interaction || return 1

    occ_cmd config:system:set user_oidc default_token_endpoint_auth_method --value="client_secret_post"
    occ_cmd config:system:set user_oidc enrich_login_id_token_with_userinfo --type=boolean --value=true
    occ_cmd config:app:set user_oidc allow_multiple_user_backends --value="0"
    occ_cmd config:app:set user_oidc sync_user_details --value="1"
}

ensure_admin_privileges() {
    log_info "Ensuring admin group exists and assigning ${NEXTCLOUD_MAIN_USER}..."

    occ_cmd group:add admin --no-interaction 2>/dev/null || true
    if occ_cmd user:info "$NEXTCLOUD_MAIN_USER" >/dev/null 2>&1; then
        occ_cmd group:adduser admin "$NEXTCLOUD_MAIN_USER" --no-interaction 2>/dev/null || true
        log_info "User ${NEXTCLOUD_MAIN_USER} is present and assigned to admin group."
        return 0
    fi

    # OIDC users are provisioned on first login; poll in the background on fresh installs.
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
    ) </dev/null >/proc/1/fd/1 2>/proc/1/fd/2 9>&- &
}
