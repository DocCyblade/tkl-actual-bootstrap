scripts/actualctl — README  (v1.0.0-rc1)
=====================================

Purpose
-------
Ops CLI for managing Actual multi-instance installs on TurnKey Linux.

Quick usage
-----------
actualctl --help
actualctl help
actualctl --version

Core commands
-------------
list                 Show instances, symlinked versions, and service status
check                Basic health checks (tools present, dirs exist)
env [INSTANCE]       Show env & paths (all or one)
health [INSTANCE]    Nginx upstream + backend health (all if omitted)
doctor [--fix]       Full system check (services, ports, nginx -t, upstream); --fix also installs package VERSION manifest
status               One-line summary per instance (version link, port, domain, service state)

Version / app mgmt
------------------
fetch <vX.Y.Z>       Install @actual-app/sync-server@<ver> into /srv/app/<ver>
switch <INST> <VER>  /srv/app/<INST> -> /srv/app/<VER>, then restart service
verify <vX.Y.Z>      Install to a temp dir, smoke-check presence, cleanup (no changes to live instances)
prune-versions [--dry-run] [--keep N] [--older-than DAYS]  Remove unused /srv/app/v* (not targeted by any instance link)
list-versions [--limit N] [--pre] [--json]
                     Query npm for recent releases; default stable only. Marks installed versions.
--check-for-updates  Check if a newer stable release exists than any installed; prints summary.

Backups
-------
backup <INST> [note] Archive user-data into /srv/backups
restore <INST> <tgz> Stop, backup current, restore, chown, start
prune-backups [--keep N]  Keep N most-recent per instance (default 7)

Instances
---------
instance add <NAME> <vX.Y.Z|development|test|production> [--from SRC] [--port P] [--domain FQDN] [--no-start]
  Creates /srv/<NAME>/data (optionally copied from SRC), links /srv/app/<NAME> to target version,
  writes unit, starts service unless --no-start. If --port omitted, picks next free port.
  If --domain is provided, writes/updates an Nginx vhost for this instance (actual-<NAME>.conf).

instance rm <NAME> [--purge]
  Stop/disable unit, remove unit, optionally delete /srv/<NAME>

instance set-port <NAME> <PORT>
  Update port in config.json and restart

instance set-domain <NAME> <FQDN|none>
  Create/update (or remove, when 'none') per-instance Nginx vhost for <NAME>.

Services
--------
service <INST> start|stop|restart|status
logs <INST> [lines]

Examples
--------
actualctl list
actualctl status
actualctl fetch v25.7.1
actualctl list-versions --limit 10
actualctl --check-for-updates
actualctl switch production v25.7.1
actualctl backup production "pre-upgrade"
actualctl restore production /srv/backups/production-20250101-120000-pre-upgrade.tgz
actualctl instance add staging v25.7.1 --from production --port 5002
actualctl instance add family v25.7.1 --port 5010 --domain budget.family.tld
actualctl instance set-port staging 5003
actualctl instance set-domain family none
actualctl health production
actualctl doctor
actualctl doctor --fix
actualctl env
actualctl env production
actualctl verify v25.7.1
actualctl service production restart
actualctl logs production 200
actualctl prune-backups --keep 10
actualctl prune-versions --dry-run
actualctl prune-versions --keep 2
actualctl prune-versions --keep 2 --older-than 14

Notes
-----
- "actualctl --version" prints: actualctl <Script-Version> (package <PKG_VERSION>).
- "doctor --fix" installs/refreshes /usr/share/tkl-actual-bootstrap/VERSION.
- JSON parsing prefers jq when available; awk-based fallback is used otherwise.
- If rsync is not installed, instance data copy falls back to "cp -a" (no deletion of extraneous files).
- "status" is a concise overview: instance -> version link target, port, domain (if any), and systemd state.
- "list-versions" queries npm for Actual releases; installed versions are marked. Use --pre to include prereleases.
- When --domain is set on "instance add" or via "instance set-domain", a per-instance Nginx vhost
  /etc/nginx/sites-available/actual-<NAME>.conf is created/updated (enabled via sites-enabled symlink).
  TLS uses TurnKey’s system certs; automatic issuance (e.g., Let's Encrypt) is out of scope.
- This file is installed to /usr/share/tkl-actual-bootstrap/docs/README.actualctl.txt by "bootstrap.sh --update-install".
