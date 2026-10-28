# Demo runbook (30 minutes)

One storyline covering the JFrog requirements R1–R4 in 30 minutes. Download blocking stays on for the whole session; the PR is merged at the end.
`Fx` references point to [CLAUDE-FINDINGS.md](CLAUDE-FINDINGS.md). The full version with workflows A and B, including the steps cut here, is [RUNBOOK-FULL.md](RUNBOOK-FULL.md).

## Setup

- Scripts live in `sbin/`. Each one changes into the repo root (one directory up from `sbin/`) and loads `sbin/.env`; copy `sbin/.env.example` to `sbin/.env` on a new machine.
- Fill in `sbin/01c-session-notes-template.txt` during the session.
- Measured waiting times: CI 25–42 s, consumer CI 40–51 s, Frogbot 87–240 s per run (job ~76 s, the rest is queue and environment approval).

### Locations

- **Terminal**: macOS terminal (or the VS Code integrated terminal) in the repo root.
- **IDE**: Visual Studio Code on macOS with the repo open.
- **Web**: links below. JFrog links start at the platform; the menu path to follow is given in the step. Deep links marked *(check)* were not verified.

| Key         | Link                                                                                                   |
| ----------- | ------------------------------------------------------------------------------------------------------ |
| gh-repo     | https://github.com/kaismontassar/gsoft-demo                                                            |
| gh-consumer | https://github.com/kaismontassar/gsoft-demo-consumer                                                   |
| gh-pulls    | https://github.com/kaismontassar/gsoft-demo/pulls                                                      |
| gh-ci       | https://github.com/kaismontassar/gsoft-demo/actions/workflows/gsoft-ci.yml                             |
| gh-frogbot  | https://github.com/kaismontassar/gsoft-demo/actions/workflows/frogbot-scan-pull-request.yml            |
| gh-rules    | https://github.com/kaismontassar/gsoft-demo/settings/rules                                             |
| gh-envs     | https://github.com/kaismontassar/gsoft-demo/settings/environments                                      |
| gh-cons-ci  | https://github.com/kaismontassar/gsoft-demo-consumer/actions                                           |
| jf-home     | https://jfrogkmm.jfrog.io/ui/                                                                          |
| jf-repos    | https://jfrogkmm.jfrog.io/ui/repos/tree/General/gsoft-npm-dev-virtual                                  |
| jf-lodash   | https://jfrogkmm.jfrog.io/ui/repos/tree/General/gsoft-npm-dev-remote-cache/lodash/-/lodash-4.17.11.tgz |
| jf-staging  | https://jfrogkmm.jfrog.io/ui/repos/tree/General/gsoft-npm-staging-local                                |
| jf-builds   | https://jfrogkmm.jfrog.io/ui/builds/gsoft-demo *(check)*                                               |
| jf-oidc     | https://jfrogkmm.jfrog.io/ui/admin/configuration/integrations *(check)*                                |

## Before the session

All items are blockers unless marked optional.

| Step | Task                                                                                                    | Where           | Script       | Ref    |
| ---- | ------------------------------------------------------------------------------------------------------- | --------------- | ------------ | ------ |
| P.1  | Preflight and baseline on `main`                                                                        | Terminal        | `01b`, `01d` |        |
| P.2  | Make the presenter a required reviewer of the `frogbot` environment, or remove the rule for the session | Web: gh-envs    |              | F7     |
| P.3  | Restore the `gsoft-ci.yml` pin to main's version, so the merge in S.9 does not move it                  | IDE, Terminal   |              | F5     |
| P.4  | Rehearse a Frogbot run with download blocking on; if it fails with 403, this runbook does not work      | Web: gh-frogbot |              | F1     |
| P.5  | Install the JFrog VS Code extension, connect to `jfrogkmm.jfrog.io`, set project `gsoft`                | IDE             |              | F11    |
| P.6  | Check the SBOM export of the last green `gsoft-demo` build and keep one file ready                      | Web: jf-builds  |              | F12    |
| P.7  | Create the session branch with lodash 4.17.11 (needs 4.17.11 in the local npm cache; do not clear it)   | Terminal        | `03a`        | F13    |
| P.8  | Open browser tabs for all links, logged in to GitHub and JFrog                                          | Web             |              |        |
| P.9  | Close leftover PRs #1 and #7                                                                            | Web: gh-pulls   |              | F14    |
| P.10 | Optional backup: screenshot of the gate scan of the old build `11.1`                                    | Terminal        | `05b`        | F4, F6 |

