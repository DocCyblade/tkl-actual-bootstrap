Configs  (v0.23.2)
==================

Template:
  configs/config.json.tpl

Rendered to:
  /srv/<instance>/data/config.json

Template fields:
  port      Instance port (e.g., 5000 / 5001 / 5006)
  hostname  Defaults to 127.0.0.1 (bind loopback; safe behind Nginx)

Note:
  Pre-rendered per-instance configs are no longer tracked; bootstrap seeds from the template.
