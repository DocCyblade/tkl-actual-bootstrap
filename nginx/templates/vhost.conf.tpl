# Licensed under GPL-3.0-or-later — see LICENSE
# TEMPLATE ONLY — bootstrap generates real vhosts with your domain
# {{HOST}} → 127.0.0.1:{{PORT}}
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

  client_max_body_size 50M;

  # Edge-only health check
  location = /healthz {
    access_log off;
    add_header Content-Type text/plain;
    return 200 'ok';
  }

  # Upstream health check
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

  location / {
    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade           $http_upgrade;
    proxy_set_header Connection        "upgrade";
    proxy_pass http://127.0.0.1:{{PORT}};
  }
}