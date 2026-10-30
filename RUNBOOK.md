# Demo runbook (30 minutes)

Two short stories with the same mistake (lodash 4.17.11), covering the JFrog requirements R1–R4:

- **Fail right**: download blocking is off. The developer ignores the IDE warning and pushes. The branch build reports the violations but is not blocked; Frogbot blocks the PR. The fix is merged and main is gated, published and promoted.
- **Fail left**: an admin switches on download blocking. The same mistake on a new branch fails at install, before anything is built.

`Fx` references point to [CLAUDE-FINDINGS.md](CLAUDE-FINDINGS.md). The full version with workflows A and B is [RUNBOOK-FULL.md](RUNBOOK-FULL.md).

## Setup

- Scripts live in `sbin/`. Each one changes into the repo root (one directory up from `sbin/`) and loads `sbin/.env`; copy `sbin/.env.example` to `sbin/.env` on a new machine.
- Fill in `sbin/01c-session-notes-template.txt` during the session.
- Branches: `demo/will-fail-right-DDMMYYYY` and `demo/will-fail-left-DDMMYYYY` (real date; add `-02` for a second run on the same day).
- CI (`gsoft-ci.yml`) runs on every push to `main` and `demo/**`. The Xray gate fails the build and promotion runs only on `main`; on other branches the gate reports violations without failing.
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

