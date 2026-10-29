# gsoft-demo

JFrog certification demo for GlobalSoft. It shows:

1. GitHub Actions workflows authenticating to the JFrog Platform (`jfrogkmm.jfrog.io`, project `gsoft`) with OIDC, without stored secrets.
2. JFrog Xray and Frogbot catching the vulnerable dependency lodash 4.17.11; the approved version is 4.18.1.

The demo itself is described in [RUNBOOK.md](RUNBOOK.md) (30-minute session) and [RUNBOOK-FULL.md](RUNBOOK-FULL.md) (full version).

## Getting started

```bash
cp sbin/.env.example sbin/.env     # demo settings, gitignored
sbin/01b-preflight-tool-versions.sh
sbin/01d-baseline-main-install-test.sh
```

Requires Node.js 24 (`.nvmrc`), npm and the JFrog CLI with a server ID `gsoft`.

## Files

### Application

| File                  | Purpose                                                                     |
| --------------------- | --------------------------------------------------------------------------- |
| `src/report.js`       | Small release report generator; `--build` writes `dist/release-report.json` |
| `test/report.test.js` | Tests for the report, run with `npm test` (`node --test`)                   |
| `package.json`        | Package metadata, scripts and the lodash dependency                         |
| `package-lock.json`   | Locked dependency tree, resolved through `gsoft-npm-dev-virtual`            |
| `.nvmrc`              | Node.js version used locally and in CI                                      |
| `.gitignore`          | Ignores `node_modules/`, `dist/`, `.env`, `.npmrc`, logs, `.DS_Store`       |

### GitHub workflows

| File                                              | Purpose                                                                                                                  |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `.github/workflows/jfrog-npm-ci.yml`              | Reusable CI (tags `ci-v1`, `ci-v1.0.0`): OIDC login, install, test, build, publish to DEV, Xray gate, promote to STAGING |
| `.github/workflows/gsoft-ci.yml`                  | Calls the reusable CI at `@ci-v1` on pushes to `main` and `demo/**`; the gate fails and promotion runs only on `main`    |
| `.github/workflows/frogbot-scan-pull-request.yml` | Frogbot scan of pull requests to `main` (OIDC, `frogbot` environment); required check in ruleset `main-require-frogbot`  |

### Demo scripts (`sbin/`)

Each script changes into the repo root and loads `sbin/.env`. The prefix is the step ID used in the runbooks.

| File                                           | Purpose                                                                     |
| ---------------------------------------------- | --------------------------------------------------------------------------- |
| `sbin/.env.example`                            | Template for `sbin/.env`: server ID, project, repos, build, watch, versions |
| `sbin/01b-preflight-tool-versions.sh`          | Host, git status, Node, npm and JFrog CLI versions                          |
| `sbin/01c-session-notes-template.txt`          | Session notes to fill in (not a script)                                     |
| `sbin/01d-baseline-main-install-test.sh`       | Clean `main`: configure npm for Artifactory, install, test                  |
| `sbin/03a-create-branch-vulnerable-lodash.sh`  | New demo branch with lodash 4.17.11 from the vulnerable commit              |
| `sbin/03d-commit-push-vulnerable-lodash.sh`    | Commit and push the vulnerable dependency                                   |
| `sbin/04d-restore-fixed-lodash-commit-push.sh` | Restore lodash 4.18.1 from `main`, install, test, build, commit, push       |
| `sbin/04g-sync-main-after-merge.sh`            | Back to `main` after the merge, install                                     |
| `sbin/05b-xray-build-scan-gate.sh`             | Xray build scan of a published build with `--fail`                          |
| `sbin/07c-build-scan-with-ignore-rule.sh`      | Build scan while an ignore rule (waiver) is active                          |
| `sbin/07d-list-ignore-rule.sh`                 | List the ignore rule for the demo vulnerability                             |
| `sbin/07e-delete-ignore-rule-rescan.sh`        | Delete the ignore rule and scan again                                       |
| `sbin/08b-final-state-check.sh`                | Final state: branch, status, installed lodash                               |

### Documentation

| File                 | Purpose                                                                                  |
| -------------------- | ---------------------------------------------------------------------------------------- |
| `README.md`          | This overview                                                                            |
| `RUNBOOK.md`         | 30-minute session: preparation, timed steps, locations and links, fallbacks              |
| `RUNBOOK-FULL.md`    | Full version with workflows A (Frogbot) and B (shift left)                               |
| `CLAUDE-FINDINGS.md` | How the demo matches the JFrog requirements (findings `Fx`, referenced by both runbooks) |
| `CLAUDE.md`          | Instructions for Claude Code working in this repo                                        |

## Related repository

[`kaismontassar/gsoft-demo-consumer`](https://github.com/kaismontassar/gsoft-demo-consumer) uses the same reusable CI workflow from a second repository.
