#!/bin/bash
# Factorio Railway entrypoint
#
# The upstream image (factoriotools/factorio:2.0.77) ships its own
# entrypoint at /docker-entrypoint.sh which:
#   - mkdir's /factorio, /factorio/saves, /factorio/config, /factorio/mods
#   - copies default server-settings.json, map-gen-settings.json,
#     map-settings.json on first boot
#   - generates a random RCON password if /factorio/config/rconpw is missing
#   - drops from root to the `factorio` user via gosu before exec
#
# What we add:
#   1. A "we made it past the chown" log line so the Railway deploy log
#      shows the server is initializing correctly.
#   2. Echo the effective UID so a misconfigured volume mount (where the
#      upstream chown fails) shows up immediately in logs.
#   3. Start a tiny HTTP health server (railway-health.sh) on Railway's
#      injected PORT so the HTTP-only healthcheck returns 200. This
#      runs in the background and serves plain "ok" responses.
#   4. Then exec the upstream entrypoint.
set -eu

echo "[factorio-railway] starting"
echo "[factorio-railway] image: factoriotools/factorio:2.0.77"
echo "[factorio-railway] uid=$(id -u) gid=$(id -g) factorio_uid=845"

# Start the HTTP health server on 8080 in the background. It just
# returns 200 OK so the healthcheck is happy. Listens on 8080 (not
# on Railway's injected PORT, which we override to 34197 so Factorio
# binds to the standard game port). Uses socat (added in Dockerfile).
nohup /usr/local/bin/railway-health.sh >/tmp/railway-health.log 2>&1 &
HEALTH_PID=$!
echo "[factorio-railway] health server pid=${HEALTH_PID} port=8080 (railway-port=${PORT})"

# Clean up the health server if the upstream entrypoint exits (best effort)
trap 'kill ${HEALTH_PID} 2>/dev/null || true' EXIT

# The upstream entrypoint is at /docker-entrypoint.sh (not
# /factorio/...). The upstream Dockerfile does `COPY files/*.sh /`
# so it lands at the root of the image.
exec /docker-entrypoint.sh "$@"
