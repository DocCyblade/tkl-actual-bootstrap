#!/usr/bin/env bash
# ==============================================================================
# tkl-actual-bootstrap : scripts/bootstrap.sh
# Version: v0.24.1
# Script-Version : v1.8.0
# Packaged-In    : v0.24.1
# Package-Compat : >=v0.24.1 <v0.25.0
# Last-Reviewed  : 2025-09-27 with package v0.24.1
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Summary:
#   Idempotent one-shot provisioner for multi-instance Actual Sync Server
#   on TurnKey Linux (NodeJS appliance v18). Creates/links instances,
#   installs the app locally under /srv/app/vX.Y.Z, writes systemd + nginx,
#   and installs 'actualctl' into PATH by default.
#
# Changes since v0.23.3:
#   - Docs-only: updated banner & references to CHANGELOG.txt / README.txt
#   - No functional changes
#
# License: GNU GPL v3
# Author : Ken Robinson <ken@turnkeylinux.org>
# Source : https://github.com/DocCyblade/tkl-actual-bootstrap
#
# Usage: ./scripts/bootstrap.sh --help     (quick usage shown on no-args)
# ==============================================================================


set -Eeuo pipefail

# --- dynamic version helpers (do not remove) ---
__tklab_read_version_file() {
  local f
  for f in "${TKL_ACTUAL_VERSION_FILE:-}" "./VERSION" \
           "/usr/share/tkl-actual-bootstrap/VERSION" \
           "/etc/actual-budget/pkg.version"; do
    [[ -n "$f" && -r "$f" ]] || continue
    if grep -q '^PKG_VERSION=' "$f" 2>/dev/null; then
      # shellcheck disable=SC1090
      . "$f"
      [[ -n "$PKG_VERSION" ]] && { echo "$PKG_VERSION"; return; }
    else
      read -r v <"$f" || true
      [[ -n "$v" ]] && { echo "$v"; return; }
    fi
  done
}

_pkg_version() {
  local v
  [[ -n "$TKL_ACTUAL_PKG_VERSION" ]] && { echo "$TKL_ACTUAL_PKG_VERSION"; return; }
  v=$(__tklab_read_version_file)
  [[ -n "$v" ]] && { echo "$v"; return; }
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    v=$(git describe --tags --abbrev=0 2>/dev/null || git describe --tags --always 2>/dev/null)
    [[ -n "$v" ]] && { echo "$v"; return; }
  fi
  awk -F: '/^# *Packaged-In/{gsub(/[ \t]/,"",$2); print $2; exit}' "${BASH_SOURCE[0]}" 2>/dev/null || echo "unknown"
}

_script_version() {
  awk -F: '/^# *Script-Version/{gsub(/[ \t]/,"",$2); print $2; exit}' "${BASH_SOURCE[0]}" 2>/dev/null || echo "unknown"
}

# Cache once per run
PKG_VERSION="$(_pkg_version)"
SCRIPT_VERSION="$(_script_version)"

# ───────────────────────────────────────────────────────────────────────────────
# Banner + help
# ───────────────────────────────────────────────────────────────────────────────
banner() {
  cat <<BANNER
┌──────────────────────────────────────────────────────────────────────────────┐
│ tkl-actual-bootstrap : bootstrap.sh               script \${SCRIPT_VERSION} │
│ Bootstrap for running Actual Sync Server on TurnKey Linux     package \${PKG_VERSION} │
│ License: GPL-3.0-or-later                                                     │
│ Author: Ken Robinson <ken@turnkeylinux.org>                                   │
│ Source: https://github.com/DocCyblade/tkl-actual-bootstrap                    │
│ Hint:   ./scripts/bootstrap.sh --help                                         │
└──────────────────────────────────────────────────────────────────────────────┘
BANNER
}