| Step       | Task                                                                                                                                       | Where          | Script       | Ref    |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------ | -------------- | ------------ | ------ |
| P.0 - DONE | OIDC mappings per trust level: main (15), `demo/*` (20), Frogbot (30); catch-all 9 and dead 10 deleted (status: F10)                       | Web: jf-oidc   |              | F10    |
| P.1 - DONE | Workflow changes merged to `main` and tag `ci-v1` pushed (`gsoft-ci.yml` uses `@ci-v1`)                                                    | Terminal, Web  |              | F5     |
| P.2        | Branch-name check in `03a`, `03d`, `04d` accepts `demo/will-fail-*` (today only `demo/rehearsal-*`, `demo/live-*`)                         | IDE            |              | F13    |
| P.3 - OK   | Download blocking **off** on `gsoft-critical-cve-fix`; an admin is available to switch it on in S.11                                       | Web: jf-home   |              | F1, F2 |
| P.4        | Rehearse how quickly the block applies to the cached lodash 4.17.11 after switching it on                                                  | Web: jf-lodash |              | F1     |
| P.5        | `frogbot` environment has the presenter (`voko`) as required reviewer, "Prevent self-review" off; Frogbot refuses to run without reviewers | Web: gh-envs   |              | F7     |
| P.6 - DONE | Install the JFrog VS Code extension, connect to `jfrogkmm.jfrog.io`, set project `gsoft`; on Apple silicon install Rosetta 2 first (F11)   | IDE            |              | F11    |
| P.7 - OK   | Check the SBOM export of the last green `gsoft-demo` build and keep one file ready                                                         | Web: jf-builds |              | F12    |
| P.8 - ??   | lodash 4.17.11 is in the local npm cache (`03a` installs offline); do not clear the cache                                                  | Terminal       |              | F13    |
| P.9 - DONE | Preflight and baseline on `main`                                                                                                           | Terminal       | `01b`, `01d` |        |
| P.10       | Open browser tabs for all links, logged in to GitHub and JFrog                                                                             | Web            |              |        |
| P.11       | Close leftover PRs (#1, #7) and delete old `demo/will-fail-*` branches                                                                     | Web: gh-pulls  |              | F14    |
| P.12       | Optional backup: screenshot of a blocked install (for example run `40750669146`)                                                           | Web: gh-ci     |              |        |


## Session

### Intro

| Step | Time | What happens                                                                                                                                         | Where                                                                   | Script | Req | Ref    |
| ---- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ------ | --- | ------ |
| S.1  | 0–3  | Two repos, JFrog project `gsoft`, watch `globalsoft-watch-default` and its policies                                                                  | Web: gh-repo, jf-repos, jf-home (Xray › Watches & Policies)             |        | –   | F2, F3 |
| S.2  | 3–6  | OIDC: integration and identity mappings (per repo, branch and `frogbot` environment), no secrets; shared `jfrog-npm-ci.yml@ci-v1` used by both repos | Web: jf-oidc, gh-ci (run log, "Set up JFrog CLI with OIDC"), gh-cons-ci |        | R3  | F10    |

### Fail right

| Step  | Time  | What happens                                                                                                                | Where                                                 | Script | Req | Ref    |
| ----- | ----- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------ | --- | ------ |
| S.3   | 6–7   | New branch `demo/will-fail-right-…` with lodash 4.17.11                                                                     | Terminal                                              | `03a`  | –   |        |
| S.4   | 7–9   | JFrog extension flags lodash 4.17.11; the developer pushes anyway                                                           | IDE                                                   |        | R4  | F11    |
| S.4.1 |       | change lodash version in package.json; run jfrog can in IDE, run `npm install --ignore-scripts --no-audit --no-fund`        | Terminal, IDE                                         |        |     |        |
| S4.2  |       | push branch anyway, build succeeds                                                                                          | Terminal                                              |        |     |        |
|       |       |                                                                                                                             |                                                       |        |     |        |
| S.5   | 9–10  | create the PR                                                                                                               | Terminal, then Web: gh-pulls                          | `03d`  | –   |        |
| S.6   | 10–12 | Branch build green: gate step lists the violations but does not fail; no promotion on branches                              | Web: gh-ci (run, "Xray policy gate" log)              |        | R1  | F6     |
| S.7   | 12–16 | Approve the Frogbot run (`frogbot` environment); Frogbot red, PR blocked: walk through the comment, what the developer does | Web: PR page                                          |        | R2  | F7, F8 |
| S.8   | 16–17 | Fix: restore lodash 4.18.1, test, commit, push , APPROVE THE FROGBOT                                                        | Terminal                                              | `04d`  | –   | F13    |
| S.9   | 17–20 | While CI and Frogbot rerun: SBOM walkthrough of the last green build                                                        | Web: jf-builds (build › Xray Data › Export) *(check)* |        | R4  | F12    |
| S.10  | 20–22 | Branch build and Frogbot green, merge; CI on `main`: gate enforced and passes, promotion to STAGING; show package           | Web: PR page, gh-ci, jf-builds, jf-staging            |        | R1  | F6     |

### Fail left

| Step | Time  | What happens                                                                                                                                                       | Where                                                               | Script              | Req    | Ref     |
| ---- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- | ------------------- | ------ | ------- |
| S.11 | 22–23 | Admin switches on **Block download** for `globalsoft-critical-cve-fix`: "this is the shift left"                                                                   | Web: jf-home (Xray › Watches & Policies)                            |                     | R1     | F1, F2  |
| S.12 | 23–24 | Back to `main`, new branch `demo/will-fail-left-…` with lodash 4.17.11, push                                                                                       | Terminal                                                            | `04g`, `03a`, `03d` | –      |         |
| S.13 | 24–25 | Build fails at install with 403 from the Xray download block; show the blocked artifact                                                                            | Web: gh-ci (run), jf-lodash (Xray tab), jf-home (Xray › Violations) |                     | R1     | F1, F4  |
| S.14 | 25–27 | Rollout plan: Frogbot (ruleset, shared template, report-only first, PR approvals, environment reviewers for outside contributors) and OIDC (mappings per use case) | Talk                                                                |                     | R2, R3 | F9, F10 |
| S.15 | 27–30 | Buffer and Q&A                                                                                                                                                     | –                                                                   |                     | –      |         |

## Fallbacks

| Situation                                  | Action                                                                             | Ref |
| ------------------------------------------ | ---------------------------------------------------------------------------------- | --- |
| Block not effective yet in S.13            | Show the P.12 screenshot; rerun the build after S.14                               | F1  |
| Asked about exceptions / waivers           | Show the ignore-rule flow from RUNBOOK-FULL.md B.7 (`07c`, `07d`, `07e`)           |     |
| Frogbot waits for approval                 | Expected: approve on the run page ("Review deployments"); keep talking through S.9 | F7  |
| Frogbot: "doesn't have reviewers selected" | P.5 was missed: add the reviewer, then "Re-run jobs" on the failed run             | F7  |
| Frogbot slower than 4 minutes              | Continue with S.9 / S.14 and come back to the PR                                   |     |
| Branch build in S.6 fails at install       | Download blocking is still on (P.3); switch it off, rerun the job                  | F1  |

## After the session

| Step | What happens                                              | Where        | Script |
| ---- | --------------------------------------------------------- | ------------ | ------ |
| E.1  | Final state check                                         | Terminal     | `08b`  |
| E.2  | Switch download blocking off again (P.3 for the next run) | Web: jf-home |        |
| E.3  | Delete both session branches, fill in the session notes   | Web: gh-repo |        |

## Accepted trade-off

The "fail left" failure is the download block at install, not the gate step. The gate is shown reporting violations on the branch build (S.6) and enforcing on `main` (S.10).
