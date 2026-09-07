# playit — UDP Tunnel Agent Service

Companion service in the Factorio template. Runs the official
[`ghcr.io/playit-cloud/playit-agent`](https://github.com/playit-cloud/playit-agent)
image (pinned `1.0.8`) as a **direct image source**. No Dockerfile: the upstream
image is deployed as-is with one variable.

## Why this service exists

Railway's public network is TCP/HTTP only — Factorio's game traffic (UDP :8080)
cannot be exposed directly. The playit agent makes **outbound** connections to
playit.gg's edge and tunnels player UDP traffic back over Railway's private
network to `factorio.railway.internal:8080`.

Note: the HTTP healthcheck (TCP 8080, socat) and RCON (TCP 27015) are unaffected —
TCP can be exposed natively on Railway. Only the UDP game port needs the tunnel.

## Variable

`SECRET_KEY` — the agent secret from your playit.gg account (required).

The upstream entrypoint runs: `playitd --secret $SECRET_KEY --platform-docker`.
Until a valid key is set, the agent exits with an auth error and restarts
(non-fatal to the factorio service).

## Post-deploy setup (manual, in playit.gg dashboard)

1. Create a free account at https://playit.gg
2. Account → Agents → **Add Agent** → copy the **secret key**
3. In Railway, set `SECRET_KEY` on the `playit` service
4. In playit.gg → Tunnels → **Add Tunnel**:
   - Type: **UDP**
   - Local address: `factorio.railway.internal`
   - Local port: `8080`
5. Give players the allocation address playit.gg assigns

Cross-service private networking resolves `factorio.railway.internal`
automatically within the same Railway project.