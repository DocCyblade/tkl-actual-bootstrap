scripts/bootstrap.sh — README  (v1.0.0-rc1)
========================================

Purpose
-------
Idempotent one‑shot provisioner for multi‑instance Actual Sync Server on TurnKey Linux.
**RC1 change:** bootstrap installs the app + tooling and then **delegates per‑instance work**
(config.json, systemd unit, and per‑instance Nginx vhost) to:
  actualctl instance add <NAME> <VERSION> --port <PORT> --domain <FQDN>

TL;DR
-----
Preview:
  ./scripts/bootstrap.sh --dry-run --domain example.com

Live (non‑interactive, defaults dev/test/production):
  ./scripts/bootstrap.sh -y --domain example.com

Install a specific version (preview):
  ./scripts/bootstrap.sh --dry-run --install-version v25.7.1 --domain example.com

Custom instances (NAME[:PORT][@FQDN]):
  ./scripts/bootstrap.sh -y --domain example.com \
    --instances "prod:5099@budget.example.com,staging:5002"

Notes:
- If you pass --domain, you must also pass --yes (live) or --dry-run (preview).
- If omitted, bootstrap prompts (or defaults to example.com when -y is used).
- Installer validates --install-version against npm and performs an atomic install via a temp build dir (no leftover dirs on failure).
- **RC1:** Per‑instance creation/updates are performed by `actualctl`, not by bootstrap.

What it does
------------
- Creates service user **budget-server** with home **/home/budget-server** and shell **/bin/bash**.
- Ensures base directories: **/srv/app**, **/srv/backups**.
- Installs local npm package **@actual-app/sync-server@<version>** into **/srv/app/vX.Y.Z**.
- Installs the **actualctl** CLI (override path with **--ctl-path**), docs, and bash completions.
- Records domain in **/etc/actual-budget/env** (**BUDGET_DOMAIN=...**).
- For each instance (default: development/test/production, or overridden via **--instances**), calls:
    actualctl instance add <NAME> <VERSION> --port <PORT> --domain <FQDN>
  which will:
  - Create **/srv/<NAME>/data** and seed **config.json** from **configs/config.json.tpl** (fallback inline JSON).
  - Link **/srv/app/<NAME> -> /srv/app/vX.Y.Z**.
  - Write **systemd** unit **<NAME>-budgetapp.service** and enable/start it.
  - Render per‑instance **Nginx** vhost **/etc/nginx/sites-available/actual-<NAME>.conf** (+ symlink in sites‑enabled) with **/healthz** and **/health/upstream**.
- Installs package **VERSION** manifest to **/usr/share/tkl-actual-bootstrap/VERSION**.

Usage
-----
./scripts/bootstrap.sh [--yes|-y] [--dry-run] [--domain <name>] \
  [--install-version vX.Y.Z] [--ctl-path /path/actualctl] \
  [--instances "NAME[:PORT][@FQDN][,NAME[:PORT][@FQDN],...]"] [--version]

Options
-------
--yes, -y         Non‑interactive live mode (assume Yes).
--dry-run         Preview only, no changes.
--domain NAME     Base domain (e.g., example.com). Requires --yes or --dry-run if provided.
--install-version VER   Actual sync‑server npm version to install (default: v25.7.1).
--ctl-path PATH   Install **actualctl** to this path (default: /usr/local/sbin/actualctl).
--instances SPEC  Override default instances. Comma‑separated **NAME[:PORT][@FQDN]** items.
                  Examples:
                    --instances "development,test,production"         (defaults)
                    --instances "development:5006,test:5000,production:5001"
                    --instances "prod:5099@budget.example.com"
                    --instances "staging:5002,prod@budget.example.com"  (# prod auto‑assigns next free port ≥5002)
                  Port rules: default names use their default ports if omitted; other names auto‑assign next free port ≥5002.
                  FQDN rule: if omitted, default is **<NAME>-budgetapp.<DOMAIN>**.
--help            Show help.
--version         Show script/package versions and exit.

Files written
-------------
/etc/actual-budget/env                             (BUDGET_DOMAIN=...)
/usr/local/sbin/actualctl                          (CLI; path overridden by --ctl-path)
/usr/share/tkl-actual-bootstrap/docs/README.actualctl.txt
/usr/share/tkl-actual-bootstrap/VERSION            (package manifest)
# Per‑instance (authored by actualctl):
/etc/systemd/system/<NAME>-budgetapp.service
/etc/nginx/sites-available/actual-<NAME>.conf  (+ symlink in sites-enabled)
/srv/<NAME>/data/config.json

Health & verify
---------------
Open (default FQDN):
  https://<NAME>-budgetapp.<domain>/healthz        -> ok
  https://<NAME>-budgetapp.<domain>/health/upstream -> 200/404 expected
Open (custom FQDN via @FQDN):
  https://<FQDN>/healthz
  https://<FQDN>/health/upstream
Run:
  actualctl doctor
  actualctl doctor --fix   (also installs/refreshes package VERSION manifest)

Troubleshooting
---------------
nginx: [emerg]         -> nginx -t; confirm vhost filename **actual-<NAME>.conf** and upstream PORT match.
npm EACCES             -> ensure /home/budget-server/.npm exists and owned by budget-server.
502 Bad Gateway        -> service active? PORT in /srv/<NAME>/data/config.json matches vhost upstream? certs present?
