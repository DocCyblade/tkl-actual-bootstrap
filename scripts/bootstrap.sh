#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2025 Ken Robinson <ken@turnkeylinux.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# ------------------------------------------------------------------------------
# bootstrap.sh — One-shot, idempotent installer for Actual Budget multi-instance
<<<<<<< HEAD
# Version: v0.21.0
=======
# Version: v0.22.0
>>>>>>> alpha
#
# What's changed since v0.20.4:
#   - Docs-only: removed personal references from public docs; no functional changes.
#   - Docs-only: added Migration from pre–v0.20 and Common port map to top-level README; no functional changes.
# Full history: see ./CHANGELOG.md (section: scripts/bootstrap.sh)
# Script README: ./docs/README.bootstrap.md
# ------------------------------------------------------------------------------
set -Eeuo pipefail
<<<<<<< HEAD
=======
if [[ $# -eq 0 ]]; then banner 2>/dev/null || true; (print_usage || usage) 2>/dev/null || echo 'Run with --help'; exit 0; fi


banner() {
  cat <<'BANNER'
┌──────────────────────────────────────────────────────────────────────┐
│ tkl-actual-bootstrap : bootstrap.sh  v0.22.0                            │
│ Manage/Bootstrap Actual Sync Server on Turnkey Linux (GPL-3.0-or-later) │
│ Author: Ken Robinson <ken@turnkeylinux.org>                          │
│ Source: https://github.com/DocCyblade/tkl-actual-bootstrap           │
│ Hint:   ./scripts/bootstrap.sh --help                                             │
└──────────────────────────────────────────────────────────────────────┘
BANNER
}

>>>>>>> alpha

# Colors
if [[ -t 1 ]]; then
  c_bold=$(tput bold); c_reset=$(tput sgr0)
  c_info=$(tput setaf 4); c_ok=$(tput setaf 2); c_warn=$(tput setaf 3); c_err=$(tput setaf 1)
else
  c_bold=""; c_reset=""; c_info=""; c_ok=""; c_warn=""; c_err=""
fi
info(){ echo -e "${c_info}[INFO]${c_reset} $*"; }
ok(){ echo -e "${c_ok}[ OK ]${c_reset} $*"; }
warn(){ echo -e "${c_warn}[WARN]${c_reset} $*"; }
err(){ echo -e "${c_err}[ERR ]${c_reset} $*" >&2; }
trap 'err "A fatal error occurred. See logs above."; exit 1' ERR

VERSION="${VERSION:-v25.8.0}"
CERT_CRT="${CERT_CRT:-/etc/ssl/private/cert.pem}"
CERT_KEY="${CERT_KEY:-/etc/ssl/private/cert.key}"
SERVICE_USER="budget-server"
SERVICE_HOME="/home/$SERVICE_USER"
NPM_CACHE="$SERVICE_HOME/.npm"
SRV="/srv"; APPS="$SRV/app"; BACKUPS="$SRV/backups"; DRY_RUN=0; ASSUME_YES=0
INSTANCES=("development" "test" "production")
declare -A PORTS=( ["development"]=5006 ["test"]=5000 ["production"]=5001 )

AB_DIR="/etc/actual-budget"; AB_ENV="$AB_DIR/env"

# Args
DOMAIN_ARG=""
while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --domain) DOMAIN_ARG="$2"; shift 2 ;;
    -h|--help)
      cat <<USAGE
Usage: ./scripts/bootstrap.sh [--yes] [--dry-run] [--domain example.com]

This will:
  - Create service user 'budget-server' with home under /home
  - Install @actual-app/sync-server into /srv/app/<VERSION>
  - Create symlinks: /srv/app/production|development|test
  - Create /srv/<instance>/data with config.json
  - Install systemd units, enable and start services
  - Generate Nginx vhosts for your domain (with health checks)

See ./docs/README.bootstrap.md for details.
USAGE
      exit 0
      ;;
    *) shift ;;
  esac
done

