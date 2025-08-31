#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# tkl-actual-bootstrap : bootstrap.sh
# Version: v0.22.1
# Bootstrap for running Actual Sync Server (multi-instance) on TurnKey Linux.
# - Creates/uses system user: budget-server (home: /home/budget-server, shell: /bin/bash)
# - Installs @actual-app/sync-server locally: /srv/app/vX.Y.Z
# - Symlinks: /srv/app/development|test|production -> /srv/app/vX.Y.Z
# - Instance data: /srv/<instance>/data (config.json lives here)
# - Systemd units: <instance>-budgetapp.service (ACTUAL_DATA_DIR points to /srv/<instance>/data)
# - Nginx TLS: /etc/ssl/private/cert.pem and /etc/ssl/private/cert.key
# NOTES:
# * Run as root. Do NOT use sudo.
# * Idempotent: safe to re-run; only updates when needed.

set -Eeuo pipefail

#######################################
# Banner
#######################################
banner() {
  cat <<'BANNER'
┌──────────────────────────────────────────────────────────────────────┐
│ tkl-actual-bootstrap : bootstrap.sh  v0.22.1                         │
│ Bootstrap for running Actual Sync Server on Turnkey Linux            │
│ License: GPL-3.0-or-later                                            │
│ Author: Ken Robinson <ken@turnkeylinux.org>                          │
│ Source: https://github.com/DocCyblade/tkl-actual-bootstrap           │
│ Hint:   ./scripts/bootstrap.sh --help                                 │
└──────────────────────────────────────────────────────────────────────┘
BANNER
}

#######################################
# Usage (quick) and Help (full)
#######################################
usage_quick() {
  cat <<'HELP'
Usage: ./scripts/bootstrap.sh [--yes|-y] [--dry-run] [--domain <name>] [--version vX.Y.Z] [--install-ctl] [--ctl-path /path/actualctl]
Hint : ./scripts/bootstrap.sh --help   # for full documentation
HELP
}

print_usage() {
  cat <<'HELP'
Usage:
  ./scripts/bootstrap.sh
    [--yes|-y]
    [--dry-run]
    [--domain <name>]
    [--version vX.Y.Z]
    [--install-ctl]
    [--ctl-path /usr/local/sbin/actualctl]
    [--help]

Options:
  --yes, -y            Non-interactive mode (assume “Yes” to prompts)
  --dry-run            Preview actions without changing the system
  --domain NAME        Your base domain (e.g., example.com). If omitted:
                         - read /etc/actual-budget/env (BUDGET_DOMAIN=…)
                         - else prompt (interactive mode)
  --version VER        Actual sync-server npm version (default: v25.8.0)
  --install-ctl        Install scripts/actualctl into PATH (root-only)
  --ctl-path PATH      Destination for actualctl (default: /usr/local/sbin/actualctl)
  --help               Show this help and exit

What gets created/updated:
  User:
    - system user 'budget-server' (home=/home/budget-server, shell=/bin/bash)
  App:
    - /srv/app/vX.Y.Z (installed as 'budget-server')
    - symlinks: /srv/app/development, /srv/app/test, /srv/app/production -> /srv/app/vX.Y.Z
  Data:
    - /srv/development/data, /srv/test/data, /srv/production/data
    - config.json in each data dir (port + hostname)
  Services:
    - systemd units: development-budgetapp.service, test-budgetapp.service, production-budgetapp.service
      (ExecStart uses ./node_modules/.bin/actual-server)
  Nginx:
    - vhosts from template nginx/templates/vhost.conf.tpl (or built-in fallback)
    - TLS paths: /etc/ssl/private/cert.pem and /etc/ssl/private/cert.key
    - health endpoints: /healthz (static) and /health/upstream (proxied)

Ports:
  development: 5006
  test:        5000
  production:  5001

Examples:
  # preview only
  ./scripts/bootstrap.sh --dry-run

  # run non-interactively with explicit domain and version
  ./scripts/bootstrap.sh --yes --domain example.com --version v25.8.0

  # run interactively and let the script prompt for domain (stores in /etc/actual-budget/env)
  ./scripts/bootstrap.sh --yes

  # also install the actualctl helper into PATH
  ./scripts/bootstrap.sh --yes --install-ctl --ctl-path /usr/local/sbin/actualctl
HELP
}

