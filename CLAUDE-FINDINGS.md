# Claude findings: demo vs. JFrog requirements

Checked on 2026-10-28 with read-only `jf` (server ID `gsoft`) and `gh` calls.
The demo steps these findings refer to are in [RUNBOOK.md](RUNBOOK.md) (30-minute session, `P.x`, `S.x`) and [RUNBOOK-FULL.md](RUNBOOK-FULL.md) (full version, `0.x`, `A.x`, `B.x`).

## JFrog requirements (follow-up session, max. 1 hour)

- **R1** A real pipeline running end to end: the build, a failure based on Xray policy criteria, and a successful build that publishes and promotes an artifact in Artifactory.
- **R2** Frogbot on a live PR, with an explanation of what it reports, what a developer should do, and how to roll it out.
- **R3** An OIDC setup that can scale beyond a single use case.
- **R4** The IDE plugin flagging a vulnerability, and an SBOM with a walkthrough of its compliance value.

## Coverage summary

| Req | Covered by      | Status                           | Findings       |
| --- | --------------- | -------------------------------- | -------------- |
| R1  | B.3, B.4, B.8   | Mostly                           | F1, F4, F5, F6 |
| R2  | A.3–A.8         | Partial (live PR only)           | F7, F8, F9     |
| R3  | 0.3             | Partial (present, not explained) | F10            |
| R4  | A.2 (undefined) | Missing                          | F11, F12       |

## Platform and repository facts

### F1 Download blocking is already active
CI run `40750669146` (`demo/voko`) failed at **"Install dependencies"**, not at the Xray gate:
`lodash-4.17.11.tgz was not downloaded due to the download blocking policy configured in Xray for gsoft-npm-dev-remote-cache` (npm E403).
The run before it (`40740454052`) passed every step because the lock file still pointed at the 4.18.1 tarball (fixed since).
The notes describe workflow A as "without blocking downloads", which does not match the current state.

### F2 Xray configuration
- Watch `globalsoft-watch-default` covers builds `gsoft-demo` and `globalsoft-security-validation` and repo `gsoft-npm-dev-remote` (among others). Policies: `globalsoft-malicious-block`, `globalsoft-critical-cve-fix`.
- `globalsoft-watch-waiver` covers `gsoft-npm-dev-local` with `globalsoft-high-notify`. `globalsoft-license-risk` is only on `globalsoft-watch-secured` (docker prod).
- A second set of `gsoft-watch-*` watches exists (project-wide). `sbin/.env` uses `globalsoft-watch-default`.
- The policy API returns **403** for the `gsoft` user, so the policy actions (fail build, block download) could not be checked. Changing them needs an admin.
- No ignore rules exist in project `gsoft` at the moment.
- Curation is off on `gsoft-npm-dev-remote` (`curated: false`). Blocking is done by an Xray policy action.
- lodash 4.17.11 is cached in `gsoft-npm-dev-remote-cache`.

### F3 Second repository
`kaismontassar/gsoft-demo-consumer` exists. Its only workflow (`ci.yml`) calls `gsoft-demo/.github/workflows/jfrog-npm-ci.yml@ef72c08` with build name `globalsoft-security-validation`, lodash 4.18.1. Last run succeeded. In this repo it is only mentioned in `sbin/01c-session-notes-template.txt` ("consumer build … fill after 5f").

## Workflow review

### F4 `jfrog-npm-ci.yml` (reusable CI)
- OIDC done right: `id-token: write`, `setup-jfrog-cli` with provider `globalsoft-github`, no stored secrets.
- With blocking on (F1), a poisoned branch fails at install, before build or publish. That is good shift-left evidence, but the **`Xray policy gate` step never runs live** on a vulnerable build.
- With blocking off, the package is **published to DEV before the gate**. The gate only stops promotion to STAGING.
- Because no new 4.17.11 build can be produced while blocked, `05b`/`07*` scan the old build `11.1`. The B.3 step depends on that build staying in Artifactory.

### F5 `gsoft-ci.yml` (caller)
- Triggers: push to `main`, `workflow_dispatch`. Fits "always merge to main".
- Pin differs: `main` uses `@ef72c08`, `demo/voko` uses `@12ba32a` (npm cache step commented out). The working copy of `jfrog-npm-ci.yml` was restored from `main`, but it has no effect while the caller pins `12ba32a`. Merging `demo/voko` would move main's pin; restore the caller to main's version first.
- **Status (prepared on `demo/voko`):** the caller now runs on pushes to `main` and `demo/**` and uses the tag `@ci-v1` instead of a commit SHA. The tag still has to be created and pushed.

