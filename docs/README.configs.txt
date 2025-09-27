Configs
==================

Template:
  configs/config.json.tpl

Rendered to:
  /srv/<instance>/data/config.json

Template token:
  __PORT__  Replaced with the instance port (e.g., 5000 / 5001 / 5006)

Notes:
  - hostname is fixed to 127.0.0.1 (bind loopback; safe behind Nginx)

Example render:
  For test instance on port 5000:

  {
    "port": 5000,
    "hostname": "127.0.0.1"
  }

Note:
  Pre-rendered per-instance configs are no longer tracked; bootstrap seeds from the template.

Change management:
  - Use: actualctl instance set-port <NAME> <PORT>
    This updates /srv/<NAME>/data/config.json and restarts the service safely.
