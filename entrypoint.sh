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
#   3. Then exec the upstream entrypoint.
set -eu

echo "[factorio-railway] starting"
echo "[factorio-railway] image: factoriotools/factorio:2.0.77"
echo "[factorio-railway] uid=$(id -u) gid=$(id -g) factorio_uid=845"

# The upstream entrypoint is at /docker-entrypoint.sh (not
# /factorio/...). The upstream Dockerfile does `COPY files/*.sh /`
# so it lands at the root of the image.
exec /docker-entrypoint.sh "$@"
