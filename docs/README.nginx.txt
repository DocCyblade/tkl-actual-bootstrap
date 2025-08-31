Nginx vhosts  (v0.23.2)
=======================

Template:
  nginx/templates/vhost.conf.tpl

TLS paths (TurnKey defaults):
  /etc/ssl/private/cert.pem
  /etc/ssl/private/cert.key

Health:
  /healthz         -> static nginx-only 200
  /health/upstream -> proxies to backend root (expect 200/404)

WebSockets:
  Upgrade headers included on "/"

HSTS:
  Optional header (comment out if undesired)

Rendered by bootstrap:
  /etc/nginx/sites-available/<instance>-budgetapp.conf
  /etc/nginx/sites-enabled/<instance>-budgetapp.conf (symlink)
  /etc/actual-budget/env (BUDGET_DOMAIN=example.com)

Validate:
  nginx -t && systemctl reload nginx
