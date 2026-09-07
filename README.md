# Factorio — Headless Server on Railway

[![Deploy to Railway](https://railway.app/button.svg)](https://railway.com/deploy/factorio)

> Factorio is a paid game. Each player who joins your server needs their own
> Factorio license. This template only runs the headless server binary — players
> connect from their own desktop client.

This template deploys the official `factoriotools/factorio:2.0.77` headless
container on Railway, with a persistent volume for save files, mods, and config.
Optimized for low-RAM 24/7 sticky hosting.

# Deploy and Host

Deploy with one click. On first boot the container:

1. Mounts the persistent Railway volume at `/factorio` (saves, config, mods survive redeploys).
2. Generates a random **RCON password** and writes it to `/factorio/config/rconpw`.
3. Copies the default `server-settings.json`, `map-gen-settings.json`, and `map-settings.json` from the image.
4. Creates a new save if `GENERATE_NEW_SAVE=true` (otherwise loads the most recent save in `/factorio/saves`, or refuses to start if `LOAD_LATEST_SAVE=false`).
5. Starts the game on UDP 8080 (game traffic) and TCP 27015 (RCON admin). UDP 8080 is shared with the HTTP health server (socat listens on TCP 8080 — the two protocols coexist because they don't collide).

Players connect from Factorio's **Multiplayer → Connect to address** screen
using the **playit.gg allocation address** — see [Connecting](#connecting).
Railway's public network is TCP/HTTP only, so the UDP game port is exposed
through the bundled playit.gg tunnel agent, not the Railway domain directly.
The RCON port lets you run admin commands from any RCON client (e.g.
[rcon-cli](https://github.com/gorcon/rcon-cli)) over a Railway TCP proxy.

## About Hosting

- **Single service**, official `factoriotools/factorio:2.0.77` image — no source build, 132 MB cold start plus ~700 KB for `socat` (used for the HTTP health server).
- **Persistent Railway volume** at `/factorio` (saves, mods, config, RCON password, logs).
- **Game port** UDP 8080 + **RCON port** TCP 27015. The UDP game port reaches players through the bundled playit.gg tunnel agent (Railway's public network is TCP/HTTP only — see [Connecting](#connecting)); RCON is on the same host on TCP 27015 (use the Railway TCP proxy or run `rcon-cli` from a sidecar — see [Connecting](#connecting)).
- **Default resource**: 1 vCPU / 1 GB RAM. Factorio headless with 8–10 players runs fine in 512 MB; 1 GB is comfortable headroom.
- **HTTP healthcheck endpoint** at `GET /` (returns `200 ok`) so Railway's HTTP-only healthcheck can verify the container is up. Implemented as a tiny `socat` listener on the Railway-injected `PORT` (default 8080) — see `health.sh`.
- **Runs as root** so the upstream entrypoint can chown the Railway-managed volume to the `factorio` user, then drops to that user before exec.

## Why Deploy

Self-hosting a Factorio server means your factory keeps running between
sessions — your conveyor belts keep churning, your trains keep rolling, your
research queue keeps advancing. Railway's sticky deployment means no surprise
reboots when traffic is low: the container stays warm and your world stays live.

## Dependencies for factorio

### Deployment Dependencies

| Dependency | Required | Purpose |
|---|---|---|
| `factoriotools/factorio:2.0.77` image | Yes | Official headless server binary |
| Railway persistent volume at `/factorio` | Yes | Saves, mods, config, RCON password survive redeploys |
| Free [playit.gg](https://playit.gg) account | Yes | UDP game tunnel (Railway's public network is TCP/HTTP only) |
| UDP 8080 | Yes | Game traffic (TCP 8080 on the same number serves the HTTP healthcheck) |
| TCP 27015 | Optional | RCON admin access (expose via a Railway TCP proxy) |

## Common Use Cases

- **24/7 factory** — the world keeps simulating between sessions: research, trains, and belts keep moving while you're away.
- **Persistent multiplayer worlds** — saves survive redeploys; friends join at `<address>:8080` from the vanilla client.
- **Modded servers** — drop mod zips into `/factorio/mods`, optionally auto-update on every boot.
- **RCON automation** — script whitelists, bans, saves, and chat over TCP 27015.

## Configuration

Most configuration is via the upstream image's env vars. See `.env.example` for
the full list. The most useful:

| Variable | Default | Purpose |
|---|---|---|
| `SAVE_NAME` | *(empty)* | Load a specific save. Empty = load most recent. |
| `LOAD_LATEST_SAVE` | `true` | Auto-load the most recent save in `/factorio/saves` |
| `GENERATE_NEW_SAVE` | `false` | Create a new timestamped save on boot |
| `UPDATE_MODS_ON_START` | `false` | Re-download mods listed in `mod-list.json` on every boot |

**Server identity, password, max players, visible-in-browser, etc.** are all
in `/factorio/config/server-settings.json`, which the image copies from its
default on first boot. **Edit that file directly** via the volume after first
deploy, or rebuild the image with a baked-in `server-settings.json`.

The **RCON password** lives at `/factorio/config/rconpw` (auto-generated on
first boot). Read it back from the volume to use it; the upstream entrypoint
won't overwrite it on subsequent boots.

## Connecting

Once the service is up (and you've set the `playit` agent's `SECRET_KEY`):

1. **Create a free account** at [playit.gg](https://playit.gg), then Account → Agents → **Add Agent** → copy the secret key.
2. **In Railway**, open the `playit` service → Variables → paste the key as `SECRET_KEY`.
3. **In playit.gg** → Tunnels → **Add Tunnel**: type **UDP**, local address `factorio.railway.internal`, local port `8080`. Playit assigns you a public allocation address (e.g. `1.2.3.4:5432`).
4. **In Factorio**, click **Multiplayer → Connect to address** and paste the playit allocation address. Leave the port as assigned — the tunnel targets the game's UDP 8080 automatically. The transport is UDP (default).
5. If your `server-settings.json` has a `password` field, enter it when prompted.
6. **For RCON admin commands**: RCON runs on TCP 27015 inside the container. Railway does **not** auto-proxy arbitrary TCP ports. The simplest access path is to add a **TCP proxy** service to the same project pointing at the Factorio service's RCON port, then point your RCON client (e.g. [rcon-cli](https://github.com/gorcon/rcon-cli)) at the TCP proxy's hostname:port with the password from `/factorio/config/rconpw` (read it from the volume). Alternatively, exec into the running container via the Railway shell and use `nc` locally.

> The Railway HTTP domain (e.g. `https://<service>.up.railway.app/`) returns `200 ok` — that's the healthcheck responder. There's no web UI; players connect through the playit allocation, not the Railway domain.

## Custom Maps / Saves

To upload a custom save:

1. Use the Railway dashboard's volume access (or shell) to drop a `*.zip` file into `/factorio/saves/`.
2. Set `SAVE_NAME=your-save` (no extension) and redeploy.

The upstream entrypoint loads the save whose name matches `SAVE_NAME`, or, if
that's empty, the most recently modified save in the directory.

## Mods

Drop `.zip` mod files into `/factorio/mods/` (via the volume or shell).
Optionally create a `mod-list.json` and set `UPDATE_MODS_ON_START=true` to
auto-download mod versions on every boot.

## Common Operations

| Goal | How |
|---|---|
| Read the auto-generated RCON password | `cat /factorio/config/rconpw` via the Railway volume |
| Change server name | Edit `/factorio/config/server-settings.json` (or rebuild with a baked-in file) |
| Add a player slot | Edit `max_players` in `server-settings.json` |
| Whitelist a player | RCON: `/whitelist add <username>` |
| Ban a player | RCON: `/ban <username>` |
| Save the world now | RCON: `/server-save` |
| Roll back to a previous save | Drop the old `*_x.zip` file into `/factorio/saves` and set `SAVE_NAME` to its base name |
| Reset the world | `rm /factorio/saves/*.zip`, set `GENERATE_NEW_SAVE=true`, redeploy |

## Cost

A 1 GB / 1 vCPU Factorio server running 24/7 on Railway's Hobby plan costs
roughly **$5–8/month** (Railway charges by usage, and a 24/7 game server can't
idle). This template is sized to the 1 GB tier because Factorio's "minimum"
is 1 GB and most players want headroom — drop to 512 MB in the service
settings if you want to optimize.

## License

Factorio itself is proprietary software by Wube Software. This template only
runs the headless server binary distributed in the official `factoriotools/factorio`
Docker image; you must own a Factorio license to use it.
