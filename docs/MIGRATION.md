# MIGRATION from pre–v0.20 (v0.23.1)

This guide helps move older installs to the standard layout.

## Target layout
- App versions: `/srv/app/vX.Y.Z`
- Instance links: `/srv/app/<instance>` -> `/srv/app/vX.Y.Z`
- Data per instance: `/srv/<instance>/data` (with `config.json`)

## Steps
1. **Backup** old data.
2. **Install** new version: `actualctl fetch v25.7.1`
3. **Create links** per instance:
   - `ln -sfn /srv/app/v25.7.1 /srv/app/test` (and `development`, `production`)
4. **Create data dirs**:
   - `/srv/test/data`, `/srv/development/data`, `/srv/production/data`
5. **Write `config.json`** with the right port per instance (see Common Port Map).
6. **Install/enable units** (via bootstrap or manual unit files).
7. **Nginx**: render vhosts for `*-budgetapp.<domain>`, run `nginx -t && systemctl reload nginx`
8. **Verify**: `actualctl list && actualctl health && actualctl doctor`

## Rollback
- Switch back links: `actualctl switch <instance> v<old>`
- Restore backups: `actualctl restore <instance> <tgz>`