usage_quick() {
  cat <<'HELP'
Usage: ./scripts/bootstrap.sh [--yes|-y] [--dry-run] [--domain <name>] [--version vX.Y.Z] [--ctl-path /path/actualctl] [--about]
Hint : ./scripts/bootstrap.sh --help   # full documentation & examples
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
    [--ctl-path /usr/local/sbin/actualctl]
    [--help]
    [--about]

Options:
  --yes, -y            Non-interactive mode (assume “Yes” to prompts) for LIVE runs
  --dry-run            Preview actions without changing the system
  --domain NAME        Your base domain (e.g., example.com)
                       NOTE: If you pass --domain, you must also pass --yes (live) or --dry-run (preview).
                       If omitted, you'll be prompted (interactive mode).
  --version VER        Actual sync-server npm version (default: v25.7.1)
  --ctl-path PATH      Destination for installing actualctl (default: /usr/local/sbin/actualctl)
  --help               Show this help and exit
  --about             Show script/package versions and exit

Default ports:
  development: 5006
  test:        5000
  production:  5001
HELP
}

# Quick UX when no args; full help with --help
if [[ $# -eq 0 ]]; then banner; usage_quick; exit 0; fi
for a in "$@"; do
  if [[ "$a" == "-h" || "$a" == "--help" ]]; then banner; print_usage; exit 0; fi
done

# ───────────────────────────────────────────────────────────────────────────────
# Constants / defaults
# ───────────────────────────────────────────────────────────────────────────────
APP_USER="budget-server"
APP_GROUP="budget-server"
APP_SHELL="/bin/bash"
APP_HOME="/home/${APP_USER}"

BASE_APP="/srv/app"      # versions + instance symlinks
BACKUPS="/srv/backups"

# Well-known instances + default ports
INSTANCES=(development test production)
declare -A PORTS=( ["development"]=5006 ["test"]=5000 ["production"]=5001 )

# Certificates (TurnKey defaults)
CERT_CRT="${CERT_CRT:-/etc/ssl/private/cert.pem}"
CERT_KEY="${CERT_KEY:-/etc/ssl/private/cert.key}"

# Default Actual version
VERSION="${VERSION:-v25.7.1}"

# Domain env file
ENV_DIR="/etc/actual-budget"
ENV_FILE="${ENV_DIR}/env"

# Flags
DRY_RUN=0
ASSUME_YES=0
BUDGET_DOMAIN=""
DOMAIN_FLAG_SET=0

# actualctl install destination (always install by default)
CTL_DST="/usr/local/sbin/actualctl"

# ───────────────────────────────────────────────────────────────────────────────
# Logging + small helpers
# ───────────────────────────────────────────────────────────────────────────────
log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

run() {
  # Dry run prints the command; live run executes it
  if [[ $DRY_RUN -eq 1 ]]; then
    printf 'DRY-RUN: %s\n' "$*"
  else
    eval "$@"
  fi
}

copy_if_changed() {
  # Install file if content differs (preserve idempotence)
  local src="$1" dst="$2"
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    log "No change: $dst"
  else
    run "install -m 0644 \"$src\" \"$dst\""
  fi
}

# ───────────────────────────────────────────────────────────────────────────────
# Arg parsing
# ───────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=1; shift ;;
    -y|--yes)     ASSUME_YES=1; shift ;;
    --domain)     BUDGET_DOMAIN="${2:-}"; DOMAIN_FLAG_SET=1; shift 2 ;;
    --version)    VERSION="${2:-}"; shift 2 ;;
    --ctl-path)   CTL_DST="${2:-/usr/local/sbin/actualctl}"; shift 2 ;;
    --about)      echo "bootstrap.sh ${SCRIPT_VERSION} (package ${PKG_VERSION})"; exit 0 ;;
    *)            err "Unknown arg: $1"; usage_quick; exit 2 ;;
  esac
done

