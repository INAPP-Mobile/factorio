#!/bin/bash
# Tiny HTTP health server for Railway's HTTP-only healthcheck.
# Returns 200 OK on every request. This is the lightest possible
# way to satisfy Railway's healthcheck for a UDP-only game server
# (Factorio doesn't speak HTTP).
#
# Listens on 8080 — Railway injects PORT=34197 to make Factorio
# bind to the standard game port, but the HTTP healthcheck still
# needs an HTTP endpoint on 8080. 8080 is the conventional Railway
# HTTP port and is also EXPOSEd in the Dockerfile.
set -eu

PORT=8080

echo "[factorio-health] listening on TCP ${PORT} for Railway healthchecks"

# socat one-liner: serve a fixed 200 OK response on every connection.
# `fork` lets it accept multiple connections (healthcheck probes).
# `reuseaddr` avoids TIME_WAIT issues during redeploys.
exec socat -T30 TCP-LISTEN:${PORT},fork,reuseaddr SYSTEM:'printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"'
