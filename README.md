# tkl-actual-bootstrap (v0.22.0)

## Changes in v0.22.0
- Version bump to v0.22.0.
- Formalizes fixes for Issues #1–#4 (executable bits, readable banners, bootstrap help on no-args, Nginx templating).
- Script headers updated to v0.22.0. Other documentation preserved from v0.21.0.

**Bootstrap for running Actual Sync Server on Turnkey Linux.**

**Last changes since v0.20.3**
- Generic docs and prompts tightened; typo fixes in helper.
- README set now includes: Quick Start, Bundle layout, and per-script docs.
- Each script carries a version header and links to `CHANGELOG.md`.

## What this bundle does

Install and manage **multiple Actual Sync Server instances** behind Nginx on a single host:
- Instances: **development**, **test**, **production**
- Symlinked app tracks: `/srv/app/development`, `/srv/app/test`, `/srv/app/production`
- Instance data: `/srv/<instance>/data` with `config.json`
- Reverse proxy: Nginx vhosts (TLS at `/etc/ssl/private/cert.pem` + `/etc/ssl/private/cert.key`)
- Service user: `budget-server` (home at `/home/budget-server`)

### Quick Start
```bash
# 1) Preview changes
./scripts/bootstrap.sh --dry-run

# 2) Install with your domain
./scripts/bootstrap.sh --yes --domain example.com

# 3) Install helper and verify
install -m 0755 scripts/actualctl /usr/local/bin/actualctl
actualctl check
```