### F6 R1 gaps: pipeline
- Show a live **gate** failure: either (a) run CI once with blocking off (gate fails), then with blocking on (install fails, "even earlier"), or (b) add a policy with *fail build* but no block download, triggered by a different vulnerable version.
- **Status (prepared on `demo/voko`):** `jfrog-npm-ci.yml` has a new input `enforce-branch` (default `main`). The gate fails the build and promotion runs only on that branch; other branches report violations. RUNBOOK.md uses this for "fail right" and switches blocking on for "fail left".
- Add a step that shows the result in Artifactory: package in `gsoft-npm-staging-local`, build info with STAGING status, the build's Xray tab.

### F7 `frogbot-scan-pull-request.yml`
- Ruleset `main-require-frogbot` requires the check "Frogbot PR scan" on the default branch, so a red Frogbot really blocks the merge.
- `pull_request_target` with checkout of the trusted base SHA is the correct secure pattern. It always runs the workflow file from `main`, so edits on demo branches have no effect.
- Environment `frogbot` requires approval from **kaismontassar** on every run. A solo presenter waits at A.5 and A.8.
- Earlier rehearsals show the red/green sequence ("Found 10 violations: [10 SCA]"). It is unclear whether Frogbot still works with download blocking on (F1); rehearse it.
- Only same-repo PRs are scanned (forks excluded).

### F8 R2 gap: what Frogbot reports and what the developer does
Add a walkthrough of the PR comment: CVE, severity, fixed version, contextual analysis (is the vulnerable code reachable), plus the SAST/secrets/IaC scanners that ran. Make the developer action explicit: take the fixed version from the comment, bump, push, check turns green.

### F9 R2 gap: rollout
No step yet. Talking points available in this setup: org-wide ruleset with the required check, shared workflow template, start with `JF_FAIL=false` (report only) then enforce, `frogbot` environment as approval gate, optionally Frogbot "scan repository" for automatic fix PRs.

### F10 R3 gap: OIDC that scales
Currently only an intro bullet. Show: one provider used by two repos and two workflow types; identity mappings on claims (`repository`, `ref`, `environment`, optionally `job_workflow_ref` to allow only the shared template) giving different scopes (main CI deploys, PR scan reads); onboarding a new repo needs no secret. The mappings could not be read with the `gsoft` user (access API 404/403). Verify in the UI that they actually differ per use case; one catch-all mapping makes the scaling story thin.

### F11 R4 gap: IDE plugin
A.2 is undefined. Use the JFrog IDE plugin (VS Code or IntelliJ) connected to `jfrogkmm.jfrog.io` with project `gsoft`, flagging lodash 4.17.11 in `package.json`. Needs install, config and rehearsal, including a check that the plugin scan works while download blocking is on.

### F12 R4 gap: SBOM
No step yet. Export a CycloneDX/SPDX SBOM from the Xray scan of build `gsoft-demo` (UI), or generate it with `jf` and keep it as a pipeline artifact. Compliance talking points: component inventory (including the replaced dependency), licenses (`globalsoft-license-risk` is not on the default watch, F2), CVE/VEX status, traceability build → commit → SBOM → promoted package, regulatory context (CRA, EO 14028, customer audits).

### F13 Script issues
- `03a` installs with `npm ci --offline` from the local npm cache, so it never hits Artifactory and hides the download block. A blocked-install step needs `npm cache clean --force` and `jf npm ci`.
- `03a`, `03d`, `04d` only accept branches named `demo/rehearsal-*` or `demo/live-*`.
- `BUILD_NUMBER` in `sbin/.env` is `11.1` (old numbering); current CI builds use `<run_id>.<attempt>`.
- `04d` does fix, test, commit and push in one go (A.6–A.8 cannot be shown separately).
- Local Node is v26; `package.json` requires `>=24 <25`.

### F14 Housekeeping
- Open PRs #1 (`demo/frogbot-vulnerable-dependency`) and #7 (`demo/rehearsal-27-10-2026`).
- The notes say both "cancel the PR" (A.9) and "always merge to main"; decide which applies.

## Proposed order for one hour

| Block                                                                   | Minutes | Requirement |
| ----------------------------------------------------------------------- | ------- | ----------- |
| Intro, OIDC walkthrough, consumer repo as "second team"                 | 10      | R3          |
| IDE plugin flags lodash                                                 | 5       | R4          |
| Frogbot PR red → green, comment walkthrough, rollout                    | 15      | R2          |
| Pipeline: gate fails → install blocked → fix, promote, Artifactory view | 15      | R1          |
| SBOM walkthrough                                                        | 10      | R4          |
| Q&A                                                                     | 5       |             |

A and B as currently defined both poison a branch and open a PR; the order above does that once.
