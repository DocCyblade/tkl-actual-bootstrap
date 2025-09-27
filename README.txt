tkl-actual-bootstrap  v0.24.1
Bootstrap for running Actual Sync Server on TurnKey Linux (NodeJS appliance v18)

License: GNU GPLv3
Author : Ken Robinson <ken@turnkeylinux.org>
Source : https://github.com/DocCyblade/tkl-actual-bootstrap


QUICK START
-----------
1) Make scripts executable:
   chmod +x scripts/*.sh

2) Preview changes (dry run):
   ./scripts/bootstrap.sh --dry-run --domain example.com

3) Apply changes (live, non-interactive):
   ./scripts/bootstrap.sh -y --domain example.com

Notes:
- If you pass --domain, you must also pass --yes (live) or --dry-run (preview).
- If --domain is omitted, bootstrap will prompt (or default to example.com in -y mode).
- By default, bootstrap installs @actual-app/sync-server v25.7.1 and installs the
  "actualctl" CLI into /usr/local/sbin/actualctl (override with --ctl-path).
- To install a specific version, add --install-version vX.Y.Z


PREREQUISITES
-------------
- TurnKey Linux NodeJS appliance v18 with: apt update && apt upgrade
- Tools available: node, npm, nginx, systemd, curl  (optional: jq, rsync)
- TLS certificates on TurnKey:
  /etc/ssl/private/cert.pem
  /etc/ssl/private/cert.key


INSTALLATION LAYOUT
-------------------
/srv/app/vX.Y.Z            Local npm install of @actual-app/sync-server
/srv/app/development       Symlink -> /srv/app/vX.Y.Z
/srv/app/test              Symlink -> /srv/app/vX.Y.Z
/srv/app/production        Symlink -> /srv/app/vX.Y.Z
/srv/<instance>/data       ACTUAL_DATA_DIR (config.json lives here)
- development : 5006
- test        : 5000
- production  : 5001
/srv/backups               Backup archives
/etc/actual-budget/env     BUDGET_DOMAIN=example.com
/etc/systemd/system/*      Instance units (<instance>-budgetapp.service)
/etc/nginx/sites-available/*-budgetapp.conf  Nginx vhosts (enabled via symlink)


HEALTH & ADMIN
--------------
Nginx health endpoints:
- https://<instance>-budgetapp.<domain>/healthz         (nginx-only, returns "ok")
- https://<instance>-budgetapp.<domain>/health/upstream (proxies to backend; expect 200/404)

CLI helpers:
- actualctl --help
- actualctl --version
- ./scripts/bootstrap.sh --version


WHAT BOOTSTRAP DOES
-------------------
- Creates service user "budget-server" with home /home/budget-server and shell /bin/bash.
- Ensures directories: /srv/app, /srv/backups, /srv/<instance>/data.
- Installs sync-server locally under /srv/app/vX.Y.Z as "budget-server".
- Links per-instance app symlinks: /srv/app/{development,test,production} -> /srv/app/vX.Y.Z.
- Seeds /srv/<instance>/data/config.json from configs/config.json.tpl (fallback inline JSON).
- Writes systemd units with graceful stop (SIGINT, TimeoutStopSec=15) and conservative hardening.
- Writes Nginx vhosts with TLS, /healthz, /health/upstream.
- Installs "actualctl" into PATH by default (override path with --ctl-path).
- Installs package VERSION manifest to /usr/share/tkl-actual-bootstrap/VERSION
- Records domain in /etc/actual-budget/env (BUDGET_DOMAIN=...).

Systemd units (per instance):
- Name: <instance>-budgetapp.service
- WorkingDirectory: /srv/app/<instance>  (symlink -> /srv/app/vX.Y.Z)
- Environment: ACTUAL_DATA_DIR=/srv/<instance>/data


ACTUALCTL QUICK REFERENCE
-------------------------
List instances, versions, service state:
  actualctl list

Fetch and install a version:
  actualctl fetch v25.7.1

Switch an instance to a version:
  actualctl switch production v25.7.1

Health and doctor:
  actualctl health production
  actualctl doctor
  actualctl doctor --fix

Backups:
  actualctl backup production "pre-upgrade"
  actualctl restore production /srv/backups/production-YYYYMMDD-HHMMSS.tgz
  actualctl prune-backups --keep 7

Instances:
  actualctl instance add staging v25.7.1 --from production --port 5002
  actualctl instance set-port staging 5003
  actualctl instance rm staging --purge

Services and logs:
  actualctl service production restart
  actualctl logs production 200


TROUBLESHOOTING
---------------
502 Bad Gateway:
- Run: actualctl health <instance>
- Check backend: journalctl -u <instance>-budgetapp -n 200
- Validate Nginx config: nginx -t
- Confirm instance port in /srv/<instance>/data/config.json matches the Nginx upstream
- Ensure the systemd service is active

Permissions:
- Ensure /srv/<instance> is owned by budget-server:budget-server

Certificates:
- Ensure /etc/ssl/private/cert.pem and /etc/ssl/private/cert.key exist and are valid


MIGRATION FROM PRE–v0.20
------------------------
- Standardize on instances: development, test, production
- Domain is stored in /etc/actual-budget/env (BUDGET_DOMAIN=...)
- See docs/MIGRATION.txt for step-by-step restore and validation


NOTES FOR v0.24.1
-----------------
- CLI: `bootstrap.sh` now uses `--install-version` to select the Actual app version; `--version` (no arg) prints script/package versions.
- Dynamic versioning in both scripts; banners and `--version` outputs show `script <Script-Version> (package <PKG_VERSION>)`.
- `actualctl doctor --fix` installs/refreshes the system VERSION manifest.
- New `VERSION` manifest is installed to `/usr/share/tkl-actual-bootstrap/VERSION` by bootstrap.
- Synchronized headers and plain-text docs; see CHANGELOG.txt for details.


LICENSE
-------
GNU GPLv3 (see LICENSE)
