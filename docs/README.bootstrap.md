<<<<<<< HEAD
# bootstrap.sh — Documentation (v0.21.0)
=======
# bootstrap.sh — Documentation (v0.22.0)
>>>>>>> alpha

**Project:** tkl-actual-bootstrap  
**Author:** Ken Robinson (<ken@turnkeylinux.org>)  
**License:** GPL-3.0-or-later — see [LICENSE](../LICENSE)  
**Source:** https://github.com/DocCyblade/tkl-actual-bootstrap

**Latest changes:** See root `CHANGELOG.md` → `scripts/bootstrap.sh`.

## Purpose
Provision a host with multi-instance Actual Sync Server, create systemd services, generate Nginx vhosts for your domain, and set up symlinked app tracks.

## Usage
```
./scripts/bootstrap.sh [--yes] [--dry-run] [--domain example.com] [-h|--help]
```

### Options
- `--yes, -y` — run non-interactively.
- `--dry-run` — print actions without changing the system.
- `--domain example.com` — set the domain for vhosts. Saved to `/etc/actual-budget/env`.
- `-h, --help` — usage text.

## What it does
1. Creates/updates the `budget-server` system user (home: `/home/budget-server`).
2. Ensures directories:
   - `/srv/app`, `/srv/backups`
   - `/srv/{development,test,production}/data`
3. Installs `@actual-app/sync-server@${VERSION}` into `/srv/app/${VERSION}` via npm (as `budget-server`).
4. Creates symlinks: `/srv/app/{development,test,production} -> /srv/app/${VERSION}`.
5. Seeds `config.json` into each instance’s data dir.
6. Installs systemd units and starts services.
7. Generates Nginx vhosts: `development|test|production-budgetapp.<domain>` with `/healthz` and `/health/upstream` endpoints.
8. Tests and reloads Nginx.

## Idempotency
- Re-running is safe: existing dirs/links are detected, and files are only replaced if changed.

## Logs & Troubleshooting
- Systemd status/logs: `systemctl status production-budgetapp.service`, `journalctl -u production-budgetapp.service -f`
- Nginx test: `nginx -t`
- Health checks: 
  - `curl -I https://development-budgetapp.example.com/healthz`
  - `curl -I https://development-budgetapp.example.com/health/upstream`


See also top-level README **Troubleshooting** and **Prerequisites** sections.