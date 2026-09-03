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
FROM factoriotools/factorio:2.0.77

USER root

# Bake in our entrypoint. The image's stock entrypoint lives at
# /factorio/docker-entrypoint.sh; we wrap it so we can guarantee
# /factorio/saves is owned by the factorio user (UID 1000) before
# the game tries to write the autosave there.
COPY entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# Factorio's default ports:
#   34197/udp — game traffic (players connect here)
#   27015/tcp — RCON (admin console)
EXPOSE 34197/udp
EXPOSE 27015/tcp

# Healthcheck uses the RCON port. A TCP-connect check is enough to
# confirm the server is up; a full RCON auth roundtrip would need
# the password baked in, which we deliberately don't do.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
  CMD bash -c 'cat < /dev/tcp/127.0.0.1/27015' >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
