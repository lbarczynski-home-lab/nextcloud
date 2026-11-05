#!/bin/bash
# AI integrations: OpenAI/LiteLLM provider, AppAPI HaRP daemon, Context Chat, and Context Agent.

configure_ai() {
    log_info "Configuring AI Assistant integration (URL: ${AI_API_BASE_URL}, model: ${AI_DEFAULT_MODEL})..."

    occ_cmd config:app:set integration_openai url --value="$AI_API_BASE_URL"
    occ_cmd config:app:set integration_openai api_key --value="$AI_API_KEY"
    occ_cmd config:app:set integration_openai service_name --value="OpenWebUI@XBHL.online"
    occ_cmd config:app:set integration_openai default_completion_model_id --value="$AI_DEFAULT_MODEL"
    occ_cmd config:app:set integration_openai llm_provider_enabled --value="1"
    occ_cmd config:app:set integration_openai chat_endpoint_enabled --value="1"
    occ_cmd config:app:set integration_openai translation_provider_enabled --value="1"
    occ_cmd config:app:set integration_openai free_prompts --value="1"
    occ_cmd config:app:set integration_openai max_tokens --value="8192"
    occ_cmd config:app:set integration_openai context_size --value="32768"
}

# Order matters: AppAPI -> backend -> frontend. Backend/frontend
# versions must match major.minor.
configure_context_chat_stack() {
    log_info "Configuring Context Chat (AppAPI, HaRP, backend, frontend)..."

    occ_cmd app:install app_api --no-interaction 2>/dev/null || true
    occ_cmd app:enable app_api --no-interaction 2>/dev/null || true

    if ! occ_cmd app_api:daemon:list 2>/dev/null | grep -q "harp_docker"; then
        log_info " - Registering HaRP deploy daemon..."
        if ! occ_cmd app_api:daemon:register harp_docker "AppAPI HaRP" "docker-install" "http" \
            "appapi-harp:8780" "https://${OVERWRITEHOST}" \
            --net nextcloud_internal_network --harp \
            --harp_frp_address "appapi-harp:8782" \
            --harp_shared_key "$HP_SHARED_KEY" \
            --set-default --no-interaction; then
            log_error "Failed to register the HaRP deploy daemon"
            return 1
        fi
    fi

    if ! occ_cmd app_api:app:list 2>/dev/null | grep -q "context_chat_backend"; then
        log_info " - Registering context_chat_backend (v5.5.0, matching context_chat)..."
        if ! occ_cmd app_api:app:register context_chat_backend harp_docker \
            --info-xml "https://raw.githubusercontent.com/nextcloud/context_chat_backend/v5.5.0/appinfo/info.xml" \
            --env "CC_EM_BASE_URL=${AI_API_BASE_URL}" \
            --env "CC_EM_MODEL_NAME=models/gemini-embedding-001" \
            --env "CC_EM_APIKEY=${AI_API_KEY}" \
            --wait-finish --no-interaction; then
            log_error "Failed to register context_chat_backend"
            return 1
        fi
    fi

    if ! is_app_present context_chat; then
        log_info " - Installing context_chat..."
        if ! occ_cmd app:install context_chat --no-interaction; then
            log_error "Failed to install context_chat"
            return 1
        fi
    fi

    occ_cmd config:app:set context_chat auto_indexing --value='true' --type=string 2>/dev/null || true
}

configure_context_agent() {
    log_info "Configuring Context Agent (Assistant chat tools)..."

    if ! occ_cmd app_api:app:list 2>/dev/null | grep -q "context_agent"; then
        log_info " - Registering context_agent from the appstore..."
        if ! occ_cmd app_api:app:register context_agent harp_docker --wait-finish --no-interaction; then
            log_error "Failed to register context_agent"
            return 1
        fi
    fi
}
