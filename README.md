# tkl-actual-bootstrap

Bootstrap for running the **Actual** Sync Server (multi-instance) on **TurnKey Linux**.

- **License:** GNU GPL v3  
- **Author:** Ken Robinson (<ken@turnkeylinux.org>)  
- **Source:** https://github.com/DocCyblade/tkl-actual-bootstrap

> Bundle docs version: **v0.23.0** — default Actual version: **v25.7.1**

## What’s new (v0.23.0)
- `actualctl instance set-port <NAME> <PORT>` — updates `/srv/<NAME>/data/config.json` and restarts the instance.
- `actualctl health [INSTANCE]` — checks Nginx upstream (`/health/upstream`) and backend reachability.
- `actualctl doctor` — full system check (required tools, `nginx -t`, service state, port listening, upstream health).
- Help text in `actualctl` and `README.actualctl.md` are synchronized.
- Instance discovery is dynamic: commands operate on all `/srv/*/data` instances, not just dev/test/prod.

## Quick Start
```bash
# bootstrap (unchanged here; see README.bootstrap.md if needed)
./scripts/bootstrap.sh --dry-run
./scripts/bootstrap.sh --yes

# manage with helper
actualctl list
actualctl health
actualctl doctor
```

## Common Port Map
| Instance     | Port |
|--------------|------|
| development  | 5006 |
| test         | 5000 |
| production   | 5001 |

## Prerequisites
- TurnKey Linux **Node.js (v18)** appliance, updated (`apt update && apt upgrade`)
- Root shell (no `sudo` assumptions)
- Nginx installed (TurnKey default)
- TLS key/cert at `/etc/ssl/private/cert.key` and `/etc/ssl/private/cert.pem`

## Migration from pre–v0.20
- Use versioned app dirs under `/srv/app/vX.Y.Z` with symlinks `/srv/app/<instance>`.
- Config lives at `/srv/<instance>/data/config.json`; services set `ACTUAL_DATA_DIR` accordingly.
- Nginx provides `/healthz` and `/health/upstream` endpoints for checks.
- Migrate user data with `actualctl backup/restore`.

## License
GPLv3 — see `LICENSE` in the main repo.
