#!/bin/bash
# Safe to rerun on every container start: everything here either
# reconciles against current state (reconcile_applications) or only
# sets a value if it's still unset (set_default_if_unset), so an
# admin's own changes from the web UI survive a restart.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logger.sh"
source "$SCRIPT_DIR/common/lock.sh"
source "$SCRIPT_DIR/common/occ.sh"
source "$SCRIPT_DIR/common/config.sh"
source "$SCRIPT_DIR/common/security.sh"

source "$SCRIPT_DIR/configure/apps.sh"
source "$SCRIPT_DIR/configure/system.sh"
source "$SCRIPT_DIR/configure/auth.sh"
source "$SCRIPT_DIR/configure/media.sh"
source "$SCRIPT_DIR/configure/integrations.sh"
source "$SCRIPT_DIR/configure/ai.sh"

validate_environment() {
    log_info "Validating required environment variables..."

    local required_vars=(
        OVERWRITEHOST
        TRUSTED_PROXIES
        NC_default_phone_region
        NC_default_language
        NC_default_locale
        NEXTCLOUD_MAIN_USER
        REDIS_HOST
        REDIS_HOST_PORT
        REDIS_HOST_PASSWORD
        OIDC_CLIENT_ID
        OIDC_CLIENT_SECRET
        OIDC_PROVIDER_URL
        AI_API_KEY
        AI_API_BASE_URL
        AI_DEFAULT_MODEL
        SMTP_HOST
        SMTP_PORT
        SMTP_USERNAME
        SMTP_PASSWORD
        SMTP_FROM
        COTURN_SECRET
        COTURN_HOST
        HP_SHARED_KEY
        NEXTCLOUD_TRASHBIN_RETENTION_OBLIGATION
        NEXTCLOUD_VERSIONS_RETENTION_OBLIGATION
    )

    local missing_vars=()
    local var
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

main() {
    log_info "Reconciling Nextcloud runtime configuration..."

    validate_environment
    acquire_lock 1

    local had_failures=0

    reconcile_applications || had_failures=1
    configure_system
    configure_caching
    configure_previews
    configure_office
    configure_memories
    configure_recognize_defaults
    configure_oidc || { log_error "OIDC provider configuration failed — will retry on next restart."; had_failures=1; }
    configure_context_chat_stack || { log_error "Context Chat stack configuration failed — will retry on next restart."; had_failures=1; }
    configure_context_agent || { log_error "Context Agent configuration failed — will retry on next restart."; had_failures=1; }
    configure_antivirus
    configure_fulltextsearch_backend
    configure_talk
    configure_ai
    configure_smtp
    configure_client_push
    configure_security_baseline
    ensure_admin_privileges

    release_lock

    if [ "$had_failures" -ne 0 ]; then
        log_error "Nextcloud runtime configuration reconciled with failures — see errors above."
        exit 1
    fi

    log_info "Nextcloud runtime configuration reconciled."
}

main "$@"
