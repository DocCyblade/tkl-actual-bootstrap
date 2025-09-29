#!/usr/bin/env bash
# ==============================================================================
# tkl-actual-bootstrap : scripts/bootstrap.sh
# Version: v1.0.0-rc1
# Script-Version : v1.11.1
# Packaged-In    : v1.0.0-rc1
# Package-Compat : >=v1.0.0-rc1 <v1.1.0
# Last-Reviewed  : 2025-09-28 with package v1.0.0-rc1
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Summary:
#   Idempotent one-shot provisioner for multi-instance Actual Sync Server
#   on TurnKey Linux (NodeJS appliance v18). Creates/links instances,
#   installs the app locally under /srv/app/vX.Y.Z, writes systemd + nginx,
#   and installs 'actualctl' into PATH by default.
#
# Changes since v0.23.3:
#   - v1.11.1: install nginx vhost template to system share for actualctl (vhost.conf.tpl -> /usr/share/tkl-actual-bootstrap/templates/); no behavior change beyond ensuring template availability.
#   - v1.11.0: RC1 simplification — delegate per-instance work to 'actualctl instance add'; docs/completions bumped; no new features (RC1 freeze).
#   - v1.10.5: preflight npm version check for --install-version; atomic install via temp build dir (no leftover dirs on failure).
#   - v1.10.6: add --instances override to create a custom set of instances with optional per-instance ports; nginx/unit rendering now iterates dynamically; update path discovers existing instances instead of recreating defaults.
#   - v1.10.7: --instances supports NAME[:PORT][@FQDN]; per-instance FQDN override for Nginx vhosts.
#   - v1.10.4: prefer system VERSION manifest (/usr/share/tkl-actual-bootstrap/VERSION) over local ./VERSION for package reporting; aligns with actualctl; no behavior change when both match.
#   - v1.10.3: bash completions installer (actualctl & bootstrap) wired into normal and --update-install paths; prints hint to reload bash-completion; no app behavior change.
#   - v1.10.2: add --update-install flags: --with-units, --with-nginx, and --update-install-all; refresh units/nginx in update path; require domain for nginx.
#   - v1.10.1: set -u hardening (version helpers, install_version/ensure_links), adaptive banner, stronger ensure_user (group creation), require_cmd adds groupadd/getent/mktemp, help/defaults synced.
#   - v1.10.0: prep for v0.25.0 packaging and docs refresh.
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
  local f v=""
  for f in "${TKL_ACTUAL_VERSION_FILE:-}" \
           "/usr/share/tkl-actual-bootstrap/VERSION" \
           "./VERSION" \
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
  # Detect width and whether stdout is a TTY
  local cols tty=0 dash line
  cols="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  [[ -t 1 ]] && tty=1

  # Default to ASCII unless explicitly opted into UTF-8
  dash='-'
  if [[ "${USE_UTF8_BANNER:-0}" == "1" ]]; then
    if (( tty == 1 )) && locale 2>/dev/null | grep -qi 'utf-8'; then
      dash='─'
    fi
  fi
  line="$(printf "%${cols}s" | tr ' ' "$dash")"

  # Optional color (respect NO_COLOR)
  local clr_reset="" clr_em=""
  if (( tty == 1 )) && [[ -z "${NO_COLOR:-}" ]] && command -v tput >/dev/null 2>&1; then
    clr_reset="$(tput sgr0 2>/dev/null || true)"
    clr_em="$(tput bold 2>/dev/null || true)"
  fi

  printf '%s\n' "$line"
  printf '  %stkl-actual-bootstrap%s : bootstrap.sh (%s) - package %s\n' \
    "$clr_em" "$clr_reset" "${SCRIPT_VERSION}" "${PKG_VERSION}"
  printf '  Bootstrap for running Actual Sync Server on TurnKey Linux\n'
  printf '  License: GPL-3.0-or-later\n'
  printf '  Author: Ken Robinson <ken@turnkeylinux.org>\n'
  printf '  Source: https://github.com/DocCyblade/tkl-actual-bootstrap\n'
  printf '  Hint:   ./scripts/bootstrap.sh --help\n'
  printf '%s\n' "$line"
}