#######################################
# Early arg guard: no-args (quick) vs --help (full)
#######################################
if [[ $# -eq 0 ]]; then
  banner
  usage_quick
  exit 0
fi
for _arg in "$@"; do
  if [[ "$_arg" == "-h" || "$_arg" == "--help" ]]; then
    banner
    print_usage
    exit 0
  fi
done

#######################################
# Config defaults
#######################################
APP_USER="budget-server"
APP_GROUP="budget-server"
APP_SHELL="/bin/bash"
APP_HOME="/home/${APP_USER}"

BASE_APP="/srv/app"
BACKUPS="/srv/backups"
INSTANCES=(development test production)
declare -A PORTS=( ["development"]=5006 ["test"]=5000 ["production"]=5001 )

CERT_CRT="${CERT_CRT:-/etc/ssl/private/cert.pem}"
CERT_KEY="${CERT_KEY:-/etc/ssl/private/cert.key}"

VERSION="${VERSION:-v25.8.0}"

ENV_DIR="/etc/actual-budget"
ENV_FILE="${ENV_DIR}/env"

DRY_RUN=0
ASSUME_YES=0
BUDGET_DOMAIN=""

INSTALL_CTL=0
CTL_DST="/usr/local/sbin/actualctl"

#######################################
# Logging helpers
#######################################
log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }
run()  { [[ $DRY_RUN -eq 1 ]] && printf 'DRY-RUN: %s\n' "$*" || eval "$@"; }

copy_if_changed() {
  local src="$1"
  local dst="$2"
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    log "No change: ${dst}"
  else
    run "install -m 0644 \"$src\" \"$dst\""
  fi
}

#######################################
# Args parsing
#######################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=1; shift ;;
    -y|--yes)      ASSUME_YES=1; shift ;;
    --domain)      BUDGET_DOMAIN="${2:-}"; shift 2 ;;
    --version)     VERSION="${2:-}"; shift 2 ;;
    --install-ctl) INSTALL_CTL=1; shift ;;
    --ctl-path)    CTL_DST="${2:-/usr/local/sbin/actualctl}"; shift 2 ;;
    *)             err "Unknown arg: $1"; usage_quick; exit 2 ;;
  esac
done

#######################################
# Pre-flight checks
#######################################
require_root() { [[ $(id -u) -eq 0 ]] || die "Run as root (no sudo)."; }
require_cmd() {
  local miss=0
  for c in node npm systemctl nginx sed install ln mkdir chown; do
    command -v "$c" >/dev/null 2>&1 || { err "Missing command: $c"; miss=1; }
  done
  [[ $miss -eq 0 ]] || die "Install required tools and re-run."
}

#######################################
# Domain handling
#######################################
read_env_domain() {
  [[ -f "$ENV_FILE" ]] || return 1
  local line
  line="$(grep -E '^BUDGET_DOMAIN=' "$ENV_FILE" || true)"
  [[ -n "$line" ]] || return 1
  BUDGET_DOMAIN="${line#BUDGET_DOMAIN=}"
  BUDGET_DOMAIN="${BUDGET_DOMAIN%\"}"; BUDGET_DOMAIN="${BUDGET_DOMAIN#\"}"
  BUDGET_DOMAIN="${BUDGET_DOMAIN//[$'\t\r\n ']/}"
  [[ -n "$BUDGET_DOMAIN" ]]
}
write_env_domain() {
  run "mkdir -p \"$ENV_DIR\""
  local tmp
  tmp="$(mktemp)"
  printf 'BUDGET_DOMAIN=%s\n' "$BUDGET_DOMAIN" > "$tmp"
  copy_if_changed "$tmp" "$ENV_FILE"
  rm -f "$tmp"
}
prompt_domain_if_needed() {
  if [[ -z "$BUDGET_DOMAIN" ]]; then
    if read_env_domain; then
      log "Using domain from ${ENV_FILE}: ${BUDGET_DOMAIN}"
      return
    fi
    if [[ $ASSUME_YES -eq 1 ]]; then
      warn "No domain provided; defaulting to example.com"
      BUDGET_DOMAIN="example.com"
    else
      printf "Enter base domain (e.g., example.com): "
      read -r BUDGET_DOMAIN
      BUDGET_DOMAIN="${BUDGET_DOMAIN//[$'\t\r\n ']/}"
      [[ -n "$BUDGET_DOMAIN" ]] || die "No domain provided."
    fi
  fi
  write_env_domain
}

