# SPDX-License-Identifier: GPL-3.0-or-later
# tkl-actual-bootstrap : nginx/templates/vhost.conf.tpl
# Version: v0.23.2
#
# Template variables (rendered by bootstrap):
#   {{HOST}}  -> FQDN for this instance (e.g., production-budgetapp.example.com)
#   {{PORT}}  -> upstream backend port for this instance (e.g., 5001)
#
# TurnKey Linux default TLS file locations:
#   /etc/ssl/private/cert.pem
#   /etc/ssl/private/cert.key
#
# Notes:
#  - Includes two health endpoints:
#      /healthz            -> static 200 "ok" (nginx only)
#      /health/upstream    -> proxies to the backend (expects 200/404)
#  - WebSocket upgrade is enabled in the main location.
#  - Keep client_max_body_size modest for attachment uploads.

server {
    listen 80;
    listen [::]:80;
    server_name {{HOST}};
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name {{HOST}};

    ssl_certificate     /etc/ssl/private/cert.pem;
    ssl_certificate_key /etc/ssl/private/cert.key;

    # Optional: basic HSTS (6 months). Comment out if not desired.
    add_header Strict-Transport-Security "max-age=15552000" always;

    client_max_body_size 50m;

    # Lightweight nginx-only health endpoint
    location = /healthz {
        access_log off;
        default_type text/plain;
        return 200 "ok";
    }

    # Upstream health: short timeouts, pass-through to backend root
    location = /health/upstream {
        access_log off;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 2s;
        proxy_read_timeout 2s;
        proxy_send_timeout 2s;
        proxy_pass http://127.0.0.1:{{PORT}}/;
    }

    # Main app proxy (supports WebSockets)
    location / {
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        "upgrade";
        proxy_buffering off;
        proxy_pass http://127.0.0.1:{{PORT}};
    }
}