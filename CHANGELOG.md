# Changelog — tkl-actual-bootstrap

This changelog is **cumulative** and organized into three parts:
1) **What’s New** — high-level summary for the most recent release (all scripts)
2) **scripts/actualctl — Full History** (newest first)
3) **scripts/bootstrap.sh — Full History** (newest first)

---

## 1) What’s New — v0.23.1 (2025-08-31)
- **scripts/actualctl v0.23.1**
  - Fix: `actualctl list` now shows only **version directories** under `/srv/app` (e.g., `v25.7.1`) and never lists symlinked directory contents.
- **scripts/bootstrap.sh**
  - No changes since **v0.23.0** (help/UX parity, safer Nginx fallback, idempotency, domain handling).

---

## 2) scripts/actualctl — Full History (newest first)

### v0.23.1 — 2025-08-31
**Fixed**
- `list`: display only version directories under `/srv/app` (sorted with `sort -V`).

### v0.23.0 — 2025-08-31
**Added**
- `instance set-port <NAME> <PORT>` — rewrite `/srv/<NAME>/data/config.json` and restart service.
- `health [INSTANCE]` — checks Nginx upstream (`/health/upstream`) and backend reachability.
- `doctor` — full system check: required tools, `nginx -t`, service state, port listening, upstream health.

**Changed**
- Help text parity with README; examples updated.
- Dynamic instance discovery (iterate `/srv/*/data`), not just dev/test/prod.

### v0.22.1 — 2025-08-31
**Changed**
- Documentation alignment with default Actual version **v25.7.1** (no functional changes).

### v0.22.0 — 2025-08-30
**Notes from tag**
- Doc-only bump for scripts (no functional changes).

### v0.21.0 — 2025-08-30
**Notes from tag**
- Docs: rebranded to **tkl-actual-bootstrap**; added GPLv3 licensing blocks and **LICENSE**.

---

## 3) scripts/bootstrap.sh — Full History (newest first)

### v0.23.0 — 2025-08-31
**Changed**
- Help/UX parity: **no-arg** shows banner + quick usage; `--help` shows full help.
- Safer Nginx fallback template; includes `/healthz` and `/health/upstream`.
- Idempotency & safety: never `chown -R /srv`; write files via `install` if changed.
- Domain handling with `/etc/actual-budget/env` (prompts if missing, or default `example.com` with `-y`).
- Amended: added `cmp` and `useradd` to `require_cmd` and documented prerequisites.

### v0.22.1 — 2025-08-31
**Changed**
- Default Actual Sync Server version set to **v25.7.1**.
- Systemd units use `./node_modules/.bin/actual-server` in `ExecStart` for stability.
- Optional `--install-ctl` to install `actualctl` into PATH (with `--ctl-path`).

### v0.22.0 — 2025-08-30
**From tag**
- Doc-only bump for scripts (no functional changes).

### v0.21.0 — 2025-08-30
**From tag**
- Rebranded to **tkl-actual-bootstrap**; added GPLv3 licensing blocks and **LICENSE**.

---

### Historical notes (pre–v0.21.0)
- Earlier “Rev” series (Rev 1–19) exist in the repository history and tags; where possible,
  details were reconstructed from commit/tag messages to maintain continuity with the new
  semantic versioning (v0.xx.y).