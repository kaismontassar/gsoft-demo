# CLAUDE.md

JFrog demo project (GlobalSoft). It shows:

1. GitHub Actions workflows authenticating to JFrog with OIDC.
2. JFrog Xray catching the vulnerable dependency lodash 4.17.11 (the approved version is 4.18.1, see `main`).

## Layout

- `.github/workflows/`: `jfrog-npm-ci.yml` (reusable CI), `gsoft-ci.yml` (caller, pinned to a commit SHA), `frogbot-scan-pull-request.yml` (Frogbot PR scan).
- `sbin/`: demo step scripts named `<step>-<summary>.sh`. Each script changes into the repo root (one directory up from `sbin/`) and loads `sbin/.env`; no hard-coded values or `$HOME` paths in the scripts.
- `RUNBOOK.md`: 30-minute session (preparation, timed steps, fallbacks); holds the location and link definitions.
- `RUNBOOK-FULL.md`: full version with workflows A and B; references the links in `RUNBOOK.md`.
- `CLAUDE-FINDINGS.md`: how the demo matches the JFrog requirements. Both runbooks reference its findings as `Fx`; keep details in one file only.

## Environment

- JFrog CLI server ID: `gsoft` (platform `https://jfrogkmm.jfrog.io`, project `gsoft`).
- Second repo using the shared CI template: `kaismontassar/gsoft-demo-consumer`.

## Conventions

- Markdown tables use an expanded-width layout: pad every cell so that all columns align, including the header separator row (`| ---- |` as wide as the column).
