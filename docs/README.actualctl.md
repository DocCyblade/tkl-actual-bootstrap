# README — scripts/actualctl (v0.23.1)

Helper to manage versions, instances, and backups for Actual Sync Server.

## Quick usage
```
actualctl <command> [args]
```

## Commands
- `help` — full help
- `list` — instances and symlink targets
- `check` — basic health checks
- `env [INSTANCE]` — show ACTUAL_DATA_DIR, config, link target
- `health [INSTANCE]` — check Nginx upstream and backend for one or all instances
- `doctor` — full system check (services, ports, nginx -t, upstream)

### Version & app
- `fetch <vX.Y.Z>` : install version to `/srv/app/<ver>`
- `switch <INSTANCE> <vX.Y.Z>` : relink and restart
- `verify <vX.Y.Z>` : temp install + presence check of module

### Backups
- `backup <INSTANCE> [note]` -> `/srv/backups/<instance>-<ts>[-note].tgz`
- `restore <INSTANCE> <tgz>` : stop, backup current, restore, chown, start
- `prune-backups [--keep N]` : keep N newest per instance

### Instances
- `instance add <NAME> <ver|development|test|production> [--from SRC] [--port PORT]`  
  Creates `/srv/<NAME>/data`, optional copy from `SRC`, links `/srv/app/<NAME>` to target.  
  If `--port` is omitted, the next free port is auto-selected (>= 5002).
- `instance rm  <NAME> [--purge]`
- `instance set-port <NAME> <PORT>`  
  Updates `/srv/<NAME>/data/config.json` with the new port and restarts the service.

### Services
- `service <INSTANCE> start|stop|restart|status`
- `logs <INSTANCE> [lines]`

## Notes
- `list` prints only version **directories** found under `/srv/app` (e.g., `v25.7.1`), not their contents.
- Run as root for commands that change the system.
- Units call `./node_modules/.bin/actual-server`.
