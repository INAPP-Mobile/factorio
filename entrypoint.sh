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

# Start the HTTP health server in the background. It listens on
# TCP 8080 (the default Railway-injected PORT) and serves a 200 OK
# for every connection so Railway's HTTP-only healthcheck passes.
# The Factorio server itself binds UDP 8080 (driven by $PORT passed
# through to the upstream entrypoint) — UDP and TCP can share a port
# number on the same address, so the game and the healthcheck
# listener coexist on 8080.
# We do NOT override PORT. Setting PORT=34197 (the standard Factorio
# game port) would silently break the healthcheck because Railway's
# HTTP proxy targets whatever PORT is set to. With PORT=8080, the
# proxy hits 8080 and our socat answers 200. Players connect on
# port 8080/udp (not 34197), which is a known Railway-port quirk.
nohup /usr/local/bin/railway-health.sh >/tmp/railway-health.log 2>&1 &
HEALTH_PID=$!
echo "[factorio-railway] health server pid=${HEALTH_PID} port=${PORT:-8080}"

# Clean up the health server if the upstream entrypoint exits (best effort)
trap 'kill ${HEALTH_PID} 2>/dev/null || true' EXIT

# The upstream entrypoint is at /docker-entrypoint.sh (not
# /factorio/...). The upstream Dockerfile does `COPY files/*.sh /`
# so it lands at the root of the image.
exec /docker-entrypoint.sh "$@"
