#!/bin/bash
# Tiny HTTP health server for Railway's HTTP-only healthcheck.
# Returns 200 OK on every request. This is the lightest possible
# way to satisfy Railway's healthcheck for a UDP-only game server
# (Factorio doesn't speak HTTP).
#
# Listens on 8080 — Railway injects PORT (usually 8080), and we
# use 8080 for the health server. The game itself binds UDP on
# 8080 too (also driven by PORT) — UDP/TCP share port numbers on
# the same address, so a TCP listener and a UDP listener coexist.
set -eu

PORT="${HEALTH_PORT:-8080}"
RESPONSE_FILE="/tmp/factorio-health-response.txt"

# Write a fixed 200 OK response once. The body MUST be CRLF, not
# LF (HTTP/1.1 wire format). We use bash here (not dash) so the
# echo -e is interpreted; the entrypoint's `set -eu` doesn't help
# if we end up in /bin/sh.
{
  printf 'HTTP/1.1 200 OK\r\n'
  printf 'Content-Type: text/plain\r\n'
  printf 'Content-Length: 2\r\n'
  printf 'Connection: close\r\n'
  printf '\r\n'
  printf 'ok'
} > "$RESPONSE_FILE"

echo "[factorio-health] listening on TCP ${PORT} for Railway healthchecks"

# socat forks per connection, so the container survives Railway's
# retry loop. `cat` writes the response bytes verbatim — no shell
# parsing, no escape ambiguity, no dash.
exec socat -T30 TCP-LISTEN:${PORT},fork,reuseaddr \
  SYSTEM:"cat ${RESPONSE_FILE}"
