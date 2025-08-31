# Changelog

**Versioning note:** Now using semantic-style labels vXX.YY.ZZ.

**Versioning note:** Starting v0.20, bundles use the v0.xx scheme. Prior release v19 = v0.19.


This changelog tracks script-level changes. Entries v1–v9 are reconstructed;
v10+ reflects our formalized bundles. Each script also includes a brief delta
in the header for quick reference.

## scripts/bootstrap.sh
<<<<<<< HEAD
=======
- **v0.22.0** — Doc bump & readability: version header updated; readable heredoc banner; help on no-args; nginx templating already present.
>>>>>>> alpha
- **v0.21.0** — Docs: rebranded to tkl-actual-bootstrap; added GPLv3 licensing blocks and LICENSE.
- **v0.20.4** — Docs: removed personal references; no functional changes.
- **v0.20.4** — Docs: added Migration from pre–v0.20 and Common port map to README; no functional changes.
- **v0.20.2** — Docs: CHANGELOG reordered newest→oldest; added explicit TurnKey Linux v18.0 prerequisite; no functional changes.
- **v0.20.1** — Docs: standardized historical version labels to vXX.YY.ZZ (no functional changes).
- **v0.20.0** — Docs: added Prerequisites & Troubleshooting; adopted v0.xx scheme (no functional changes).
- **v0.19.0** — Docs refresh; stronger domain handling; minor readability/typo fixes.
- **v0.18.0** — Generic domain; base instances: development/test/production; production symlink.
- **v0.17.0** — Expanded changelog back to v1–v9.
- **v0.16.0** — Headers + changelog references.
- **v0.15.0** — Doc polish.
- **v0.14.0** — Nginx health checks added in vhosts (edge and upstream).
- **v0.13.0** — True dry-run (no runuser); path fixes; minimal chown scope.
- **v0.12.0** — TurnKey TLS defaults; start-of-run prompt.
- **v0.11.0** — npm HOME/cache moved to service user; avoid `/srv/.npm` EACCES.
- **v0.10.0** — Fixed service user handling; avoid chowning `/srv`; run via runuser/su.
- **v0.9.0** — Hardened ownership scoping under `/srv/*`, avoided touching `/srv` root.
- **v0.8.0** — Service user home under `/home`, removed sudo assumptions.
- **v0.7.0** — Fixed `ver` unbound variable and arg parsing nits.
- **v0.6.0** — Added interactive flow & dry-run draft.
- **v0.5.0** — Idempotency checks.
- **v0.4.0** — Added inline documentation and clearer logging.
- **v0.3.0** — First public bundle; README partial.
- **v0.2.0** — Added instance directories and basic systemd unit templates.
- **v0.1.0** — Initial bootstrap skeleton (layout only).
## scripts/actualctl
<<<<<<< HEAD
=======
- **v0.22.0** — Doc bump & readability: version header updated; readable heredoc banner.
>>>>>>> alpha
- **v0.21.0** — Docs: rebranded to tkl-actual-bootstrap; added GPLv3 licensing blocks.
- **v0.20.4** — Docs: aligned with v0.20.4; no functional changes.
- **v0.20.4** — Docs: aligned with v0.20.4; no functional changes.
- **v0.20.2** — Docs: CHANGELOG reordered newest→oldest; no functional changes.
- **v0.20.1** — Docs: standardized historical version labels to vXX.YY.ZZ (no functional changes).
- **v0.20.0** — Docs parity with v0.20; adopted v0.xx scheme (no functional changes).
- **v0.19.0** — Docs parity; runuser detection fix; help refresh.
- **v0.18.0** — Generic domain; tracks renamed to production/test/development.
- **v0.17.0** — Docs-only: changelog backfill.
- **v0.16.0** — New: `instance rm`, `prune-backups`; parser fix; headers.
- **v0.15.0** — New: `instance add`, `check`, `env`, `verify` + systemd/nginx generation.
- **v0.14.0** — No changes.
- **v0.13.0** — No changes.
- **v0.12.0** — No changes.
- **v0.11.0** — All npm runs under service user HOME/cache.
- **v0.10.0** — Stable helper: manage services; fetch/switch; backup/restore; reset-password; shell; logs/status.
- **v0.9.0** — Minor fixes; help cleanup.
- **v0.8.0** — Honor service user env; prep for npm cache isolation.
- **v0.7.0** — Logging polish, error handling improvements.
- **v0.6.0** — `reset-password` and `shell` helpers.
- **v0.5.0** — Safer `switch` (stop → link → start).
- **v0.4.0** — Help examples improved.
- **v0.3.0** — Added `backup`/`restore`; help text.
- **v0.2.0** — Added `fetch` and `switch` (tracking links).
- **v0.1.0** — Helper draft: start/stop/status/logs for fixed instances.