## Session

| Step | Time  | What happens                                                                                                        | Where                                                                   | Script | Req    | Ref        |
| ---- | ----- | ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ------ | ------ | ---------- |
| S.1  | 0–3   | Intro: two repos, JFrog project `gsoft`, watch `globalsoft-watch-default` and its policies                          | Web: gh-repo, jf-repos, jf-home (Xray › Watches & Policies)             |        | –      | F2, F3     |
| S.2  | 3–6   | OIDC: integration and identity mappings, no secrets in workflows; consumer repo as second use case (last green run) | Web: jf-oidc, gh-ci (run log, "Set up JFrog CLI with OIDC"), gh-cons-ci |        | R3     | F10        |
| S.3  | 6–9   | JFrog extension flags lodash 4.17.11 in `package.json` on the session branch                                        | IDE                                                                     |        | R4     | F11        |
| S.4  | 9–10  | Push, open the PR, start CI on the session branch                                                                   | Terminal, then Web: gh-pulls, gh-ci › Run workflow                      | `03d`  | –      |            |
| S.5  | 10–13 | While Frogbot runs: CI fails at install with 403 from the Xray download block; show the blocked artifact            | Web: gh-ci (run), jf-lodash (Xray tab), jf-home (Xray › Violations)     |        | R1     | F1, F4, F6 |
| S.6  | 13–17 | Frogbot red: approve the environment if asked, walk through the comment, explain what the developer does            | Web: PR page                                                            |        | R2     | F7, F8     |
| S.7  | 17–18 | Fix: restore lodash 4.18.1, test, commit, push                                                                      | Terminal                                                                | `04d`  | –      | F13        |
| S.8  | 18–22 | While Frogbot reruns: SBOM walkthrough of the last green build                                                      | Web: jf-builds (build › Xray Data › Export) *(check)*                   |        | R4     | F12        |
| S.9  | 22–25 | Frogbot green, merge the PR; CI on `main` green: gate passes, promotion to STAGING; show build info and package     | Web: PR page, gh-ci, jf-builds, jf-staging; Terminal                    | `04g`  | R1     | F5, F6     |
| S.10 | 25–27 | Rollout plan: Frogbot (ruleset, shared template, report-only first) and OIDC (mappings per use case)                | Talk                                                                    |        | R2, R3 | F9, F10    |
| S.11 | 27–30 | Buffer and Q&A                                                                                                      | –                                                                       |        | –      |            |

## Fallbacks

| Situation                                 | Action                                                                                         | Ref    |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------- | ------ |
| Asked to see the Xray gate step fail      | Show the P.10 screenshot of the `05b` scan                                                     | F4, F6 |
| Asked about exceptions / waivers          | Show the ignore-rule flow from RUNBOOK-FULL.md B.7 (`07c`, `07d`, `07e`)                       |        |
| Frogbot waits for approval                | Approve on the run page (P.2); keep talking through S.5 or S.8                                 | F7     |
| Frogbot slower than 4 minutes             | Continue with S.8 / S.10 and come back to the PR                                               |        |
| CI install succeeds on the session branch | Download block is off or the lock file is wrong; continue with Frogbot and use the P.10 backup | F1     |

## After the session

| Step | What happens                             | Where        | Script |
| ---- | ---------------------------------------- | ------------ | ------ |
| E.1  | Final state check                        | Terminal     | `08b`  |
| E.2  | Delete the session branch, fill in notes | Web: gh-repo |        |

## Cut from the full version

| Full step          | Reason                                                                     |
| ------------------ | -------------------------------------------------------------------------- |
| 0.6 (`01b`, `01d`) | Moved to P.1                                                               |
| A.9 (cancel PR)    | Replaced by the merge in S.9 (F14)                                         |
| B.2, B.3 (`05b`)   | The live CI failure shows the policy; old-build scan kept as backup (P.10) |
| B.5                | Clearing the npm cache would break `03a` (F13)                             |
| B.7 (waiver)       | Fallback only                                                              |
| B.9                | Consumer run shown as a link in S.2                                        |

## Accepted trade-off

The live failure comes from the download block at install, not from the `Xray policy gate` step (F4, F6). It meets "a failure based on Xray policy criteria" and shows the issue caught even earlier; the gate failure is covered by the P.10 backup.