#######################################
# System user
#######################################
ensure_user() {
  if id "$APP_USER" >/dev/null 2>&1; then
    log "User exists: $APP_USER"
  else
    log "Creating user '$APP_USER' with home $APP_HOME"
    run "useradd --system --create-home --home-dir '$APP_HOME' --shell '$APP_SHELL' '$APP_USER'"
  fi
  run "mkdir -p '$APP_HOME/.npm'"
  run "chown -R '$APP_USER:$APP_GROUP' '$APP_HOME'"
}

#######################################
# Directories (do not chown /srv root)
#######################################
ensure_dirs() {
  log "Ensuring directories"
  run "mkdir -p '$BASE_APP' '$BACKUPS'"
  for inst in "${INSTANCES[@]}"; do
    run "mkdir -p '/srv/${inst}/data'"
    run "chown -R '$APP_USER:$APP_GROUP' '/srv/${inst}'"
  done
}

#######################################
# Install app version as budget-server
#######################################
install_version() {
  local ver="$1"
  local dest="${BASE_APP}/${ver}"
  log "Preparing app dir: ${dest}"
  run "mkdir -p '$dest'"
  run "chown -R '$APP_USER:$APP_GROUP' '$dest'"
  if [[ -f "${dest}/node_modules/@actual-app/sync-server/package.json" ]]; then
    log "Version present: ${ver} (skipping npm install)"
    return
  fi
  log "Installing @actual-app/sync-server@${ver} into ${dest}"
  if command -v runuser >/dev/null 2>&1; then
    run "runuser -u '$APP_USER' -- bash -lc 'cd \"$dest\" && { test -f package.json || npm init -y; } && npm config set fund false && npm config set audit false && npm install \"@actual-app/sync-server@${ver}\"'"
  else
    run "su -s /bin/bash - '$APP_USER' -c 'cd \"$dest\" && { test -f package.json || npm init -y; } && npm config set fund false && npm config set audit false && npm install \"@actual-app/sync-server@${ver}\"'"
  fi
}

#######################################
# Symlinks for development/test/production
#######################################
ensure_links() {
  local ver="$1"
  for link in "${INSTANCES[@]}"; do
    local target="${BASE_APP}/${ver}"
    local linkpath="${BASE_APP}/${link}"
    log "Linking: ${linkpath} -> ${target}"
    run "ln -sfn '$target' '$linkpath'"
  done
}

#######################################
# config.json for each instance
#######################################
write_config_for() {
  local inst="$1"
  local port="$2"
  local data="/srv/${inst}/data"
  local cfg="${data}/config.json"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp" <<JSON
{
  "port": ${port},
  "hostname": "127.0.0.1"
}
JSON
  copy_if_changed "$tmp" "$cfg"
  rm -f "$tmp"
  run "chown -R '$APP_USER:$APP_GROUP' '$data'"
}
ensure_configs() {
  for inst in "${INSTANCES[@]}"; do
    write_config_for "$inst" "${PORTS[$inst]}"
  done
}

#######################################
# systemd units
#######################################
unit_text() {
  local inst="$1"
  local linkdir="${BASE_APP}/${inst}"
  local datadir="/srv/${inst}/data"
  cat <<UNIT
[Unit]
Description=Actual Sync Server (${inst})
After=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${linkdir}
Environment=NODE_ENV=production
Environment=ACTUAL_DATA_DIR=${datadir}
ExecStart=/usr/bin/env bash -lc './node_modules/.bin/actual-server'
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
}
install_units() {
  local changed=0
  for inst in "${INSTANCES[@]}"; do
    local unit="/etc/systemd/system/${inst}-budgetapp.service"
    local tmp
    tmp="$(mktemp)"
    unit_text "$inst" > "$tmp"
    if [[ -f "$unit" ]] && cmp -s "$tmp" "$unit"; then
      log "No change: ${unit}"
      rm -f "$tmp"
    else
      log "Installing: ${unit}"
      run "install -m 0644 '$tmp' '$unit'"
      changed=1
    fi
  done
  if [[ $changed -eq 1 ]]; then
    log "Reloading systemd"
    run "systemctl daemon-reload"
  fi
  log "Enabling & starting services"
  for inst in "${INSTANCES[@]}"; do
    run "systemctl enable --now '${inst}-budgetapp.service'"
  done
}

