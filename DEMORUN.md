# Demo runbook (30 minutes)

Two short stories with the same mistake (lodash 4.17.11), covering the JFrog requirements R1–R4:

- **Fail right**: download blocking is off. The developer ignores the IDE warning and pushes. The branch build reports the violations but is not blocked; Frogbot blocks the PR. The fix is merged and main is gated, published and promoted.
- **Fail left**: an admin switches on download blocking. The same mistake on a new branch fails at install, before anything is built.

## Preparations

| Step | Do                           | Comments                                                                                                                                     |
| ---- | ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| P-01 | sbin/01-preparation.sh       | clears git working copy and remote branches, pulls main, turns downloadblock off                                                             |
| P-02 | sbin/open-links.sh           | opens `DEMO_LINKS` from `sbin/.env` (or the URLs given as arguments) in a browser window. See comments for other browser options under linux |
| P-03 | optional: run IDE jfrog scan | run from `main`, should tell that all is fine                                                                                                |
| P-04 | Once only                    | Setup three tokens and three server IDs for jfrog cli, see below                                                                             |
|      |                              |                                                                                                                                              |

### Prep: server IDs

* create two tokens and set the names in .env
* check examples at https://jfrogkmm.jfrog.io/ui/admin/configuration/security/access_tokens
| desrciption example | .env variable    | volker's name | comment                        |
| ------------------- | ---------------- | ------------- | ------------------------------ |
| voko-admin          | SERVER_ID        | gsoft         | currently only used by AI      |
| vokostudio-curl     | POLICY_SERVER_ID | gsoft-voko    | needed for `set-policy-block*` |

```bash
jf config add gsoft-user --url https://jfrogkmm.jfrog.io
# then select token and paste your token value
# afterwards set POLICY_SERVER_ID to 'gsoft-user'

```

## Intro

| Step | Do                           | where   | Say                                              | Comments                                                                  |
| ---- | ---------------------------- | ------- | ------------------------------------------------ | ------------------------------------------------------------------------- |
| I-01 | sbin/open-links.sh           | browser | show two github repos, polices, identity mapping | only show tabs, no clicking                                               |
| I-02 | dependency, workflows        | IDE     | package.json, gsoft-ci.yml, jfrog-npm-ci.yml     | show 'nice' koadash version, expalain how jfrog-nom-ci is called by gsoft |

## fail right

| Step    | Do                                                           | Where     | Comments                                      |
| ------- | ------------------------------------------------------------ | --------- | --------------------------------------------- |
| FR-01   | `git checkout -b demo/fail-right`                            | shell     | starting a coding cycle                       |
| FR-02   | patch package,json with version `4.17.11`, run `npm install` | IDE       | introducing vul                               |
| FR-03   | run jfrog scan in IDE                                        | IDE       |                                               |
| FR-04   | while  FR-03 is running, show OIDC integration               | IDE       |                                               |
| FR-04.1 | show OIDC blocks in frogbot and jfrog workflows              | IDE       |                                               |
| FR-04.2 | show OIDC Integration landing page (Audience, orga)          | jfrog     |                                               |
| FR-05   | show scan results in IDE                                     | IDE       |                                               |
| FR-06   | push anyway `git commit -am "Did it anyway" ; git push`      | shell     | Or use IDE                                    |
| FR-07   | show build running (github --> gsoft-demo --> Actions)       | github    |                                               |
| FR-08   | show step results for XRay Policy Gate and Build Summary     | github    |                                               |
| FR-09   | create PR                                                    | github    |                                               |
| FR-10   | Approve Frogbot Build (got actions and open the frogbot job) | github    |                                               |
| FR-11   | while frogbot runs, aks for questions                        | --        |                                               |
| FR-12   | show red Frogbot results                                     | github    |                                               |
| FR-13   | fix `package.json`, then                                     | IDE       |                                               |
| FR-14   | `npm install; git commit -am "fixed it right" ; git push`    | Termninal |                                               |
| FR-15   | approve frogbot                                              |           |                                               |
| FR-16   | export SBOM (CycloneDX, all checkboxes, json)                |           | open in https://cyclonedx.github.io/Sunshine/ |
| FR-17   | Merge Pull Request to main                                   | github    |                                               |

## fail left

| Step         | Do                                                            | Where  | Comments                  |
| ------------ | ------------------------------------------------------------- | ------ | ------------------------- |
| FL-01        | enable blocking `sbin/set-policy-block.sh true`               | shell  | or use the jfrog web UI   |
| FL-02        | `git switch main; git pull ; git checkout -b demo/fail-left`  | shell  |                           |
| FL-03        | introduce the vul again                                       | IDE    |                           |
| FL-04        | `npm install; git commit -am "done it again/left" ; git push` | shell  |                           |
| FL-05        | see the build fail directly                                   | github | currently NOT failing!!   |
| INTERMISSION | ------ below is not reproduced yet, seel also TODO-01 ------- |        |                           |
| FL-07        | run a change/PR in gsoft-demo-consumer                        | IDE    | shows OIDC reuse          |
| FL-08        | see the build being scanned using the action and OIDC         | github | ? with vul or without ? |

## FINDINGS

### Policy change does not block

curious behaviour, depending on the direction of the switch. Please try to reproduce

**blocked --> not blocked**: refreshing the XRay page for the artifact will clear the blockage
**non-blocked --> blocked**: refreshing has no effect, a rescan is required, then the block works

## TODOs

| ID      | What                                                                  | Status |
| ------- | --------------------------------------------------------------------- | ------ |
| TODO-01 | make gsoft-demo-consumer also start the build upon push automatically | new    |
| TODO-02 |                                                                       |        |