require_root(){ if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then err "Run as root"; exit 1; fi }
require_cmd(){ for c in node npm systemctl nginx install ln id cmp; do command -v "$c" >/dev/null 2>&1 || { err "Missing command: $c"; exit 1; }; done }
run(){ if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN: $*"; else eval "$@"; fi }
run_as_budget(){
  local cmd="$*"
  if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN: [budget-server] $cmd"; return 0; fi
  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$SERVICE_USER" -- env HOME="$SERVICE_HOME" NPM_CONFIG_CACHE="$NPM_CACHE" PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin" bash -lc "$cmd"
  else
    su -s /bin/bash - "$SERVICE_USER" -c "HOME='$SERVICE_HOME' NPM_CONFIG_CACHE='$NPM_CACHE' PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin' bash -lc \"$cmd\""
  fi
}

ensure_user(){
  if id "$SERVICE_USER" >/dev/null 2>&1; then
    ok "User '$SERVICE_USER' present"
    current_home="$(getent passwd "$SERVICE_USER" | cut -d: -f6 || true)"
    if [[ -n "$current_home" && "$current_home" != "$SERVICE_HOME" ]]; then
      info "Adjusting home for $SERVICE_USER: $current_home -> $SERVICE_HOME"
      run "usermod -d '$SERVICE_HOME' -m '$SERVICE_USER'"
    fi
  else
    info "Creating user '$SERVICE_USER' with home $SERVICE_HOME"
    run "useradd --system --create-home --home-dir '$SERVICE_HOME' --shell /bin/bash '$SERVICE_USER'"
  fi
  [[ -d "$SERVICE_HOME" ]] || run "mkdir -p '$SERVICE_HOME'"
  run "mkdir -p '$NPM_CACHE'"
  run "chown -R '$SERVICE_USER:$SERVICE_USER' '$SERVICE_HOME'"
}

ensure_dir(){ local d="$1"; [[ -d "$d" ]] && ok "Dir exists: $d" || { info "Creating dir: $d"; run "mkdir -p '$d'"; }; }
ensure_owner(){ local p="$1"; run "chown -R '$SERVICE_USER:$SERVICE_USER' '$p'"; }
ensure_symlink(){ local target="$1" link="$2"; if [[ -L "$link" && "$(readlink -f "$link")" == "$(readlink -f "$target")" ]]; then ok "Symlink OK: $link -> $target"; else info "Linking: $link -> $target"; run "ln -sfn '$target' '$link'"; fi }

install_version(){
  local ver="${1:-${VERSION:-v25.8.0}}"; local vdir="$APPS/$ver"
  ensure_dir "$vdir"; ensure_owner "$vdir"
  if [[ -x "$vdir/node_modules/.bin/actual-server" ]]; then ok "Version already installed: $ver"; return; fi
  info "Installing @actual-app/sync-server@$ver into $vdir"
  local ver_trim="${ver#v}"
  run_as_budget "cd '$vdir' && npm init -y && npm install --omit=dev --no-audit --no-fund @actual-app/sync-server@${ver_trim}"
}

copy_if_changed(){ local src="$1" dest="$2" mode="${3:-0644}"; if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then ok "Up-to-date: $dest"; else info "Installing: $dest"; if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN: install -m $mode '$src' '$dest'"; else install -m "$mode" "$src" "$dest"; fi; fi }

make_nginx_site(){
  local inst="$1" host="$2" port="$3"
  local file="/etc/nginx/sites-available/${inst}-budgetapp.conf"
  run "bash -lc 'cat > \"$file\" <<NGINX
# ${host} → 127.0.0.1:${port}
server {
  listen 80;
  listen [::]:80;
  server_name ${host};
  return 301 https://\$host\$request_uri;
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name ${host};

  ssl_certificate     ${CERT_CRT};
  ssl_certificate_key ${CERT_KEY};

  client_max_body_size 50M;

  location = /healthz {
    access_log off;
    add_header Content-Type text/plain;
    return 200 \"ok\";
  }

  location = /health/upstream {
    access_log off;
    proxy_http_version 1.1;
    proxy_set_header Host              \$host;
    proxy_set_header X-Real-IP         \$remote_addr;
    proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_connect_timeout 2s;
    proxy_read_timeout 2s;
    proxy_send_timeout 2s;
    proxy_pass http://127.0.0.1:${port}/;
  }

  location / {
    proxy_http_version 1.1;
    proxy_set_header Host              \$host;
    proxy_set_header X-Real-IP         \$remote_addr;
    proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Upgrade           \$http_upgrade;
    proxy_set_header Connection        \"upgrade\";
    proxy_pass http://127.0.0.1:${port};
  }
}
NGINX'"
  run "ln -sfn \"$file\" \"/etc/nginx/sites-enabled/${inst}-budgetapp.conf\""
}

prompt_domain(){
  local dom=""
  if [[ -n "$DOMAIN_ARG" ]]; then
    dom="$DOMAIN_ARG"
  elif [[ -f "$AB_ENV" ]]; then
    # shellcheck disable=SC1090
    . "$AB_ENV"
    dom="$BUDGET_DOMAIN"
  fi
  if [[ -z "$dom" && -t 0 && $ASSUME_YES -eq 0 ]]; then
    echo ""
    echo "${c_bold}Enter your domain (used for vhosts), e.g., example.com${c_reset}"
    read -r -p "Domain: " dom || true
  fi
  [[ -n "$dom" ]] || dom="example.com"
  echo "$dom"
}

main(){
  require_root; require_cmd

  DOMAIN="$(prompt_domain)"
  info "Using domain: $DOMAIN"
  [[ -d "/etc/actual-budget" ]] || run "mkdir -p /etc/actual-budget"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY-RUN: write $AB_ENV with BUDGET_DOMAIN=$DOMAIN"
  else
    echo "BUDGET_DOMAIN=$DOMAIN" > "$AB_ENV"
  fi

  info "Ensuring layout"
  ensure_user
  ensure_dir "$APPS"
  ensure_dir "$BACKUPS"
  for i in "${INSTANCES[@]}"; do ensure_dir "$SRV/$i/data"; ensure_owner "$SRV/$i"; done

  install_version "$VERSION"

  info "Ensuring symlinks"
  ensure_symlink "$APPS/$VERSION" "$APPS/production"
  ensure_symlink "$APPS/$VERSION" "$APPS/development"
  ensure_symlink "$APPS/$VERSION" "$APPS/test"

  info "Copying configs"
  BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  copy_if_changed "$BUNDLE_DIR/configs/development/config.json" "$SRV/development/data/config.json"
  copy_if_changed "$BUNDLE_DIR/configs/test/config.json" "$SRV/test/data/config.json"
  copy_if_changed "$BUNDLE_DIR/configs/production/config.json" "$SRV/production/data/config.json"
  run "chown '$SERVICE_USER:$SERVICE_USER' '$SRV/development/data/config.json' '$SRV/test/data/config.json' '$SRV/production/data/config.json'"

  info "Installing systemd units"
  run "mkdir -p /etc/systemd/system"
  copy_if_changed "$BUNDLE_DIR/systemd/development-budgetapp.service" "/etc/systemd/system/development-budgetapp.service"
  copy_if_changed "$BUNDLE_DIR/systemd/test-budgetapp.service" "/etc/systemd/system/test-budgetapp.service"
  copy_if_changed "$BUNDLE_DIR/systemd/production-budgetapp.service" "/etc/systemd/system/production-budgetapp.service"
  info "Reloading systemd"; run "systemctl daemon-reload"
  info "Enabling & starting services"; run "systemctl enable --now development-budgetapp.service test-budgetapp.service production-budgetapp.service"

  info "Installing Nginx vhosts"
  run "mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled"
  if [[ ! -f "$CERT_CRT" || ! -f "$CERT_KEY" ]]; then warn "TLS cert/key not present ($CERT_CRT / $CERT_KEY). HTTPS will fail until provided."; fi
  make_nginx_site "development" "development-budgetapp.${DOMAIN}" "${PORTS[development]}"
  make_nginx_site "test"        "test-budgetapp.${DOMAIN}"        "${PORTS[test]}"
  make_nginx_site "production"  "production-budgetapp.${DOMAIN}"  "${PORTS[production]}"
  info "Testing Nginx config"; run "nginx -t"
  info "Reloading Nginx"; run "systemctl reload nginx || systemctl restart nginx"

  ok "Bootstrap core complete."
  echo ""
  read -r -p "Run initial password resets now? (y/N) " do_pw || true
  if [[ "$do_pw" =~ ^[Yy]$ ]]; then
    for i in "${INSTANCES[@]}"; do
      link_dir="$APPS/$i"; bin="$link_dir/node_modules/.bin/actual-server"
      [[ -x "$bin" ]] && run_as_budget "ACTUAL_DATA_DIR='$SRV/$i/data' '$bin' --reset-password" || true
    done
  fi

  cat <<NEXT

Next steps:
- Access:
    https://development-budgetapp.${DOMAIN}
    https://test-budgetapp.${DOMAIN}
    https://production-budgetapp.${DOMAIN}

- Daily ops:
    install -m 0755 scripts/actualctl /usr/local/bin/actualctl
    actualctl check
    actualctl env production

Re-run ./scripts/bootstrap.sh anytime; it's safe and idempotent.
NEXT
}

<<<<<<< HEAD
main "$@"
=======
main "$@"
# --- Nginx template renderer (safe) ---
render_nginx_site() {
  local inst="$1" host="$2" port="$3"
  host="${host//$'\t'/}"; host="${host//$'\r'/}"; host="${host//$'\n'/}"; host="${host// /}"
  local BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local tpl="$BUNDLE_DIR/nginx/templates/vhost.conf.tpl"
  local out="/etc/nginx/sites-available/${inst}-budgetapp.conf"
  if [[ ! -f "$tpl" ]]; then
    echo "[ERR ] Missing Nginx template: $tpl" >&2
    return 1
  fi
  sed -e "s|{{HOST}}|${host}|g" -e "s|{{PORT}}|${port}|g" "$tpl" > "$out"
  ln -sfn "$out" "/etc/nginx/sites-enabled/${inst}-budgetapp.conf"
}
make_nginx_site(){ render_nginx_site "$@"; }
>>>>>>> alpha
