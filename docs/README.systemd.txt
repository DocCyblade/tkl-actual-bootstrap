Systemd units  (v0.23.2)
========================

Template (in repo):
  systemd/budgetapp.service.tpl

Rendered units (on host):
  /etc/systemd/system/<instance>-budgetapp.service

Key behaviors:
- WorkingDirectory: /srv/app/<instance>  (symlink -> /srv/app/vX.Y.Z)
- Environment: ACTUAL_DATA_DIR=/srv/<instance>/data
- Graceful stop: KillSignal=SIGINT, TimeoutStopSec=15
- Conservative hardening: NoNewPrivileges, PrivateTmp, ProtectSystem=full, etc.

Tip:
- If you harden further, consider ReadWritePaths=/srv/<instance>/data
