# Nextcloud & Collabora Office Suite

Enterprise-grade private cloud storage and collaborative office suite with PostgreSQL, Redis caching, automated thumbnail/preview generation, Cloudflare Tunnels, Authelia OIDC single sign-on, ClamAV antivirus, Elasticsearch + Apache Tika full-text search, Nextcloud Talk with Coturn STUN/TURN, OpenWebUI AI integration, local machine learning photo recognition, and Collabora Online document editing.

---

## Architecture Overview

### Nextcloud Ecosystem (`src/nextcloud`)
- **Nextcloud**: Official Apache image extended with multimedia libraries (`ffmpeg`, `imagemagick`, `ghostscript`, and `exiftool`) and strict security headers (`HSTS max-age=15552000`).
- **Database**: PostgreSQL 18.6 tuned with 512MB shared buffers and connection caching.
- **Cache & Locking**: Redis for distributed memory caching and transactional file locking.
- **Primary Storage**: QNAP NAS NFS mount for data directory (`/var/nc-data`).
- **Access & Ingress**: Dedicated Cloudflare Tunnel (`nextcloud.xbhl.online`).
- **Authentication (SSO)**: Authelia OpenID Connect integration (`user_oidc`) with alternative logins disabled and enforced 2FA.
- **Instant Client Sync (`notify_push`)**: High Performance Backend binary proxying real-time WebSockets to desktop and mobile clients.
- **Communication & Calls**: Nextcloud Talk (`spreed`) backed by an integrated Coturn STUN/TURN server (`talk.nextcloud.xbhl.online`).
- **Antivirus Security**: ClamAV daemon (`files_antivirus`) with automated signature updates and streaming file scan on upload.
- **Full-Text Search (FTS)**: Elasticsearch cluster (`fulltextsearch_elasticsearch`) coupled with an Apache Tika document text extraction service (`files_fulltextsearch_tika`).
- **AI Assistant**: Nextcloud Assistant integrated with OpenWebUI (`integration_openai`) using `models/gemini-3.5-flash-lite`.
- **Photo AI (`recognize`)**: Local machine learning engine for face detection, facial clustering into people, and object/landmark detection for Memories and Nextcloud Photos.
- **Office & Diagramming Suite**:
  - **Collabora Online (`richdocuments`)**: Real-time collaborative document, spreadsheet, and presentation editing.
  - **Draw.io (`drawio`)**: Vector diagrams, flowcharts, and whiteboarding directly inside Nextcloud.
  - **Viewers**: EPUB reader (`epubviewer`) and DICOM medical imaging viewer (`dicomviewer`).
- **Retention Policy**: Strict 365-day retention obligation configured for deleted files (`trashbin_retention_obligation`) and file versions (`versions_retention_obligation`).
- **Background Workers**:
  - `nextcloud_cron`: Standard Nextcloud system cron runner (executes `/cron.sh` every 5 minutes).
  - `nextcloud_maintenance_worker`: Dedicated maintenance daemon for preview pre-generation (every 15 min), FTS sync (hourly), and daily database optimization/repair.

### Collabora Online Suite (`src/collabora`)
- **Collabora CODE**: Containerized LibreOffice-based document server (`office.xbhl.online`).
- **Isolation & Jails**: `SYS_ADMIN` and `MKNOD` capabilities enabled for fast Linux `bind-mount` chroot document sandboxes.
- **Ingress**: Dedicated Cloudflare Tunnel (`office.xbhl.online`).

---

## On-Demand Maintenance CLI

You can trigger a complete maintenance, indexing, and model update cycle on demand from the host VM:

```bash
docker exec -it nextcloud /scripts/maintenance-worker.sh --now
```

### Actions executed during on-demand maintenance:
1. **System Cron (`cron.php`)**: Processes pending background jobs and notifications.
2. **Preview Generation (`preview:pre-generate`)**: Pre-renders image and video thumbnails.
3. **Memories Indexing (`memories:index`)**: Extracts EXIF dates and geolocation tags.
4. **Recognize AI (`recognize`)**: Checks/downloads ML models, runs face/object classification, and clusters faces.
5. **Full-Text Search (`fulltextsearch:index`)**: Indexes new files into Elasticsearch via Apache Tika.
6. **Database Cleanup & Repair (`files:cleanup`, `db:optimize`, `maintenance:repair`)**: Optimizes database tables and clears stale locks.

---

## Coturn Network Ports & DNS

Nextcloud Talk Coturn requires direct (unproxied / non-Cloudflare Tunnel) routing for WebRTC UDP/TCP media traffic:
- **DNS Record**: `talk.nextcloud.xbhl.online` (A record pointing to Public Router IP, `proxied: false`, managed automatically by CI pipeline).
- **Router Port Forwarding to VM**:
  - `3478` (TCP / UDP) - STUN/TURN signaling port
  - `49152-49172` (UDP) - Media relay port range

---

## CI/CD Environment Variables

### Project-Level Variables (GitLab Nextcloud Repository)
- `NEXTCLOUD_CLOUDFLARE_TUNNEL_UUID`
- `NEXTCLOUD_CLOUDFLARE_TUNNEL_TOKEN`
- `OFFICE_CLOUDFLARE_TUNNEL_UUID`
- `OFFICE_CLOUDFLARE_TUNNEL_TOKEN`
- `NEXTCLOUD_ADMIN_PASSWORD`
- `NEXTCLOUD_MAIN_USER` (default: `lbarczynski`)
- `NEXTCLOUD_DB_PASSWORD`
- `NEXTCLOUD_REDIS_PASSWORD`
- `NEXTCLOUD_OAUTH_CLIENT_SECRET`
- `NEXTCLOUD_COTURN_SECRET`
- `OPEN_WEBUI_API_KEY`

### Inherited Global Variables (GitLab Home Lab Group)
- `SSH_USER`
- `SSH_PRIVATE_KEY`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_DNS_API_TOKEN`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_FROM`