# Enforce: if user passed --domain, they must also pass --yes (live) or --dry-run (preview)
if (( DOMAIN_FLAG_SET == 1 )); then
  if (( DRY_RUN == 0 && ASSUME_YES == 0 )); then
    die "--domain requires either --yes (for a live, non-interactive run) or --dry-run (for a preview)."
  fi
fi

# ───────────────────────────────────────────────────────────────────────────────
# Preconditions
# ───────────────────────────────────────────────────────────────────────────────
require_root() { [[ $(id -u) -eq 0 ]] || die "Run as root (no sudo)."; }

require_cmd() {
  # Only require tools we actually use here (actualctl has its own checks)
  local miss=0
  for c in node npm systemctl nginx sed install ln mkdir chown cmp useradd; do
    command -v "$c" >/dev/null 2>&1 || { err "Missing command: $c"; miss=1; }
  done
  # We try runuser for nicer env; fallback to su in code paths that need it.
  command -v runuser >/dev/null 2>&1 || warn "runuser not found; will fallback to su where needed"
  [[ $miss -eq 0 ]] || die "Install required tools and re-run."
}

# ───────────────────────────────────────────────────────────────────────────────
# Domain handling
# ───────────────────────────────────────────────────────────────────────────────
read_env_domain() {
  [[ -f "$ENV_FILE" ]] || return 1
  local line; line="$(grep -E '^BUDGET_DOMAIN=' "$ENV_FILE" || true)"
  [[ -n "$line" ]] || return 1
  BUDGET_DOMAIN="${line#BUDGET_DOMAIN=}"
  BUDGET_DOMAIN="${BUDGET_DOMAIN%\"}"; BUDGET_DOMAIN="${BUDGET_DOMAIN#\"}"
  BUDGET_DOMAIN="${BUDGET_DOMAIN//$'\t\r\n '}"
  [[ -n "$BUDGET_DOMAIN" ]]
}

write_env_domain() {
  run "mkdir -p \"$ENV_DIR\""
  local tmp; tmp="$(mktemp)"
  printf 'BUDGET_DOMAIN=%s\n' "$BUDGET_DOMAIN" > "$tmp"
  copy_if_changed "$tmp" "$ENV_FILE"
  rm -f "$tmp"
}

prompt_domain_if_needed() {
  # If no domain provided, try env file; if still empty and not --dry-run, prompt (unless --yes w/ default)
  if [[ -z "$BUDGET_DOMAIN" ]]; then
    if read_env_domain; then
      log "Using domain from $ENV_FILE: $BUDGET_DOMAIN"
      return
    fi
    if (( DRY_RUN == 1 )); then
      # In dry run, default to example.com without prompting
      warn "No domain provided; DRY-RUN defaulting to example.com"
      BUDGET_DOMAIN="example.com"
    elif (( ASSUME_YES == 1 )); then
      # Non-interactive live run without domain: default to example.com
      warn "No domain provided; non-interactive defaulting to example.com"
      BUDGET_DOMAIN="example.com"
    else
      # Interactive prompt
      printf "Enter base domain (e.g., example.com): "
      read -r BUDGET_DOMAIN
      BUDGET_DOMAIN="${BUDGET_DOMAIN//$'\t\r\n '}"
      [[ -n "$BUDGET_DOMAIN" ]] || die "No domain provided."
    fi
  fi
  write_env_domain
}

# ───────────────────────────────────────────────────────────────────────────────
# System user / dirs
# ───────────────────────────────────────────────────────────────────────────────
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

ensure_dirs() {
  log "Ensuring directories"
  run "mkdir -p '$BASE_APP' '$BACKUPS'"
  for inst in "${INSTANCES[@]}"; do
    run "mkdir -p '/srv/${inst}/data'"
    # Do NOT chown /srv; only the instance subtree
    run "chown -R '$APP_USER:$APP_GROUP' '/srv/${inst}'"
  done
}

