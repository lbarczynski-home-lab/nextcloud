#!/bin/bash
# External service integrations: Collabora Office, ClamAV, Elasticsearch, and Talk/Coturn.

configure_office() {
    log_info "Configuring Nextcloud Office (Collabora Online at https://office.xbhl.online)..."

    occ_cmd app:enable richdocuments --no-interaction 2>/dev/null || true
    occ_cmd config:app:set richdocuments wopi_url --value="https://office.xbhl.online"
    occ_cmd config:app:set richdocuments public_wopi_url --value="https://office.xbhl.online"
    occ_cmd config:app:set richdocuments doc_format --value="ooxml"
    occ_cmd richdocuments:activate-config --no-interaction 2>/dev/null || true
}

configure_antivirus() {
    log_info "Configuring ClamAV Antivirus integration..."

    occ_cmd config:app:set files_antivirus av_mode --value="daemon"
    occ_cmd config:app:set files_antivirus av_host --value="clamav"
    occ_cmd config:app:set files_antivirus av_port --value="3310"
    occ_cmd config:app:set files_antivirus av_infected_action --value="delete"
    # Must stay at or below clamd's StreamMaxLength (100M default in clamav image).
    occ_cmd config:app:set files_antivirus av_stream_max_length --value="100000000"
}

configure_fulltextsearch_backend() {
    log_info "Configuring Elasticsearch Full-Text Search backend wiring..."

    occ_cmd fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_Elasticsearch\\Platform\\ElasticSearchPlatform"}' --no-interaction
    occ_cmd fulltextsearch_elasticsearch:configure '{"elastic_host":"http://elasticsearch:9200","elastic_index":"nextcloud"}' --no-interaction
    occ_cmd files_fulltextsearch:configure '{"files_local":"1","files_pdf":"1","files_office":"1","files_metadata":"1","files_metadata_max_size":"100"}' --no-interaction 2>/dev/null || true
    occ_cmd config:app:set files_fulltextsearch_metadata metadata_indexed --value="1"
    occ_cmd config:app:set files_fulltextsearch_metadata files_metadata_max_size --value="100"
}

configure_talk() {
    local coturn_port="${COTURN_PORT:-3478}"
    log_info "Configuring Nextcloud Talk STUN and Coturn TURN servers (${COTURN_HOST}:${coturn_port})..."

    occ_cmd config:app:set spreed stun_servers --value='["'"$COTURN_HOST"':'"$coturn_port"'","stun.nextcloud.com:443"]'
    occ_cmd config:app:set spreed turn_servers --value='[{"server":"'"$COTURN_HOST"':'"$coturn_port"'","secret":"'"$COTURN_SECRET"'","protocols":"udp,tcp"}]'

    if [ -n "${GIPHY_API_KEY:-}" ] && [ "$GIPHY_API_KEY" != "PLACEHOLDER" ]; then
        log_info "Configuring Giphy API Key for Talk integration..."
        occ_cmd config:app:set integration_giphy api_key --value="$GIPHY_API_KEY"
        occ_cmd config:app:set integration_giphy rating_filter --value="r"
    fi
}
