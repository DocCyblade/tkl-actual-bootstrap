# README — scripts/bootstrap.sh (v0.23.1)

One-shot, idempotent provisioning for multi-instance Actual Sync Server on TurnKey Linux.

## Quick usage
```
./scripts/bootstrap.sh [--yes|-y] [--dry-run] [--domain <name>] [--version vX.Y.Z] [--install-ctl] [--ctl-path /path/actualctl]
```
Tip: run with `--dry-run` first.

## Full options
- `--yes|-y` — non-interactive mode
- `--dry-run` — preview actions without changes
- `--domain` — base domain; stored in `/etc/actual-budget/env`
- `--version` — Actual npm version (default: **v25.7.1**)
- `--install-ctl` — install `scripts/actualctl` into PATH
- `--ctl-path` — destination for `actualctl` (default: `/usr/local/sbin/actualctl`)

## Prerequisites
- Root shell (no `sudo` assumptions)
- TurnKey Linux Node.js appliance (v18) with updates (`apt update && apt upgrade`)
- TLS files at `/etc/ssl/private/cert.key` and `/etc/ssl/private/cert.pem`
- Commands: `node`, `npm`, `systemctl`, `nginx`, `sed`, `install`, `ln`, `mkdir`, `chown`, `cmp`, `useradd`

## What it creates
- System user `budget-server` (home `/home/budget-server`, shell `/bin/bash`)
- App under `/srv/app/vX.Y.Z` and symlinks `/srv/app/development|test|production`
- Data under `/srv/<instance>/data` (writes `config.json`)
- Units `<instance>-budgetapp.service` (ExecStart: `./node_modules/.bin/actual-server`)
- Nginx vhosts with `/healthz` and `/health/upstream`

## Ports
- development: **5006**
- test: **5000**
- production: **5001**

## Examples
```
./scripts/bootstrap.sh --dry-run
./scripts/bootstrap.sh --yes --domain example.com --version v25.7.1
./scripts/bootstrap.sh --yes --install-ctl --ctl-path /usr/local/sbin/actualctl
```

## Notes
- Does **not** chown `/srv`; only touches per-instance dirs and app-version dirs.
- npm runs as `budget-server` with cache under `/home/budget-server/.npm`.
- Idempotent: safe to re-run; skips unchanged steps.
