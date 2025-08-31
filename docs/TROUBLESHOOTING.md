# TROUBLESHOOTING (v0.23.1)

## 502 Bad Gateway
1. `systemctl status <instance>-budgetapp.service`
2. Logs: `journalctl -u <instance>-budgetapp.service -n 200 --no-pager`
3. Nginx: `nginx -t && systemctl reload nginx`
4. Port listening: `ss -ltn | grep :<port>$`
5. Backend probe: `curl -fsS -o /dev/null -w '%{http_code}' http://127.0.0.1:<port>/` (expect 200/404)
6. Upstream probe: `curl -k -fsS -o /dev/null -w '%{http_code}' https://<instance>-budgetapp.<domain>/health/upstream` (expect 200)

## npm EACCES / cache ownership
- Ensure `/home/budget-server/.npm` exists and `budget-server:budget-server` owns it.

## TLS errors
- Confirm files: `/etc/ssl/private/cert.pem`, `/etc/ssl/private/cert.key`
- Validate permissions allow Nginx worker to read.

## Port already in use
- Change with: `actualctl instance set-port <NAME> <PORT>`
- Restart service and `nginx -t && systemctl reload nginx` if fronted.

## Config corruption
- Validate JSON syntax: `jq . /srv/<instance>/data/config.json`

## Quick health sweep
```bash
actualctl doctor
```
