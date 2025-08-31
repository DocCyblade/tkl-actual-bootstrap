# README — configs & data layout (v0.23.1)

Instance data:
```
/srv/<INSTANCE>/data/
  ├─ config.json     # minimal Actual server config
  ├─ user-data/      # created on first run
  └─ server-data/    # created on first run
```

`config.json` example:
```json
{
  "port": 5000,
  "hostname": "127.0.0.1"
}
```
Notes:
- `hostname` should remain `127.0.0.1` (Actual binds locally; Nginx proxies from the Internet).
- Ports:
  - development: **5006**
  - test: **5000**
  - production: **5001**

Environment:
- Units set `ACTUAL_DATA_DIR=/srv/<INSTANCE>/data`
- The Actual server auto-detects this and creates `server-data` & `user-data` on first start.
