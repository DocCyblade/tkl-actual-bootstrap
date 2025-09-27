Systemd units
========================

Template (in repo):
  systemd/budgetapp.service.tpl

Rendered units (on host):
  /etc/systemd/system/<instance>-budgetapp.service

Lifecycle
---------
- Units are rendered by bootstrap and enabled/started automatically.
- When bootstrap updates units, it runs `systemctl daemon-reload` for you.
- Manual refresh after editing a unit:
  systemctl daemon-reload && systemctl restart <instance>-budgetapp

Key behaviors:
- WorkingDirectory: /srv/app/<instance>  (symlink -> /srv/app/vX.Y.Z)
- Environment: ACTUAL_DATA_DIR=/srv/<instance>/data
- Graceful stop: KillSignal=SIGINT, TimeoutStopSec=15
- Conservative hardening: NoNewPrivileges, PrivateTmp, ProtectSystem=full, etc.
 - User/Group: budget-server


Manage & logs
-------------
- Check status:   systemctl status <instance>-budgetapp
- Restart:        systemctl restart <instance>-budgetapp
- With CLI:       actualctl service <instance> status|restart
- Tail logs:      actualctl logs <instance> 100

Troubleshooting
---------------
- After changing a unit by hand: systemctl daemon-reload
- View journal directly: journalctl -u <instance>-budgetapp -n 200 -f
- If service won’t start, verify ACTUAL_DATA_DIR exists and points to /srv/<instance>/data
- Use: actualctl doctor   (checks services, ports, nginx -t, upstream)