usage_quick() {
  cat <<'HELP'
Usage: ./scripts/bootstrap.sh [--yes|-y] [--dry-run] [--domain <name>] [--install-version vX.Y.Z] [--ctl-path /path/actualctl] [--instances "NAME[:PORT][@FQDN][,NAME[:PORT][@FQDN],...]"] [--version]
Hint : ./scripts/bootstrap.sh --help   # full docs | Use --update-install to refresh CLI/docs
HELP
}

print_usage() {
  cat <<'HELP'
Usage:
  ./scripts/bootstrap.sh
    [--yes|-y]
    [--dry-run]
    [--domain <name>]
    [--install-version vX.Y.Z]
    [--ctl-path /usr/local/sbin/actualctl]
    [--instances "NAME[:PORT][@FQDN][,NAME[:PORT][@FQDN],..."]
    [--help]
    [--version]
    --update-install
    [--with-units]
    [--with-nginx]
    [--update-install-all]

Options:
  --yes, -y            Non-interactive mode (assume “Yes” to prompts) for LIVE runs
  --dry-run            Preview actions without changing the system
  --domain NAME        Your base domain (e.g., example.com)
                       NOTE: If you pass --domain, you must also pass --yes (live) or --dry-run (preview).
                       If omitted, you'll be prompted (interactive mode).
  --install-version VER  Actual sync-server npm version to install (default: v25.7.1)
  --ctl-path PATH      Destination for installing actualctl (default: /usr/local/sbin/actualctl)
  --instances SPEC    Override the default instances. SPEC is a comma-separated list of NAME[:PORT][@FQDN].
                      Examples:
                        --instances "development,test,production"                       (defaults)
                        --instances "development:5006,test:5000,production:5001"       (explicit defaults)
                        --instances "prod:5099@budget.example.com"                     (single custom with FQDN)
                        --instances "staging:5002@staging.budget.tld,prod@budget.tld"  (two custom; prod auto-port)
                      If PORT is omitted for a default name, the default port is used.
                      If PORT is omitted for a non-default name, an available port ≥5002 is assigned.
                      If FQDN is omitted, the vhost defaults to <NAME>-budgetapp.<DOMAIN>.
  --help               Show this help and exit
  --version            Show script/package versions and exit
  --update-install     Refresh installed assets (actualctl, docs, VERSION) only; no app install/links
  --with-units         With --update-install, also reinstall systemd units (daemon-reload, enable/start)
  --with-nginx         With --update-install, also re-render Nginx vhosts and reload Nginx
                       (requires domain in /etc/actual-budget/env or pass --domain NAME with -y/--dry-run)
  --update-install-all Equivalent to --update-install --with-units --with-nginx

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
declare -A DOMAINS=()

# Instance override input (set via --instances)
INSTANCE_SPEC_INPUT=""

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
DO_UPDATE_INSTALL=0
DO_WITH_UNITS=0
DO_WITH_NGINX=0

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
# Instance specification parsing & discovery
# ───────────────────────────────────────────────────────────────────────────────
is_valid_name() { [[ "$1" =~ ^[a-z0-9-]+$ ]]; }

next_free_port() {
  local start=${1:-5002} used="$2" p
  for ((p=start; p<65000; p++)); do
    if [[ " $used " != *" $p "* ]]; then
      echo "$p"; return 0
    fi
  done
  echo 0; return 1
}

parse_instances_spec() {
  # If no override provided, keep defaults (INSTANCES/PORTS already set)
  [[ -n "$INSTANCE_SPEC_INPUT" ]] || return 0

  local spec="$INSTANCE_SPEC_INPUT" item name port used_ports="" out_names=() left fqdn
  declare -A out_ports
  declare -A out_domains

  # Normalize and split on commas
  spec="${spec//[[:space:]]/}"
  IFS=',' read -r -a items <<< "$spec"

  for item in "${items[@]}"; do
    [[ -n "$item" ]] || continue
    # Split optional @FQDN first, then optional :PORT
    left="$item"; fqdn=""
    if [[ "$left" == *"@"* ]]; then
      fqdn="${left##*@}"; left="${left%%@*}"
    fi
    if [[ "$left" == *":"* ]]; then
      name="${left%%:*}"; port="${left##*:}"
    else
      name="$left"; port=""
    fi
    is_valid_name "$name" || die "Invalid instance name: $name (use lowercase a-z, 0-9, and dashes)"
    if [[ -n "$port" ]]; then
      [[ "$port" =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]] || die "Invalid port for $name: $port"
      used_ports+=" $port"
    fi
    out_names+=("$name")
    out_ports["$name"]="$port"
    if [[ -n "$fqdn" ]]; then
      [[ "$fqdn" =~ ^[A-Za-z0-9.-]+$ ]] || die "Invalid FQDN for $name: $fqdn"
      out_domains["$name"]="$fqdn"
    fi
  done

  ((${#out_names[@]})) || die "--instances resolved to empty set"

  # Assign missing ports
  local n p
  for n in "${out_names[@]}"; do
    p="${out_ports[$n]}"
    if [[ -z "$p" ]]; then
      case "$n" in
        development) p="${PORTS[development]}" ;;
        test)        p="${PORTS[test]}" ;;
        production)  p="${PORTS[production]}" ;;
        *)           p="$(next_free_port 5002 "$used_ports")" ;;
      esac
      [[ "$p" != 0 ]] || die "Unable to assign a free port for $n"
      out_ports["$n"]="$p"
      used_ports+=" $p"
    fi
  done

  # Overwrite globals with parsed results
  INSTANCES=("${out_names[@]}")
  # Rebuild PORTS associative map
  for n in "${!PORTS[@]}"; do unset 'PORTS[$n]'; done
  for n in "${INSTANCES[@]}"; do PORTS["$n"]="${out_ports[$n]}"; done
  # Rebuild DOMAINS associative map
  for n in "${!DOMAINS[@]}"; do unset 'DOMAINS[$n]'; done
  for n in "${INSTANCES[@]}"; do
    if [[ -n "${out_domains[$n]:-}" ]]; then DOMAINS["$n"]="${out_domains[$n]}"; fi
  done
}