#######################################
# Nginx templating
#######################################
default_vhost_template() {
  cat <<'TPL'
# TEMPLATE (fallback) — prefer nginx/templates/vhost.conf.tpl if available
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

  location = /healthz {
    access_log off;
    add_header Content-Type text/plain;
    return 200 'ok';
  }

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
TPL
}
render_nginx_site() {
  local inst="$1"
  local host="$2"
  local port="$3"
  host="${host//[$'\t\r\n ']/}"
  local bundle_dir
  bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local tpl="${bundle_dir}/nginx/templates/vhost.conf.tpl"
  local out="/etc/nginx/sites-available/${inst}-budgetapp.conf"
  local tmp
  tmp="$(mktemp)"
  if [[ -f "$tpl" ]]; then
    sed -e "s|{{HOST}}|${host}|g" -e "s|{{PORT}}|${port}|g" "$tpl" > "$tmp"
  else
    warn "Template not found at ${tpl}; using built-in fallback"
    default_vhost_template | sed -e "s|{{HOST}}|${host}|g" -e "s|{{PORT}}|${port}|g" > "$tmp"
  fi
  copy_if_changed "$tmp" "$out"
  rm -f "$tmp"
  run "ln -sfn '$out' '/etc/nginx/sites-enabled/${inst}-budgetapp.conf'"
}
install_nginx() {
  log "Installing Nginx vhosts"
  local dev_host="development-budgetapp.${BUDGET_DOMAIN}"
  local tst_host="test-budgetapp.${BUDGET_DOMAIN}"
  local prd_host="production-budgetapp.${BUDGET_DOMAIN}"
  render_nginx_site "development" "$dev_host" "${PORTS[development]}"
  render_nginx_site "test"        "$tst_host" "${PORTS[test]}"
  render_nginx_site "production"  "$prd_host" "${PORTS[production]}"
  log "Testing Nginx config"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf 'DRY-RUN: nginx -t\n'
  else
    if nginx -t; then
      run "systemctl reload nginx"
    else
      die "nginx -t failed"
    fi
  fi
}

#######################################
# Optional: install actualctl into PATH
#######################################
install_ctl_if_requested() {
  [[ $INSTALL_CTL -eq 1 ]] || return 0
  local script_dir src
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  src="${script_dir}/actualctl"
  if [[ ! -f "$src" ]]; then
    warn "actualctl not found at ${src}; skipping --install-ctl"
    return 0
  fi
  log "Installing actualctl to ${CTL_DST}"
  run "install -m 0755 \"$src\" \"$CTL_DST\""
}

#######################################
# Main
#######################################
main() {
  banner
  require_root
  require_cmd
  prompt_domain_if_needed

  log "Parameters"
  log "  VERSION       = ${VERSION}"
  log "  DOMAIN        = ${BUDGET_DOMAIN}"
  log "  DRY_RUN       = ${DRY_RUN}"
  log "  CERT_CRT      = ${CERT_CRT}"
  log "  CERT_KEY      = ${CERT_KEY}"
  log "  INSTALL_CTL   = ${INSTALL_CTL}"
  if [[ $INSTALL_CTL -eq 1 ]]; then
    log "  CTL_DST       = ${CTL_DST}"
  fi

  ensure_user
  ensure_dirs
  install_version "${VERSION}"
  ensure_links   "${VERSION}"
  ensure_configs
  install_units
  install_nginx
  install_ctl_if_requested

  log "Complete."
  log "Visit:"
  log "  https://development-budgetapp.${BUDGET_DOMAIN}/healthz"
  log "  https://test-budgetapp.${BUDGET_DOMAIN}/healthz"
  log "  https://production-budgetapp.${BUDGET_DOMAIN}/healthz"
}
main "$@"
