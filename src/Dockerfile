FROM nextcloud:34.0.3-apache

# Install required system tools and libraries for multimedia processing and background workers:
# - ffmpeg: Video preview generation and video transcoding (used by Memories app)
# - ghostscript: PDF document preview generation
# - libmagickcore-*-extra & imagemagick: Extended image format preview support (HEIC, SVG, TIFF, etc.)
# - libimage-exiftool-perl (exiftool): Extracting metadata from photos and media (used by Memories app)
# - procps: Process monitoring tools (ps) required by Nextcloud background checks
# - curl & jq: Utilities for healthcheck and automated bootstrap scripts
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    ghostscript \
    libmagickcore-*-extra \
    imagemagick \
    libimage-exiftool-perl \
    procps \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

COPY config/custom.ini /usr/local/etc/php/conf.d/custom.ini
COPY hooks/setup-datadir.sh /docker-entrypoint-hooks.d/pre-installation/setup-datadir.sh
RUN chmod +x /docker-entrypoint-hooks.d/pre-installation/setup-datadir.sh

COPY scripts/entrypoint-wrapper.sh /entrypoint-wrapper.sh
RUN chmod +x /entrypoint-wrapper.sh

ENTRYPOINT ["/entrypoint-wrapper.sh"]
CMD ["apache2-foreground"]
