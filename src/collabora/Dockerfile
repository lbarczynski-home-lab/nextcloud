FROM busybox:1.37.0-musl AS helper

FROM collabora/code:26.04.5.2.1
COPY --from=helper /bin/wget /usr/bin/wget
