scripts/bootstrap.sh — README  (v1.0.0-rc1)
========================================

Purpose
-------
Idempotent one-shot provisioner for multi-instance Actual Sync Server on TurnKey Linux.

TL;DR
-----
Preview:
  ./scripts/bootstrap.sh --dry-run --domain example.com

Live (non-interactive):
  ./scripts/bootstrap.sh -y --domain example.com

Install a specific version (preview):
  ./scripts/bootstrap.sh --dry-run --install-version v25.9.0 --domain example.com

Notes:
- If you pass --domain, you must also pass --yes (live) or --dry-run (preview).
- If omitted, bootstrap prompts (or defaults to example.com when -y is used).
- Installer validates --install-version against npm and performs an atomic install via a temp build dir (no leftover dirs on failure).

What it does
------------
- Creates service user budget-server with home /home/budget-server and shell /bin/bash.
- Ensures directories: /srv/app, /srv/backups, /srv/<instance>/data.
- Installs local npm package @actual-app/sync-server@<version> into /srv/app/vX.Y.Z.
- Links per-instance symlinks: /srv/app/{development,test,production} -> /srv/app/vX.Y.Z.
- Seeds /srv/<instance>/data/config.json from configs/config.json.tpl (fallback inline JSON).
- Writes systemd units (graceful stop + conservative hardening).
- Writes Nginx vhosts with /healthz and /health/upstream.
- Installs "actualctl" into PATH by default (override with --ctl-path).
- Installs package VERSION manifest to /usr/share/tkl-actual-bootstrap/VERSION.

Usage
-----
./scripts/bootstrap.sh [--yes|-y] [--dry-run] [--domain <name>] [--install-version vX.Y.Z] [--ctl-path /path/actualctl] [--version]

Options
-------
--yes, -y       Non-interactive live mode (assume Yes).
--dry-run       Preview only, no changes.
--domain NAME   Base domain (e.g., example.com). Requires --yes or --dry-run if provided.
--install-version VER   Actual sync-server npm version to install (default: v25.7.1).
--ctl-path PATH Install actualctl to this path (default: /usr/local/sbin/actualctl).
--help          Show help.
--version       Show script/package versions and exit.

Files written
-------------
/etc/actual-budget/env                     (BUDGET_DOMAIN=...)
/etc/systemd/system/<instance>-budgetapp.service
/etc/nginx/sites-available/<instance>-budgetapp.conf  (+ symlink in sites-enabled)
/srv/<instance>/data/config.json
/usr/share/tkl-actual-bootstrap/VERSION

Health & verify
---------------
Open:
  https://<instance>-budgetapp.<domain>/healthz        -> ok
  https://<instance>-budgetapp.<domain>/health/upstream -> 200/404 expected
Run:
  actualctl doctor   (checks services, ports, nginx -t, upstream)
  actualctl doctor --fix   (also installs/refreshes package VERSION manifest)

Troubleshooting
---------------
nginx: [emerg]    -> nginx -t; verify template substitutions (HOST/PORT).
npm EACCES        -> ensure /home/budget-server/.npm exists and owned by budget-server.
502 Bad Gateway   -> service active? port match between config.json and Nginx upstream? certs exist?
