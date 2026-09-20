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
- **Context Chat**: Chat with the content of your own files (e.g. "find invoices over 1000 PLN paid in cash"), via AppAPI + HaRP running the `context_chat_backend` ExApp, using the same external OpenAI-compatible endpoint as the Assistant for both completions and embeddings — no local embedding model or GPU required.
- **Security & Antivirus**: ClamAV daemon for automated signature updates and streaming file scan on upload.
- **High Performance Push**: `notify_push` backend for instant desktop and mobile WebSocket sync.
- **High-Performance Image Previews**: Dedicated Imaginary microservice powered by `libvips` for accelerated on-demand photo and thumbnail generation in Nextcloud Memories.
- **Single Sign-On (SSO)**: OpenID Connect (OIDC) integration.
- **Dedicated Background Workers**:
  - `cron`: System cron runner for background tasks.
  - `ai_worker`: Dedicated task processor for near-instant AI assistant responses.
  - `maintenance_worker`: Automated scheduled preview generation, search indexing, application autoupdates, and database optimization.

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

The maintenance worker uses a lock file (shared across the `nextcloud`,
`nextcloud_maintenance_worker`, and `nextcloud_ai_worker` containers via the
bind-mounted `scripts/` directory) to avoid two maintenance runs stepping on
each other. If a run is already in progress, `--now` skips instead of
running concurrently. To wait for it to finish instead of skipping
immediately (up to 5 minutes, then gives up):

```bash
docker exec -it nextcloud /scripts/maintenance-worker.sh --now --force
```

`--force` cannot forcibly kill the other run — it's in a different
container's process namespace, so a PID from the shared lock file isn't
something this container can signal. If you need to kill a genuinely stuck
run, do it in its own container, e.g.
`docker exec nextcloud_maintenance_worker kill <pid>` (see the log line
`acquire_lock` prints for the PID).

---

## Required CI/CD Variables

### Project Variables
- `NEXTCLOUD_CLOUDFLARE_TUNNEL_UUID` / `NEXTCLOUD_CLOUDFLARE_TUNNEL_TOKEN`
- `OFFICE_CLOUDFLARE_TUNNEL_UUID` / `OFFICE_CLOUDFLARE_TUNNEL_TOKEN`
- `NEXTCLOUD_ADMIN_PASSWORD`
- `NEXTCLOUD_DB_PASSWORD`
- `NEXTCLOUD_REDIS_PASSWORD`
- `NEXTCLOUD_OAUTH_CLIENT_SECRET`
- `NEXTCLOUD_COTURN_SECRET`
- `NEXTCLOUD_APPAPI_HARP_SHARED_KEY`
- `OPEN_WEBUI_API_KEY`
- `GIPHY_API_KEY`

### Global Variables
- `SSH_USER` / `SSH_PRIVATE_KEY`
- `CLOUDFLARE_ZONE_ID` / `CLOUDFLARE_DNS_API_TOKEN`
- `SMTP_HOST` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `SMTP_FROM`

