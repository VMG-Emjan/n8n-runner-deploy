FROM alpine:3.22 AS ffmpeg-src
RUN apk add --no-cache ffmpeg \
    && mkdir -p /collect/bin /collect/lib \
    && cp /usr/bin/ffmpeg /usr/bin/ffprobe /collect/bin/ \
    && find /usr/lib /lib -name '*.so*' -exec cp -L {} /collect/lib/ \; 2>/dev/null

# Docker Hub mirror of the same n8n image. docker.n8n.io hard-rate-limits CI runner IPs (HTTP 429).
FROM docker.io/n8nio/n8n:latest
COPY --from=ffmpeg-src /collect/bin/ /usr/local/bin/
COPY --from=ffmpeg-src /collect/lib/ /usr/local/lib/
ENV LD_LIBRARY_PATH=/usr/local/lib
USER root
RUN mkdir -p /data/animal-rescue && chown -R node:node /data
USER node
