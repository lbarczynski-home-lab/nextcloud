#!/bin/bash
# Media processing: Imaginary previews, Memories video/EXIF tools, and Recognize defaults.

configure_previews() {
    log_info "Configuring preview providers, Imaginary service, and dimensions..."

    occ_cmd config:system:set enable_previews --type=boolean --value=true
    occ_cmd config:system:set preview_imaginary_url --value="http://imaginary:9000"
    occ_cmd config:system:set preview_concurrency_all --type=integer --value=8
    occ_cmd config:system:set preview_concurrency_new --type=integer --value=4
    occ_cmd config:system:set preview_max_x --type=integer --value=2048
    occ_cmd config:system:set preview_max_y --type=integer --value=2048
    occ_cmd config:system:set preview_max_filesize_image --type=integer --value=50

    local providers=(
        "OC\Preview\Imaginary"
        "OC\Preview\ImaginaryPDF"
        "OC\Preview\PNG"
        "OC\Preview\JPEG"
        "OC\Preview\GIF"
        "OC\Preview\BMP"
        "OC\Preview\XBitmap"
        "OC\Preview\MP3"
        "OC\Preview\TXT"
        "OC\Preview\MarkDown"
        "OC\Preview\PDF"
        "OC\Preview\Movie"
        "OC\Preview\HEIC"
        "OC\Preview\WebP"
    )
    set_system_list enabledPreviewProviders "${providers[@]}"

    occ_cmd config:app:set previewgenerator squareSizes --value="64 128 256 512"
    occ_cmd config:app:set previewgenerator widthSizes --value="64 128 256 512 1024 1920"
    occ_cmd config:app:set previewgenerator heightSizes --value="64 128 256 512 1024 1080"
}

configure_memories() {
    log_info "Configuring Nextcloud Memories..."

    occ_cmd config:app:delete memories vod.external 2>/dev/null || true
    occ_cmd config:app:delete memories vod.ffmpeg 2>/dev/null || true
    occ_cmd config:app:delete memories vod.ffprobe 2>/dev/null || true
    occ_cmd config:app:delete memories exiftool 2>/dev/null || true

    occ_cmd config:system:set memories.vod.ffmpeg --value="/usr/bin/ffmpeg"
    occ_cmd config:system:set memories.vod.ffprobe --value="/usr/bin/ffprobe"
    occ_cmd config:system:set memories.exiftool --value="/usr/bin/exiftool"
}

configure_recognize_defaults() {
    log_info "Applying default Recognize feature toggles where not already set..."

    set_default_if_unset recognize face_recognition_enabled 1
    set_default_if_unset recognize object_recognition_enabled 1
    set_default_if_unset recognize landmark_recognition_enabled 1
    set_default_if_unset recognize music_recognition_enabled 1
    set_default_if_unset recognize video_recognition_enabled 1
}
