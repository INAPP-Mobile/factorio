# Factorio Headless Server on Railway
# https://github.com/factoriotools/factorio-docker
# Wraps the official pinned image so we can:
#   1. Pin the exact Factorio version (no :latest drift)
#   2. Run as root so the Railway-managed volume at /factorio is writable
#      (the upstream image's `factorio` user has no permission to chown
#      a root-owned fresh Railway volume; doing the chown as root first
#      then dropping to the factorio user is the proven pattern)
#   3. Layer in a Railway-aware entrypoint that verifies the volume
#      before exec'ing the upstream binary
#   4. Add a tiny HTTP health server on Railway's injected PORT so
#      Railway's HTTP-only healthcheck sees a 200 (the UDP game port
#      can't satisfy an HTTP probe).
FROM factoriotools/factorio:2.0.77

USER root

# socat is a tiny static-ish binary (~700 KB) that we use as a one-liner
# HTTP responder for Railway's healthcheck. Without this, every deploy
# fails the healthcheck and is marked FAILED (the game server itself
# runs fine, but Railway tears down the container).
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends socat \
    && rm -rf /var/lib/apt/lists/*

# Bake in our entrypoint. The image's stock entrypoint lives at
# /factorio/docker-entrypoint.sh; we wrap it so we can guarantee
# /factorio/saves is owned by the factorio user (UID 1000) before
# the game tries to write the autosave there.
COPY entrypoint.sh /usr/local/bin/railway-entrypoint.sh
COPY health.sh /usr/local/bin/railway-health.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh /usr/local/bin/railway-health.sh

# Factorio's default ports:
#   34197/udp — game traffic (players connect here)
#   27015/tcp — RCON (admin console)
# 8080/tcp   — Railway HTTP healthcheck (responded to by railway-health.sh)
EXPOSE 34197/udp
EXPOSE 27015/tcp
EXPOSE 8080/tcp

# Docker-level healthcheck probes the RCON port. The Railway-level
# healthcheck (configured separately) hits the HTTP 8080 endpoint
# served by railway-health.sh.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
  CMD bash -c 'cat < /dev/tcp/127.0.0.1/27015' >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
