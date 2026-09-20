#!/bin/bash
# Tier 1 — one-time bootstrap.
#
# Runs exactly once per BOOTSTRAP_VERSION (guarded by a marker stored in the
# Nextcloud system config). Anything here either can't be re-run safely
# (app installation churn, admin group assignment) or sets a *default* that
# the admin is expected to tune afterwards from the web UI without this
# script fighting them on every container restart (e.g. Recognize feature
# toggles). Bump BOOTSTRAP_VERSION to deliberately force a re-run after
# changing this file.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-common.sh"

readonly BOOTSTRAP_VERSION=1
readonly BOOTSTRAP_MARKER_KEY="homelab_bootstrap_version"

is_bootstrap_done() {
    local current
    current=$(occ_cmd config:system:get "$BOOTSTRAP_MARKER_KEY" 2>/dev/null || echo "0")
    [ "$current" = "$BOOTSTRAP_VERSION" ]
}

install_applications() {
    log_info "Installing and enabling required applications..."

    local apps=(
        # Authentication & Security
        admin_audit
        bruteforcesettings
        files_antivirus
        suspicious_login
        user_oidc

        # AI & Smart Features
        assistant
        context_chat
        integration_openai
        llm2
        recognize

        # Search & Indexing (Full-Text Search)
        files_fulltextsearch
        files_fulltextsearch_metadata
        files_fulltextsearch_tika
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
        cameraraw
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

    log_info "Configuring app version compatibility overwrite whitelist (temporary, pending NC35 app compat)..."
    local overwrite_apps=(
        previewgenerator
        context_chat
        drawio
        files_fulltextsearch_metadata
        news
        quota_warning
        duplicatefinder
    )
    local o_idx=0
    for app in "${overwrite_apps[@]}"; do
        occ_cmd config:system:set app_install_overwrite "$o_idx" --value="$app"
        o_idx=$((o_idx + 1))
    done

    for app in "${apps[@]}"; do
        log_info " - Ensuring app is active: $app"
        occ_cmd app:install "$app" --no-interaction 2>/dev/null || occ_cmd app:enable "$app" --no-interaction 2>/dev/null || true
    done
}

disable_unwanted_apps() {
    log_info "Disabling and removing unwanted applications..."

    local disabled_apps=(
        app_api
        cospend
        dicomviewer
        encryption
        external
        registration
        user_ldap

        # Two-factor auth is handled upstream by Authelia (LDAP-backed) — it
        # must not be selectable or enforceable from within Nextcloud itself.
        twofactor_totp
        twofactor_nextcloud_notification
        twofactor_backupcodes
    )

    for app in "${disabled_apps[@]}"; do
        occ_cmd app:disable "$app" --no-interaction 2>/dev/null || true
        occ_cmd app:remove "$app" --no-interaction 2>/dev/null || true
    done
}

configure_recognize_defaults() {
    log_info "Setting initial Recognize feature defaults (admin may retune these later in Settings)..."

    occ_cmd config:app:set recognize face_recognition_enabled --value="1"
    occ_cmd config:app:set recognize object_recognition_enabled --value="1"
    occ_cmd config:app:set recognize landmark_recognition_enabled --value="1"
    occ_cmd config:app:set recognize music_recognition_enabled --value="1"
    occ_cmd config:app:set recognize video_recognition_enabled --value="1"
}

main() {
    if is_bootstrap_done; then
        log_info "Bootstrap v${BOOTSTRAP_VERSION} already completed — skipping one-time setup."
        return 0
    fi

    log_info "Running one-time bootstrap (v${BOOTSTRAP_VERSION})..."

    install_applications
    disable_unwanted_apps
    configure_recognize_defaults

    occ_cmd config:system:set "$BOOTSTRAP_MARKER_KEY" --value="$BOOTSTRAP_VERSION"
    log_info "Bootstrap completed and marked as version ${BOOTSTRAP_VERSION}."
}

main "$@"
