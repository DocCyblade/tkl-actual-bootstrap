# tkl-actual-bootstrap

Bootstrap for running the **Actual** Sync Server (multi-instance) on **TurnKey Linux**.

- **Project:** tkl-actual-bootstrap _(Bootstrap for Actual Sync Server on TurnKey Linux)_
- **License:** GNU GPL v3
- **Author:** Ken Robinson (<ken@turnkeylinux.org>)
- **Source:** https://github.com/DocCyblade/tkl-actual-bootstrap

> Docs bundle: **v0.23.1** — default Actual version: **v25.7.1**

## What’s new in v0.23.1
- **scripts/actualctl**: `list` now shows only **version directories** under `/srv/app` (e.g., `v25.7.1`), never the contents of those directories.
- **scripts/bootstrap.sh**: no functional changes from v0.23.0; docs synced (prereqs clarified).
- **Docs:** Added folder-level READMEs for **nginx**, **systemd**, **configs**, and CI; added **TROUBLESHOOTING.md** and **MIGRATION.md**.

## Quick Start
```bash
# 1) Preview
./scripts/bootstrap.sh --dry-run

# 2) Provision (creates user, installs app, writes configs, units, nginx vhosts)
./scripts/bootstrap.sh --yes --domain example.com --version v25.7.1

# 3) Verify
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
- **Platform:** TurnKey Linux **Node.js v18** appliance with updates (`apt update && apt upgrade`)
- **Privileges:** Run as **root** (no `sudo` assumptions)
- **TLS:** `/etc/ssl/private/cert.pem` and `/etc/ssl/private/cert.key`
- **Tools:** `node`, `npm`, `systemctl`, `nginx`, `sed`, `install`, `ln`, `mkdir`, `chown`, `cmp`, `useradd`

## Migration from pre–v0.20
See **MIGRATION.md** for a step-by-step guide.

## Troubleshooting
See **TROUBLESHOOTING.md** for a detailed checklist and commands.