# ───────────────────────────────────────────────────────────────────────────────
# App install + linking
# ───────────────────────────────────────────────────────────────────────────────
install_version() {
  local ver="$1" dest="${BASE_APP}/${ver}"
  log "Preparing app dir: $dest"
  run "mkdir -p '$dest'"
  run "chown -R '$APP_USER:$APP_GROUP' '$dest'"

  if [[ -f "$dest/node_modules/@actual-app/sync-server/package.json" ]]; then
    log "Version present: $ver (skipping npm install)"
    return
  fi

  log "Installing @actual-app/sync-server@$ver into $dest"
  if command -v runuser >/dev/null 2>&1; then
    run "runuser -u '$APP_USER' -- bash -lc 'cd \"$dest\" && { test -f package.json || npm init -y; } && npm config set fund false && npm config set audit false && npm install \"@actual-app/sync-server@$ver\"'"
  else
    run "su -s /bin/bash - '$APP_USER' -c 'cd \"$dest\" && { test -f package.json || npm init -y; } && npm config set fund false && npm config set audit false && npm install \"@actual-app/sync-server@$ver\"'"
  fi
}

ensure_links() {
  # Point instance links (development/test/production) to the chosen version
  local ver="$1"
  for link in "${INSTANCES[@]}"; do
    local target="${BASE_APP}/${ver}"
    local linkpath="${BASE_APP}/${link}"
    log "Linking: $linkpath -> $target"
    run "ln -sfn '$target' '$linkpath'"
  done
}

# ───────────────────────────────────────────────────────────────────────────────
# Config seeding
# ───────────────────────────────────────────────────────────────────────────────
write_config_for() {
  # Seed /srv/<instance>/data/config.json, preferring repo template if present.
  local inst="$1"
  local port="$2"
  local data="/srv/${inst}/data"
  local cfg="${data}/config.json"
  local tmp; tmp="$(mktemp)"

  # Locate bundle root (../ from scripts/)
  local bundle_dir
  bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local tpl="${bundle_dir}/configs/config.json.tpl"

  if [[ -f "$tpl" ]]; then
    # Render from template
    sed "s/__PORT__/${port}/g" "$tpl" > "$tmp"
  else
    # Fallback inline (keeps idempotence without the template)
    cat >"$tmp" <<JSON
{
  "port": ${port},
  "hostname": "127.0.0.1"
}
JSON
  fi

  copy_if_changed "$tmp" "$cfg"
  rm -f "$tmp"
  run "chown -R '$APP_USER:$APP_GROUP' '$data'"
}

ensure_configs() {
  log "Copying configs"
  for inst in "${INSTANCES[@]}"; do
    log "Installing: /srv/${inst}/data/config.json"
    write_config_for "$inst" "${PORTS[$inst]}"
  done
}

# ───────────────────────────────────────────────────────────────────────────────
# systemd units
# ───────────────────────────────────────────────────────────────────────────────
unit_text() {
  local inst="$1"
  local linkdir="${BASE_APP}/${inst}"
  local datadir="/srv/${inst}/data"

  cat <<UNIT
# SPDX-License-Identifier: GPL-3.0-or-later
# Rendered as: /etc/systemd/system/${inst}-budgetapp.service
#
# WorkingDirectory = ${linkdir}          (symlink -> /srv/app/vX.Y.Z)
# ACTUAL_DATA_DIR  = ${datadir}          (config.json lives here)
# Service user     = budget-server

[Unit]
Description=Actual Sync Server (${inst})
After=network.target
# After=nginx.service

[Service]
Type=simple

# Runtime identity
User=${APP_USER}
Group=${APP_GROUP}

# App is installed locally via instance link
WorkingDirectory=${linkdir}

# Environment for the app
Environment=NODE_ENV=production
Environment=ACTUAL_DATA_DIR=${datadir}

# Launch Actual from local node_modules
ExecStart=/usr/bin/env bash -lc './node_modules/.bin/actual-server'

# Restart policy
Restart=on-failure
RestartSec=2

# Graceful shutdown (Node handles SIGINT)
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
# RestrictNamespaces=yes                          # enable if Node build doesn’t need namespaces
# ReadWritePaths=${datadir}                       # uncomment only if you change ProtectSystem level

[Install]
WantedBy=multi-user.target
UNIT
}

