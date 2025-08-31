# README — CI / GitHub Actions (v0.23.1)

Suggested CI:
1. **Lint**: shellcheck + shfmt (verify no diffs)
2. **Build**: assemble bundles (docs + scripts), compute SHA256
3. **Test (dry-run)**: run `./scripts/bootstrap.sh --dry-run` and `scripts/actualctl doctor` in a Debian container
4. **Release**: upload artifacts to the GitHub Release for the tag

Minimal `ci.yml` outline:
```yaml
name: CI
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update && sudo apt-get install -y shellcheck shfmt
      - run: shellcheck -x scripts/*.sh
      - run: shfmt -d scripts
  dry-run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          chmod +x scripts/*.sh
          ./scripts/bootstrap.sh --dry-run || true
  release:
    if: startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build bundles & checksums
        run: |
          # your packaging steps here
          :
      - uses: softprops/action-gh-release@v2
        with:
          files: |
            dist/*.zip
            dist/SHA256SUMS
```