### Prerequisites
- Built and tested on **TurnKey Linux NodeJS v18.0** (<https://www.turnkeylinux.org/nodejs>) with all updates applied (`apt update && apt upgrade`).
- Linux host with root access (tested on TurnKey Linux NodeJS).
- **Node.js 18+** and **npm** installed (TurnKey NodeJS ISO includes these).
- **Nginx** installed and enabled (`nginx -v`).
- TLS files present (or to be placed) at:
  - `/etc/ssl/private/cert.pem`
  - `/etc/ssl/private/cert.key`
- Outbound network access to npm registry.

### Troubleshooting
- **npm EACCES** referencing `/srv/.npm`  
  This bundle uses the `budget-server` user's HOME/cache; if you see `/srv/.npm` in errors, re-run bootstrap so it creates `/home/budget-server/.npm` and installs as that user.

- **`nginx -t` fails**  
  Check syntax of generated vhosts in `/etc/nginx/sites-available/*-budgetapp.conf`. Ensure TLS paths exist (`/etc/ssl/private/cert.pem`, `/etc/ssl/private/cert.key`).

- **Service not listening on port**  
  `actualctl check` → see `PORTS` section. Confirm the systemd unit is active: `systemctl status <instance>-budgetapp.service`. View logs: `actualctl <instance> logs`.

- **Port already in use**  
  Edit `/srv/<instance>/data/config.json` and pick a free port, then `systemctl restart <instance>-budgetapp.service`.

- **Permission issues under /srv**  
  We intentionally **do not** change ownership of `/srv` root. Instance dirs are owned by `budget-server`. If you manually create dirs, ensure they are `chown -R budget-server:budget-server /srv/<instance>`.

- **Missing `runuser`**  
  The scripts fall back to `su`. Ensure `/bin/bash` exists and is set as the shell for `budget-server`.

- **TLS not ready yet**  
  Sites can come up over HTTP→HTTPS redirect errors if TLS files are missing. Place cert/key or adjust the Nginx config paths as needed and reload.

- **DNS not pointed yet**  
  You can still verify locally with `curl -k https://127.0.0.1:443/healthz --resolve production-budgetapp.example.com:443:127.0.0.1` (replace hostname and IP).

- **Stuck after switching versions**  
  `actualctl switch <track> <version>` stops, re-links, starts. If a service fails, check logs and ensure the new version exists under `/srv/app/<version>` and contains `node_modules/.bin/actual-server`.



> **Versioning note:** starting with this release we label bundles as **v0.xx**.  
> The previous release **v19** corresponds to **v0.19**.

### Layout
- `/srv/app/vX.Y.Z` — versioned app installs (via npm)
- `/srv/app/production|development|test` — symlinks to chosen version
- `/srv/<instance>/data` — per-instance data + `config.json`
- `/srv/backups` — `.tgz` backups produced by the helper
- `/etc/actual-budget/env` — `BUDGET_DOMAIN` and future defaults

### Bundle contents
- `scripts/bootstrap.sh` — one-shot, idempotent installer
- `scripts/actualctl` — operations helper
- `systemd/*.service` — units for the three base instances
- `configs/*/config.json` — seed configs (ports preset)
- `nginx/templates/vhost.conf.tpl` — reference vhost template
- `docs/README.bootstrap.md` — bootstrap docs
- `docs/README.actualctl.md` — helper docs
- `CHANGELOG.md` — complete per-script change history

# Common port map

By default the bundle seeds these ports:

| Role / Instance | Default Port | Notes |
|---|---:|---|
| **test** | **5000** | Stable default for testing |
| **production** | **5001** | Prod instance |
| **development** | **5006** | Kept separate to avoid collisions |
| (legacy: prod-family) | 5001/5002 | Historical split; keep as custom instance if desired |

## Adding more instances
- `actualctl instance add` picks the next free port ≥ 5000, **skipping 5006** unless explicitly set with `--port`.
Examples:
```bash
actualctl instance add personal --link production --fqdn personal-budgetapp.example.com --yes
actualctl instance add lab --link test --port 5010 --fqdn lab-budgetapp.example.com --yes
```

## Changing a port later
```bash
systemctl stop <instance>-budgetapp.service
# edit /srv/<instance>/data/config.json -> set "port": <newPort>
systemctl start <instance>-budgetapp.service
actualctl check
```

## Firewall / SELinux / AppArmor
Open the ports as needed (e.g., `ufw allow 5001/tcp`) and ensure policies permit Nginx proxying to `127.0.0.1:<port>`.


# Migration from pre–v0.20

This project changed a few conventions at v0.20:

- **Tracks/links:** `current` ➜ **`production`** (and we now have **development**, **test**, **production**).
- **Domains:** stored at `/etc/actual-budget/env` as `BUDGET_DOMAIN` (no hard-coded domain).
- **Nginx:** vhosts are generated dynamically (include `/healthz` and `/health/upstream`).
- **TLS:** defaults to TurnKey paths `/etc/ssl/private/cert.pem` and `/etc/ssl/private/cert.key` (override with `CERT_CRT`/`CERT_KEY`).
- **Service user:** `budget-server` with home `/home/budget-server` and npm cache to avoid `/srv/.npm` permission issues.

## Before you start
- Schedule a short maintenance window.
- Ensure you have backups.

## Option A — Keep existing instances, adopt new tracks
1) Back up:
```bash
actualctl backup development
actualctl backup test
# If present:
actualctl backup prod-family
```
2) Install and bootstrap:
```bash
./scripts/bootstrap.sh --yes --domain example.com
```
3) (Optional) Recreate a legacy instance to follow a track:
```bash
actualctl instance rm prod-family --keep-data --yes
actualctl instance add prod-family --link production --fqdn family-budgetapp.example.com --port 5002 --copy-from production --yes
```
4) Verify:
```bash
actualctl check
curl -I https://production-budgetapp.example.com/healthz
curl -I https://production-budgetapp.example.com/health/upstream
```

## Option B — Consolidate to a single production instance
1) Back up the source to become production:
```bash
actualctl backup prod-family
```
2) Bootstrap:
```bash
./scripts/bootstrap.sh --yes --domain example.com
```
3) Migrate data and remove legacy:
```bash
systemctl stop production-budgetapp.service
rsync -a /srv/prod-family/data/ /srv/production/data/
chown -R budget-server:budget-server /srv/production
systemctl start production-budgetapp.service

actualctl instance rm prod-family --yes
# If used:
```
4) Verify:
```bash
actualctl check
curl -I https://production-budgetapp.example.com/healthz
```

## Notes
- Restore any backup with `actualctl restore <instance> /srv/backups/<file>.tgz`.
- The old `/srv/app/current` link is replaced by `/srv/app/production`; switch with:
```bash
actualctl fetch v0.25.9
actualctl switch production v0.25.9
```
- Ensure `budget-server` exists and has `/home/budget-server`.


For full command documentation and examples, read the per-script READMEs in `docs/`. 
## License

Licensed under the **GNU General Public License v3.0 or later** (GPL-3.0-or-later).  
You should have received a copy of the license along with this project in [LICENSE](LICENSE);  
if not, see <https://www.gnu.org/licenses/>.

Copyright (C) 2025 Ken Robinson.