discover_existing_instances() {
  # Discover instances by existing /srv/<name>/data or /srv/app/<name> symlinks (excluding version dirs)
  local out=() d n seen=" "

  for d in /srv/*; do
    [[ -d "$d/data" ]] || continue
    n="$(basename "$d")"
    out+=("$n"); seen+="$n "
  done

  shopt -s nullglob
  for d in "${BASE_APP}"/*; do
    [[ -L "$d" ]] || continue
    n="$(basename "$d")"
    [[ "$n" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && continue
    [[ " $seen " == *" $n "* ]] || out+=("$n")
  done
  shopt -u nullglob

  if ((${#out[@]})); then
    IFS=$'\n' printf '%s\n' "${out[@]}" | sort
    unset IFS
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
    --install-version) VERSION="${2:-}"; shift 2 ;;
    --ctl-path)   CTL_DST="${2:-/usr/local/sbin/actualctl}"; shift 2 ;;
    --instances)  INSTANCE_SPEC_INPUT="${2:-}"; shift 2 ;;
    --version)     echo "bootstrap.sh ${SCRIPT_VERSION} (package ${PKG_VERSION})"; exit 0 ;;
    --update-install) DO_UPDATE_INSTALL=1; shift ;;
    --with-units) DO_WITH_UNITS=1; shift ;;
    --with-nginx) DO_WITH_NGINX=1; shift ;;
    --update-install-all) DO_UPDATE_INSTALL=1; DO_WITH_UNITS=1; DO_WITH_NGINX=1; shift ;;
    *)            err "Unknown arg: $1"; usage_quick; exit 2 ;;
  esac
done

# Enforce: if user passed --domain, they must also pass --yes (live) or --dry-run (preview)
if (( DOMAIN_FLAG_SET == 1 )); then
  if (( DRY_RUN == 0 && ASSUME_YES == 0 )); then
    die "--domain requires either --yes (for a live, non-interactive run) or --dry-run (for a preview)."
  fi
fi

# Parse --instances if provided (overrides INSTANCES/PORTS)
parse_instances_spec

# ───────────────────────────────────────────────────────────────────────────────
# Preconditions
# ───────────────────────────────────────────────────────────────────────────────
require_root() { [[ $(id -u) -eq 0 ]] || die "Run as root (no sudo)."; }

require_cmd() {
  # Only require tools we actually use here (actualctl has its own checks)
  local miss=0
  for c in node npm systemctl nginx sed install ln mkdir chown cmp useradd groupadd getent mktemp; do
    command -v "$c" >/dev/null 2>&1 || { err "Missing command: $c"; miss=1; }
  done
  # We try runuser for nicer env; fallback to su in code paths that need it.
  command -v runuser >/dev/null 2>&1 || warn "runuser not found; will fallback to su where needed"
  [[ $miss -eq 0 ]] || die "Install required tools and re-run."
}

# Return 0 if the given version exists on npm; supports v-prefixed or bare versions
npm_version_exists() {
  local ver="${1:-}"; [[ -n "$ver" ]] || return 1
  local npmver="${ver#v}"
  # Query as the service user; exit code indicates existence
  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$APP_USER" -- sh -lc \
      "npm view '@actual-app/sync-server@${npmver}' version --silent >/dev/null 2>&1"
  else
    su -s /bin/sh - "$APP_USER" -c \
      "npm view '@actual-app/sync-server@${npmver}' version --silent >/dev/null 2>&1"
  fi
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
  if getent group "$APP_GROUP" >/dev/null 2>&1; then
    log "Group exists: $APP_GROUP"
  else
    log "Creating system group '$APP_GROUP'"
    run "groupadd --system '$APP_GROUP'"
  fi
  if id "$APP_USER" >/dev/null 2>&1; then
    log "User exists: $APP_USER"
  else
    log "Creating user '$APP_USER' with home $APP_HOME"
    run "useradd --system --gid '$APP_GROUP' --create-home --home-dir '$APP_HOME' --shell '$APP_SHELL' '$APP_USER'"
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
  local ver="${1:-}"
  [[ -n "$ver" ]] || die "install_version: missing version (got empty arg)"
  local npmver="${ver#v}"
  local dest="${BASE_APP}/v${npmver}"

  # Build in a temp dir owned by the service user; only move into place on success
  local build
  build="$(mktemp -d -p "${BASE_APP}" ".build-v${npmver}.XXXXXX")" \
    || die "mktemp failed under ${BASE_APP}"
  log "Preparing temp build dir: ${build}"
  run "chown -R '${APP_USER}:${APP_GROUP}' '${build}'"

  # Cleanup on function return (success or failure); harmless if moved
  trap "rm -rf '${build}' 2>/dev/null || true" RETURN

  # Do the install as the service user
  if command -v runuser >/dev/null 2>&1; then
    run "runuser -u '${APP_USER}' -- sh -lc 'cd \"${build}\" && { test -f package.json || npm init -y >/dev/null 2>&1; } && npm config set fund false && npm config set audit false && npm install \"@actual-app/sync-server@${npmver}\"'"
  else
    run "su -s /bin/sh - '${APP_USER}' -c 'cd \"${build}\" && { test -f package.json || npm init -y >/dev/null 2>&1; } && npm config set fund false && npm config set audit false && npm install \"@actual-app/sync-server@${npmver}\"'"
  fi

  # Sanity check result
  if [[ ! -d "${build}/node_modules/@actual-app/sync-server" ]]; then
    die "Install failed: @actual-app/sync-server@${npmver} not found in ${build}/node_modules"
  fi

  # Move into place atomically
  run "rm -rf '${dest}'"
  run "mv '${build}' '${dest}'"
  trap - RETURN

  log "Installed Actual Sync Server @ ${dest}"
}

ensure_links() {
  # Point instance links (development/test/production) to the chosen version
  local ver="${1:-}"; [[ -n "$ver" ]] || die "ensure_links: missing version (got empty arg)"
  local canon="v${ver#v}"
  for link in "${INSTANCES[@]}"; do
    local target="${BASE_APP}/${canon}"
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
  local names=("$@")
  if ((${#names[@]}==0)); then names=("${INSTANCES[@]}"); fi
  log "Installing systemd units"
  local changed=0
  for inst in "${names[@]}"; do
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
  for inst in "${names[@]}"; do
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
  local out="/etc/nginx/sites-available/actual-${inst}.conf"
  local tmp; tmp="$(mktemp)"

  if [[ -f "$tpl" ]]; then
    sed -e "s|{{HOST}}|${host}|g" -e "s|{{PORT}}|${port}|g" "$tpl" > "$tmp"
  else
    warn "Template not found at $tpl; using built-in fallback"
    default_vhost_template | sed -e "s|{{HOST}}|${host}|g" -e "s|{{PORT}}|${port}|g" > "$tmp"
  fi

  copy_if_changed "$tmp" "$out"
  rm -f "$tmp"
  run "ln -sfn '$out' '/etc/nginx/sites-enabled/actual-${inst}.conf'"
}

install_nginx() {
  local names=("$@")
  if ((${#names[@]}==0)); then names=("${INSTANCES[@]}"); fi
  log "Installing Nginx vhosts"

  # Warn if cert files are missing (common Gotcha on fresh TurnKey)
  [[ -f "$CERT_CRT" ]] || warn "SSL cert not found: $CERT_CRT"
  [[ -f "$CERT_KEY" ]] || warn "SSL key  not found: $CERT_KEY"

  local inst host
  for inst in "${names[@]}"; do
    host="${DOMAINS[$inst]:-${inst}-budgetapp.${BUDGET_DOMAIN}}"
    render_nginx_site "$inst" "$host" "${PORTS[$inst]}"
  done

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
# Package version manifest (install VERSION file to system path)
# ───────────────────────────────────────────────────────────────────────────────
install_version_manifest() {
  local bundle_dir src dest_dir dst
  bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  src="${bundle_dir}/VERSION"
  dest_dir="/usr/share/tkl-actual-bootstrap"
  dst="${dest_dir}/VERSION"

  if [[ -f "$src" ]]; then
    log "Installing package VERSION manifest to $dst"
    run "install -d -m 0755 \"$dest_dir\""
    copy_if_changed "$src" "$dst"
  else
    warn "VERSION file not found at $src; skipping package manifest install"
  fi
}

install_docs() {
  local bundle_dir src_dir dest_dir
  bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  src_dir="${bundle_dir}/docs"
  dest_dir="/usr/share/tkl-actual-bootstrap/docs"

  if [[ ! -d "$src_dir" ]]; then
    warn "Docs dir not found at $src_dir; skipping docs install"
    return 0
  fi
  run "install -d -m 0755 \"$dest_dir\""
  # Copy all files (preserve subdirs)
  local f rel dst
  while IFS= read -r -d '' f; do
    rel="${f#"$src_dir"/}"
    dst="$dest_dir/$rel"
    run "install -d -m 0755 \"$(dirname "$dst")\""
    copy_if_changed "$f" "$dst"
  done < <(find "$src_dir" -type f -print0)
}

# Install nginx vhost template to a system path used by actualctl
install_templates() {
  local bundle_dir src dest_dir dst
  bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  src="${bundle_dir}/nginx/templates/vhost.conf.tpl"
  dest_dir="/usr/share/tkl-actual-bootstrap/templates"
  dst="${dest_dir}/vhost.conf.tpl"

  if [[ -f "$src" ]]; then
    log "Installing nginx vhost template to $dst"
    run "install -d -m 0755 \"$dest_dir\""
    copy_if_changed "$src" "$dst"
  else
    warn "nginx vhost template not found at $src; actualctl requires it to render sites"
  fi
}

# Install bash completion files for actualctl and bootstrap
install_completions() {
  local bundle_dir src_dir dest_dir
  bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  src_dir="${bundle_dir}/completions"
  dest_dir="/etc/bash_completion.d"
  if [[ ! -d "$src_dir" ]]; then
    warn "Completions dir not found at $src_dir; skipping bash completion install"
    return 0
  fi
  run "install -d -m 0755 \"$dest_dir\""
  # actualctl completion
  if [[ -f "${src_dir}/actualctl.bash" ]]; then
    copy_if_changed "${src_dir}/actualctl.bash" "${dest_dir}/actualctl"
  else
    warn "Missing ${src_dir}/actualctl.bash"
  fi
  # bootstrap completion (installed as 'tkl-actual-bootstrap' and bound also to ./scripts/bootstrap.sh)
  if [[ -f "${src_dir}/bootstrap.bash" ]]; then
    copy_if_changed "${src_dir}/bootstrap.bash" "${dest_dir}/tkl-actual-bootstrap"
  else
    warn "Missing ${src_dir}/bootstrap.bash"
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
  if (( DO_UPDATE_INSTALL == 1 )); then
    log "Refreshing installed assets (VERSION/docs/CLI)"
    install_version_manifest
    install_docs
    install_templates
    install_ctl
    install_completions
    if (( DO_WITH_UNITS == 1 )); then
      log "Refreshing systemd units"
      ensure_user
      # Discover existing instances; do not recreate missing defaults in update path
      mapfile -t EXISTING < <(discover_existing_instances || true)
      if ((${#EXISTING[@]})); then
        install_units "${EXISTING[@]}"
      else
        warn "No existing instances discovered under /srv or /srv/app; skipping unit reinstall"
      fi
    fi
    if (( DO_WITH_NGINX == 1 )); then
      # Ensure we have a domain (from env or arg); do not prompt here
      if [[ -z "$BUDGET_DOMAIN" ]]; then
        if ! read_env_domain; then
          die "--with-nginx requires a domain (set via previous run or pass --domain NAME with -y/--dry-run)."
        fi
      fi
      log "Refreshing Nginx vhosts for domain: $BUDGET_DOMAIN"
      mapfile -t EXISTING_NGX < <(discover_existing_instances || true)
      if ((${#EXISTING_NGX[@]})); then
        install_nginx "${EXISTING_NGX[@]}"
      else
        warn "No existing instances discovered; skipping Nginx vhost rendering"
      fi
    fi
    log "Bash completion installed to /etc/bash_completion.d (reload your shell or source /etc/bash_completion)"
    log "Update-install complete."
    return 0
  fi

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
  # Verify the requested version exists before attempting an install
  if (( DRY_RUN == 1 )); then
    log "[dry-run] would verify npm version '${VERSION}' via npm view"
  else
    log "Validating npm version: ${VERSION}"
    if ! npm_version_exists "${VERSION}"; then
      die "No such npm version: @actual-app/sync-server@${VERSION}. Try 'actualctl verify ${VERSION}' or choose a valid version."
    fi
  fi
  install_version "$VERSION"
  install_ctl
  install_templates

  # Delegate instances to actualctl (single source of truth)
  for inst in "${INSTANCES[@]}"; do
    host="${DOMAINS[$inst]:-${inst}-budgetapp.${BUDGET_DOMAIN}}"
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "[dry-run] %s instance add '%s' '%s' --port '%s' --domain '%s'\n" \
        "$CTL_DST" "$inst" "$VERSION" "${PORTS[$inst]}" "$host"
    else
      "$CTL_DST" instance add "$inst" "$VERSION" --port "${PORTS[$inst]}" --domain "$host"
    fi
  done

  install_version_manifest
  install_completions

  log "Complete."
  log "Visit:"
  for inst in "${INSTANCES[@]}"; do
    host="${DOMAINS[$inst]:-${inst}-budgetapp.$BUDGET_DOMAIN}"
    log "  https://${host}/healthz"
  done
}

main "$@"