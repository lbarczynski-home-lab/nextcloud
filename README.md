# Nextcloud & Collabora Office Suite

Self-hosted enterprise private cloud storage and collaborative office suite powered by Docker Compose.

---

## Features & Included Services

- **Nextcloud Hub**: Official Apache-based Nextcloud extended with multimedia processing tools (`ffmpeg`, `imagemagick`, `exiftool`).
- **Database & Cache**: PostgreSQL with performance tuning and Redis for distributed memory caching and transactional file locking.
- **Collaborative Office**: Collabora Online (CODE) for real-time document, spreadsheet, and presentation editing.
- **Full-Text Search (FTS)**: Elasticsearch cluster paired with Apache Tika for deep content indexing (PDF, Office documents, text).
- **Communication**: Nextcloud Talk with Coturn STUN/TURN integration for WebRTC audio/video calls.
- **AI Integrations**: Nextcloud Assistant (LLM integration) and Recognize for local machine learning photo classification and facial recognition.
- **Security & Antivirus**: ClamAV daemon for automated signature updates and streaming file scan on upload.
- **High Performance Push**: `notify_push` backend for instant desktop and mobile WebSocket sync.
- **Single Sign-On (SSO)**: OpenID Connect (OIDC) integration.
- **Dedicated Background Workers**:
  - `cron`: System cron runner for background tasks.
  - `ai_worker`: Dedicated task processor for near-instant AI assistant responses.
  - `maintenance_worker`: Automated scheduled preview generation, search indexing, and database optimization.

---

## Directory Structure

```text
├── src/
│   ├── nextcloud/          # Nextcloud compose, Dockerfile, envs, and scripts
│   └── collabora/          # Collabora Online document server
├── scripts/                # Helper automation scripts
└── .gitlab-ci.yml          # Automated CI/CD deployment pipeline
```

---

## On-Demand Maintenance

To manually run a complete maintenance and indexing cycle:

```bash
docker exec -it nextcloud /scripts/maintenance-worker.sh --now
```

---

## Required CI/CD Variables

### Project Variables
- `NEXTCLOUD_CLOUDFLARE_TUNNEL_UUID` / `NEXTCLOUD_CLOUDFLARE_TUNNEL_TOKEN`
- `OFFICE_CLOUDFLARE_TUNNEL_UUID` / `OFFICE_CLOUDFLARE_TUNNEL_TOKEN`
- `NEXTCLOUD_ADMIN_PASSWORD`
- `NEXTCLOUD_MAIN_USER`
- `NEXTCLOUD_DB_PASSWORD`
- `NEXTCLOUD_REDIS_PASSWORD`
- `NEXTCLOUD_OAUTH_CLIENT_SECRET`
- `NEXTCLOUD_COTURN_SECRET`
- `OPEN_WEBUI_API_KEY`

### Global Variables
- `SSH_USER` / `SSH_PRIVATE_KEY`
- `CLOUDFLARE_ZONE_ID` / `CLOUDFLARE_DNS_API_TOKEN`
- `SMTP_HOST` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `SMTP_FROM`