install_units() {
  log "Installing systemd units"
  local changed=0
  for inst in "${INSTANCES[@]}"; do
    local unit="/etc/systemd/system/${inst}-budgetapp.service"
    local tmp; tmp="$(mktemp)"
    unit_text "$inst" > "$tmp"
    if [[ -f "$unit" ]] && cmp -s "$tmp" "$unit"; then
      log "No change: $unit"
      rm -f "$tmp"
    else
      log "Installing: $unit"
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

# ───────────────────────────────────────────────────────────────────────────────
# Nginx vhosts (with /healthz and /health/upstream)
# ───────────────────────────────────────────────────────────────────────────────
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
  local inst="$1" host="$2" port="$3"
  host="${host//$'\t\r\n '}"
  local bundle_dir; bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local tpl="${bundle_dir}/nginx/templates/vhost.conf.tpl"
  local out="/etc/nginx/sites-available/${inst}-budgetapp.conf"
  local tmp; tmp="$(mktemp)"

  if [[ -f "$tpl" ]]; then
    sed -e "s|{{HOST}}|${host}|g" -e "s|{{PORT}}|${port}|g" "$tpl" > "$tmp"
  else
    warn "Template not found at $tpl; using built-in fallback"
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

  # Warn if cert files are missing (common Gotcha on fresh TurnKey)
  [[ -f "$CERT_CRT" ]] || warn "SSL cert not found: $CERT_CRT"
  [[ -f "$CERT_KEY" ]] || warn "SSL key  not found: $CERT_KEY"

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

# ───────────────────────────────────────────────────────────────────────────────
# actualctl installation (ALWAYS install; --ctl-path to override)
# ───────────────────────────────────────────────────────────────────────────────
install_ctl() {
  local script_dir src
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  src="${script_dir}/actualctl"

  if [[ ! -f "$src" ]]; then
    warn "actualctl not found at $src; skipping CLI install"
    return 0
  fi

  # Ensure destination dir exists
  run "mkdir -p '$(dirname "$CTL_DST")'"

  log "Installing actualctl to ${CTL_DST}"
  run "install -m 0755 \"$src\" \"$CTL_DST\""

  # Friendly path echo
  if command -v actualctl >/dev/null 2>&1; then
    log "actualctl is available at: $(command -v actualctl)"
  else
    warn "actualctl not found in current PATH; installed to ${CTL_DST}"
  fi
}

# ───────────────────────────────────────────────────────────────────────────────
# Main
# ───────────────────────────────────────────────────────────────────────────────
main() {
  banner
  require_root
  require_cmd
  prompt_domain_if_needed

  log "Parameters"
  log "  VERSION       = $VERSION"
  log "  DOMAIN        = $BUDGET_DOMAIN"
  log "  DRY_RUN       = $DRY_RUN"
  log "  CERT_CRT      = $CERT_CRT"
  log "  CERT_KEY      = $CERT_KEY"
  log "  CTL_DST       = $CTL_DST"
  log "  PKG_VERSION   = $PKG_VERSION"
  log "  SCRIPT_VERSION= $SCRIPT_VERSION"

  ensure_user
  ensure_dirs
  install_version "$VERSION"
  ensure_links "$VERSION"
  ensure_configs
  install_units
  install_nginx
  install_ctl

  log "Complete."
  log "Visit:"
  log "  https://development-budgetapp.$BUDGET_DOMAIN/healthz"
  log "  https://test-budgetapp.$BUDGET_DOMAIN/healthz"
  log "  https://production-budgetapp.$BUDGET_DOMAIN/healthz"
}

main "$@"