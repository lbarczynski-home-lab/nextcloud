FROM busybox:musl AS helper

FROM collabora/code:26.04.4.2.1
COPY --from=helper /bin/wget /usr/bin/wget
