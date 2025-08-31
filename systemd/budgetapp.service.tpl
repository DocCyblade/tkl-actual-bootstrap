# SPDX-License-Identifier: GPL-3.0-or-later
# tkl-actual-bootstrap : systemd/budgetapp.service.tpl
# Version: v0.23.2
#
# Instance unit for Actual Sync Server.
# Rendered as: /etc/systemd/system/{{INSTANCE}}-budgetapp.service
#
# Conventions:
#   WorkingDirectory = /srv/app/{{INSTANCE}}      (symlink -> /srv/app/vX.Y.Z)
#   ACTUAL_DATA_DIR  = /srv/{{INSTANCE}}/data     (config.json lives here)
#   Service user     = budget-server              (no sudo assumptions)
#
# Notes:
#   - Conservative hardening enabled (safe for Node).
#   - Journald captures logs (use: journalctl -u {{INSTANCE}}-budgetapp -n 200).
#   - If you need nginx up first, add 'After=nginx.service'.

[Unit]
Description=Actual Sync Server ({{INSTANCE}})
After=network.target
# After=nginx.service

[Service]
Type=simple

# Runtime identity (matches ownership of /srv/{{INSTANCE}})
User=budget-server
Group=budget-server

# App is installed locally via instance link:
#   /srv/app/{{INSTANCE}} -> /srv/app/vX.Y.Z
WorkingDirectory=/srv/app/{{INSTANCE}}

# Environment for the app:
Environment=NODE_ENV=production
Environment=ACTUAL_DATA_DIR=/srv/{{INSTANCE}}/data

# Launch Actual from local node_modules
ExecStart=/usr/bin/env bash -lc './node_modules/.bin/actual-server'

# Restart policy
Restart=on-failure
RestartSec=2

# Graceful shutdown (Node handles SIGINT nicely)
KillSignal=SIGINT
TimeoutStopSec=15

# -------------------------
# Conservative hardening
# -------------------------
NoNewPrivileges=yes
PrivateTmp=yes
ProtectControlGroups=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectSystem=full
RestrictSUIDSGID=yes
RestrictRealtime=yes
LockPersonality=yes
CapabilityBoundingSet=
AmbientCapabilities=
SystemCallArchitectures=native
# RestrictNamespaces=yes            # enable if your Node build does not need namespaces
# ReadWritePaths=/srv/{{INSTANCE}}/data

[Install]
WantedBy=multi-user.target