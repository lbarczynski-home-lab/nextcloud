#!/bin/bash
# Application catalog reconciliation (desired vs unwanted apps).

reconcile_applications() {
    log_info "Reconciling installed applications against desired state..."

    local desired_apps=(
        # Authentication & Security
        admin_audit
        bruteforcesettings
        files_antivirus
        suspicious_login
        user_oidc

        # AI & Smart Features
        assistant
        integration_openai
        recognize

        # Search & Indexing (Full-Text Search)
        files_fulltextsearch
        files_fulltextsearch_metadata
        fulltextsearch
        fulltextsearch_elasticsearch

        # File Management & Storage
        files_automatedtagging
        files_retention
        groupfolders
        previewgenerator
        quota_warning

        # Collaboration & Office
        bookmarks
        calendar
        contacts
        deck
        drawio
        forms
        mail
        notes
        richdocuments
        spreed
        tasks

        # Media & Viewers
        epubviewer
        memories
        duplicatefinder

        # UI & Navigation Integrations
        integration_giphy
        maps
        news
        notify_push
        side_menu
    )

    # Two-factor auth is handled upstream by Authelia (LDAP-backed MFA) — no
    # 2FA method may be selectable from within Nextcloud itself.
    local unwanted_apps=(
        cospend
        dicomviewer
        encryption
        external
        registration
        user_ldap
        twofactor_totp
        twofactor_nextcloud_notification
        twofactor_backupcodes
    )

    log_info "Configuring app version compatibility overwrite whitelist..."
    set_system_list app_install_overwrite files_fulltextsearch_metadata

    local app_list_json
    app_list_json=$(occ_cmd app:list --output=json 2>/dev/null || echo "{}")
    local enabled_ids
    enabled_ids=$(printf '%s' "$app_list_json" | jq -r '(.enabled // {} | keys) | .[]')
    local disabled_ids
    disabled_ids=$(printf '%s' "$app_list_json" | jq -r '(.disabled // {} | keys) | .[]')
    local present_ids
    present_ids=$(printf "%s\n%s\n" "$enabled_ids" "$disabled_ids")

    local failed_installs=()
    local app
    for app in "${desired_apps[@]}"; do
        if ! list_contains "$app" "$present_ids"; then
            log_info " - Installing missing app: $app"
            occ_cmd app:install "$app" --no-interaction || failed_installs+=("$app")
        elif list_contains "$app" "$disabled_ids"; then
            log_info " - Enabling previously disabled app: $app"
            occ_cmd app:enable "$app" --no-interaction || failed_installs+=("$app")
        fi
    done

    for app in "${unwanted_apps[@]}"; do
        if list_contains "$app" "$present_ids"; then
            log_info " - Removing unwanted app: $app"
            occ_cmd app:disable "$app" --no-interaction 2>/dev/null || true
            # app:remove fails harmlessly for shipped/core apps, which can only be disabled.
            occ_cmd app:remove "$app" --no-interaction 2>/dev/null || true
        fi
    done

    if [ "${#failed_installs[@]}" -gt 0 ]; then
        log_error "Failed to install or enable app(s): ${failed_installs[*]}"
        return 1
    fi
}
