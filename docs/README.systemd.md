# README — systemd units (v0.23.1)

Each instance runs under a systemd unit named `<instance>-budgetapp.service`.

Key fields:
- `User=budget-server`
- `WorkingDirectory=/srv/app/<instance>` (symlink to `/srv/app/vX.Y.Z`)
- `Environment=ACTUAL_DATA_DIR=/srv/<instance>/data`
- `ExecStart=./node_modules/.bin/actual-server`
- `Restart=on-failure`

## Commands
```bash
systemctl status production-budgetapp.service
journalctl -u production-budgetapp.service -n 200 --no-pager
systemctl restart production-budgetapp.service
```

## Overrides
Create `/etc/systemd/system/<instance>-budgetapp.service.d/override.conf` if you need custom env or limits, then:
```bash
systemctl daemon-reload
systemctl restart <instance>-budgetapp.service
```
