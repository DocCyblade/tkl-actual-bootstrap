# README — nginx/templates (vhosts) (v0.23.1)

This directory contains the Nginx virtual host template used by the bootstrap.

- Template file: `nginx/templates/vhost.conf.tpl`
- Placeholders:
  - `{{HOST}}` — the FQDN (e.g., `test-budgetapp.example.com`)
  - `{{PORT}}` — upstream Actual server port (e.g., `5000`)

## What bootstrap renders
- A port-80 server block that redirects to HTTPS
- A port-443 server block with TLS:
  - `ssl_certificate     /etc/ssl/private/cert.pem`
  - `ssl_certificate_key /etc/ssl/private/cert.key`
- Health probes:
  - `/healthz` — static `200 ok`
  - `/health/upstream` — proxied to `http://127.0.0.1:{{PORT}}/`

## Enabling the site
Bootstrap writes to `/etc/nginx/sites-available/<instance>-budgetapp.conf` and links to `/etc/nginx/sites-enabled/…`, then runs `nginx -t` and reloads if clean.

Manual steps:
```bash
nginx -t && systemctl reload nginx
```

## Hardening (optional)
- Add HSTS once TLS is confirmed:
  ```nginx
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  ```
- Tune proxy timeouts and body size in the template if needed.
