# Demo runbook (full version)

Full intro and workflow steps (A and B), with the changes still needed. The 30-minute session is in [RUNBOOK.md](RUNBOOK.md).
`Fx` references point to [CLAUDE-FINDINGS.md](CLAUDE-FINDINGS.md), which also maps the steps to the JFrog requirements R1–R4.

## Setup

- Scripts live in `sbin/`. Each one changes into the repo root (one directory up from `sbin/`) and loads `sbin/.env`; copy `sbin/.env.example` to `sbin/.env` on a new machine.
- Fill in `sbin/01c-session-notes-template.txt` during the session.
- Generic workflow: always start on `main`, create a new `demo/*` branch, poison it with lodash 4.17.11, demo with that branch, end by merging to `main`.

| Workflow | Purpose                                                         |
| -------- | --------------------------------------------------------------- |
| A        | Frogbot and a standard pull request, without blocking downloads |
| B        | Shift left: suppress the download                               |

### Locations

Locations (Terminal, IDE, Web) and the link keys (`gh-*`, `jf-*`) are defined in [RUNBOOK.md](RUNBOOK.md#locations).

## 0 Environment overview

| Step | What to show                                                                                                                 | Where                                                                    | Script       | Changes needed                          |
| ---- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | ------------ | --------------------------------------- |
| 0.1  | Two GitHub repos: `gsoft-demo` (Frogbot PR scan, CI caller, reusable CI) and `gsoft-demo-consumer` (CI only, same template)  | Web: gh-repo, gh-consumer                                                |              | F3                                      |
| 0.2  | SaaS instance `jfrogkmm.jfrog.io`, project `gsoft`, npm virtual (local + cache-local + npmjs remote), DEV and STAGING locals | Web: jf-repos (Artifactory › Artifacts, project `gsoft`)                 |              |                                         |
| 0.3  | GitHub ↔ JFrog integration via OIDC (provider `globalsoft-github`), no secrets in the workflows                              | Web: jf-oidc (Administration › General Management › Manage Integrations) |              | Expand into a scaling walkthrough (F10) |
| 0.4  | Frogbot on GitHub: workflow, `frogbot` environment, required check in ruleset `main-require-frogbot`                         | Web: gh-frogbot, gh-envs, gh-rules                                       |              | Approval by kaismontassar per run (F7)  |
| 0.5  | Xray watch `globalsoft-watch-default` and its two policies                                                                   | Web: jf-home (Xray › Watches & Policies, project `gsoft`)                |              | Policy details need admin (F2)          |
| 0.6  | Preflight and baseline on `main`                                                                                             | Terminal                                                                 | `01b`, `01d` |                                         |

## A Generic workflow: two Frogbot runs (red and green)

| Step | What happens                                                 | Where                               | Script | Changes needed                                                                                        |
| ---- | ------------------------------------------------------------ | ----------------------------------- | ------ | ----------------------------------------------------------------------------------------------------- |
| A.1  | Introduce the vulnerable dependency on a new `demo/*` branch | Terminal                            | `03a`  | Branch-name check; `--offline` install (F13)                                                          |
| A.2  | Local check in the IDE                                       | IDE (JFrog extension view)          |        | Undefined: use the JFrog IDE plugin (F11)                                                             |
| A.3  | Push to GitHub                                               | Terminal                            | `03d`  |                                                                                                       |
| A.4  | Create the pull request                                      | Web: gh-pulls                       |        |                                                                                                       |
| A.5  | PR blocked by Frogbot (red)                                  | Web: PR page, run page (gh-frogbot) |        | Approve the `frogbot` environment (F7); walk through the comment (F8); rehearse with blocking on (F1) |
| A.6  | Fix / undo the injection in the IDE                          | IDE (or Terminal for the script)    | `04d`  | `04d` also does A.7 and A.8 (F13)                                                                     |
| A.7  | Test again in the IDE                                        | IDE (or Terminal for the script)    | `04d`  |                                                                                                       |
| A.8  | PR checks run again, Frogbot stays green                     | Web: PR page                        | `04d`  | Add rollout talking points (F9)                                                                       |
| A.9  | Cancel the PR or leave it open                               | Web: PR page                        |        | Conflicts with "always merge to main" (F14)                                                           |
| A.10 | Switch back to `main`                                        | Terminal                            | `04g`  |                                                                                                       |

## B Shift left

| Step | What happens                                                                        | Where                                                                       | Script              | Changes needed                                                               |
| ---- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------- | ---------------------------------------------------------------------------- |
| B.1  | Show the watch and policies in Xray, including the block-download action            | Web: jf-home (Xray › Watches & Policies)                                    |                     |                                                                              |
| B.2  | Switch to `main`                                                                    | Terminal                                                                    | `04g`               | `origin/main` is clean (4.18.1); "still broken" only holds for the old build |
| B.3  | Build scan in the terminal: one watch fires twice                                   | Terminal                                                                    | `05b`               | Scans old build `11.1` (F4, F13)                                             |
| B.4  | Poison a new branch, dispatch CI: install fails with 403 from the download block    | Terminal (`03a`, `03d`), then Web: gh-ci › Run workflow on the demo branch  | `03a`, `03d`        | Gate never runs live; show a gate failure too (F6)                           |
| B.5  | Same on the laptop: clean npm cache, `jf npm ci` returns 403                        | Terminal                                                                    |                     | No script yet (F13)                                                          |
| B.6  | Show the blocked artifact in `gsoft-npm-dev-remote-cache` and the violation in Xray | Web: jf-lodash (Xray tab), jf-home (Xray › Violations)                      |                     |                                                                              |
| B.7  | Optional waiver: ignore rule for `XRAY-85679`, scan passes; delete it, scan fails   | Web: jf-home (Xray › Watches & Policies › Ignore Rules), then Terminal      | `07c`, `07d`, `07e` |                                                                              |
| B.8  | Fix, merge to `main`: CI green, gate passes, promote to STAGING, checksum verified  | Terminal (`04d`, `04g`), Web: PR page (merge), gh-ci, jf-builds, jf-staging | `04d`, `04g`        | Restore caller pin first (F5); show the result in Artifactory (F6)           |
| B.9  | Optional: consumer repo CI, same template and OIDC, green                           | Web: gh-cons-ci                                                             |                     | Fits better under 0.3 (F3, F10)                                              |
| B.10 | SBOM walkthrough                                                                    | Web: jf-builds (build › Xray Data › Export) *(check)*                       |                     | Not defined yet (F12)                                                        |

## End

| Step | What happens                    | Where               | Script |
| ---- | ------------------------------- | ------------------- | ------ |
| E.1  | Final state check               | Terminal            | `08b`  |
| E.2  | Close leftover PRs and branches | Web: gh-pulls (F14) |        |

## Open decisions

- Run A with download blocking off, or confirm Frogbot works with it on (F1, F7).
- Merge or cancel the PR at the end of A (F14).
- Restructure A and B into the one-hour order proposed in CLAUDE-FINDINGS.md.
