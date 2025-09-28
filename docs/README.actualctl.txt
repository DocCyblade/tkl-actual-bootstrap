scripts/actualctl — README  (v0.25.0)
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

Version / app mgmt
------------------
fetch <vX.Y.Z>       Install @actual-app/sync-server@<ver> into /srv/app/<ver>
switch <INST> <VER>  /srv/app/<INST> -> /srv/app/<VER>, then restart service
verify <vX.Y.Z>      Install to a temp dir, smoke-check presence, cleanup (no changes to live instances)

Backups
-------
backup <INST> [note] Archive user-data into /srv/backups
restore <INST> <tgz> Stop, backup current, restore, chown, start
prune-backups [--keep N]  Keep N most-recent per instance (default 7)

Instances
---------
instance add <NAME> <vX.Y.Z|development|test|production> [--from SRC] [--port P]
  Creates /srv/<NAME>/data, optional copy from SRC, links /srv/app/<NAME> to target version,
  writes unit, starts service. If --port omitted, picks next free port.

instance rm <NAME> [--purge]
  Stop/disable unit, remove unit, optionally delete /srv/<NAME>

instance set-port <NAME> <PORT>
  Update port in config.json and restart

Services
--------
service <INST> start|stop|restart|status
logs <INST> [lines]

Examples
--------
actualctl list
actualctl fetch v25.7.1
actualctl switch production v25.7.1
actualctl backup production "pre-upgrade"
actualctl restore production /srv/backups/production-20250101-120000-pre-upgrade.tgz
actualctl instance add staging v25.7.1 --from production --port 5002
actualctl instance set-port staging 5003
actualctl health production
actualctl doctor
actualctl doctor --fix
actualctl env
actualctl env production
actualctl verify v25.7.1
actualctl service production restart
actualctl logs production 200
actualctl prune-backups --keep 10

Notes
-----
- "actualctl --version" prints: actualctl <Script-Version> (package <PKG_VERSION>).
- "doctor --fix" installs/refreshes /usr/share/tkl-actual-bootstrap/VERSION.
- JSON parsing prefers jq when available; awk-based fallback is used otherwise.
- If rsync is not installed, instance data copy falls back to "cp -a" (no deletion of extraneous files).
- This file is installed to /usr/share/tkl-actual-bootstrap/docs/README.actualctl.txt by "bootstrap.sh --update-install".
