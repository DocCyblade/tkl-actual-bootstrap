Nginx vhosts
=======================

Template:
  nginx/templates/vhost.conf.tpl

TLS paths (TurnKey defaults):
  /etc/ssl/private/cert.pem
  /etc/ssl/private/cert.key

Health:
  /healthz         -> static nginx-only 200
  /health/upstream -> proxies to backend root (expect 200/404)

CLI checks:
  actualctl health [INSTANCE]
  actualctl doctor            (runs nginx -t among other checks)
  actualctl doctor --fix      (also installs/refreshes package VERSION manifest)

WebSockets:
  Upgrade headers included on "/"

HSTS:
  Optional header (comment out if undesired)

Rendered by actualctl (via `instance add` / `set-domain`):
  /etc/nginx/sites-available/actual-<NAME>.conf
  /etc/nginx/sites-enabled/actual-<NAME>.conf (symlink)
  /etc/actual-budget/env (BUDGET_DOMAIN=example.com)

Default hostnames:
  development-budgetapp.<domain>
  test-budgetapp.<domain>
  production-budgetapp.<domain>

Validate:
  nginx -t && systemctl reload nginx
