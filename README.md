# Nextcloud Service

Nextcloud enterprise-grade private cloud storage setup with PostgreSQL, Redis cache, automated preview generation, Cloudflare Tunnel, Authelia OIDC integration, ClamAV antivirus, Elasticsearch full-text search, Nextcloud Talk with Coturn STUN/TURN, and OpenWebUI AI integration.

## Architecture

- **Nextcloud**: Apache image with multimedia support (`ffmpeg`, `imagemagick`, `ghostscript`, and `exiftool`).
- **Database**: PostgreSQL on local VM storage.
- **Cache & Locking**: Redis.
- **Storage**: QNAP NAS NFS mount for data directory (`/var/nc-data`).
- **Access**: Cloudflare Tunnel (`nextcloud.xbhl.online`).
- **SSO**: Authelia OIDC integration (`user_oidc`).
- **Communication & Calls**: Nextcloud Talk (`spreed`) with dedicated Coturn STUN/TURN server (`nextcloud_coturn` at `talk.nextcloud.xbhl.online`).
- **Security**: ClamAV daemon antivirus scanning on upload (`files_antivirus`).
- **Search**: Elasticsearch full-text search backend (`fulltextsearch_elasticsearch`) with automated background indexing.
- **AI Assistant**: OpenWebUI integration via OpenAI-compatible API (`integration_openai`).
- **Background Tasks**: Dedicated `nextcloud_cron` container (every 5 min) and `nextcloud_maintenance_worker` (previews every 15 min + search sync hourly).

## Coturn Network Ports & DNS

Coturn requires direct (unproxied / non-Cloudflare Tunnel) routing to handle WebRTC UDP/TCP traffic:
- **DNS Record**: `talk.nextcloud.xbhl.online` (A record pointing to Public Router IP, `proxied: false`, managed automatically by CI pipeline).
- **Ports to Forward on Router to VM**:
  - `3478` (TCP / UDP) - STUN/TURN service port
  - `49152-49172` (UDP) - Relay media port range

## CI/CD Environment Variables Required

### Project-Level Variables (in Nextcloud Repo)
- `CLOUDFLARE_TUNNEL_UUID`
- `CLOUDFLARE_TUNNEL_TOKEN`
- `NEXTCLOUD_ADMIN_USER` (default: `admin`)
- `NEXTCLOUD_ADMIN_PASSWORD`
- `NEXTCLOUD_MAIN_USER` (default: `lbarczynski`)
- `NEXTCLOUD_DB_PASSWORD`
- `NEXTCLOUD_REDIS_PASSWORD`
- `NEXTCLOUD_OAUTH_CLIENT_SECRET`
- `NEXTCLOUD_COTURN_SECRET`
- `OPEN_WEBUI_API_KEY`

### Inherited Global Variables (from GitLab Home Lab Group)
- `SSH_USER`
- `SSH_PRIVATE_KEY`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_DNS_API_TOKEN`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_FROM`
