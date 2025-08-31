<<<<<<< HEAD
# actualctl — Documentation (v0.21.0)
=======
# actualctl — Documentation (v0.22.0)
>>>>>>> alpha

**Project:** tkl-actual-bootstrap  
**Author:** Ken Robinson (<ken@turnkeylinux.org>)  
**License:** GPL-3.0-or-later — see [LICENSE](../LICENSE)  
**Source:** https://github.com/DocCyblade/tkl-actual-bootstrap

**Latest changes:** See root `CHANGELOG.md` → `scripts/actualctl`.

## Summary
`actualctl` wraps common operational tasks for multi-instance Actual deployments.

It reads defaults from `/etc/actual-budget/env` (notably `BUDGET_DOMAIN`).

## Commands & Examples

### Service controls
```
actualctl <INSTANCE> <logs|status|start|stop|restart>
```
Examples:
```
actualctl production status
actualctl test logs
actualctl development restart
```

### Reset admin password (per instance)
```
actualctl reset-password <INSTANCE>
```

### Interactive shell in the app directory (as budget-server)
```
actualctl shell <INSTANCE>
```

### Version management
```
actualctl fetch <VERSION>                # e.g., v25.9.2
actualctl switch <production|test|development> <VERSION>
```
Examples:
```
actualctl fetch v25.9.2
actualctl switch development v25.9.2
```

### Backup & restore
```
actualctl backup <INSTANCE>
actualctl restore <INSTANCE> <TARBALL>
```
Examples:
```
actualctl backup production
actualctl restore production /srv/backups/production-20250101-120000.tgz
```

### Prune backups
```
actualctl prune-backups <INSTANCE> --keep N
```
Example:
```
actualctl prune-backups production --keep 10
```

### Environment inspection
```
actualctl env <INSTANCE>
```
Shows data dir, link target, port, and paths.

### Sanity checks
```
actualctl check
```
Checks core binaries, service user, symlinks, services, ports, TLS files, and `nginx -t`.

### Verify a version (safe preflight)
```
actualctl verify <VERSION> [--keep]
```
- Installs to `/srv/app/_verify/<VERSION>`
- Runs `actual-server --version`
- Deletes temp install unless `--keep` is provided

### Create / remove instances
```
actualctl instance add <NAME> --link <production|test|development> [--fqdn HOST] [--port N] [--copy-from SRC] [--no-nginx] [--yes]
actualctl instance rm  <NAME> [--keep-data] [--yes]
```
Examples:
```
actualctl instance add personal --link production --fqdn personal-budgetapp.example.com --copy-from production --yes
actualctl instance rm personal --keep-data --yes
```

## Notes
- All npm operations run as the `budget-server` user with its own HOME and cache to avoid permission issues under `/srv`.
- Ports: by default choose next free ≥5000 (reserving 5006 for development unless explicitly requested).
