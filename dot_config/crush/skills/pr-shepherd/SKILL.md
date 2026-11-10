---
name: pr-shepherd
description: Use when told to open a PR, shepherd a PR, watch CI on a PR, fix a failing PR, or invoke pr-shepherd.
license: MIT
compatibility: Requires a teamcurri GitHub repo, gh, git, and either Switchboard RWX MCP tools or a local rwx CLI (`rwx whoami` works).
metadata:
  author: Aleks Clark
  version: "1.1.0"
  adapted_for: crush-local
---

# PR Shepherd

Open or adopt a pull request in a Curri-owned repository, then keep working until the exact PR head is terminal-clean. This is an active remediation loop: monitor, diagnose, reproduce, fix, test, commit, push, and re-bind every gate after every head change.

When the user explicitly authorizes merge ("merge it", "shepherd and merge", etc.), merge only after the **Merge Authorization Contract** below is fully satisfied. A clean shepherding result without merge authorization means "ready for merge," not "merged."

## When to Use

- The user tells you to **open a PR** in a Curri-owned repository.
- The user tells you to **shepherd a PR**, **watch CI**, or **fix a failing PR**.
- The user explicitly invokes **pr-shepherd**.

Do not use for repositories outside the `teamcurri` GitHub organization or for read-only review requests that prohibit mutations.

## RWX access (MCP primary, CLI fallback)

Prefer Switchboard RWX MCP tools when available. Call them via Switchboard `execute` after `search` (do not invent tool names). Local Crush may also shell out to the `rwx` CLI when MCP is missing, unauthorized, times out, or truncates useful log context.

| Need | Switchboard MCP | Local CLI (`bash`) |
|---|---|---|
| Wait for run | `rwx_wait_for_ci_run` | `rwx results <run-id> --wait` |
| Structured results | `rwx_get_run_results` | `rwx results <run-id> --json` |
| Full task logs | `rwx_get_task_logs` | `rwx logs <run-id> --task <key>` or `rwx logs <task-id>` |
| Tail / head logs | `rwx_tail_logs` / `rwx_head_logs` | download with `rwx logs`, then `tail`/`head` |
| Grep logs | `rwx_grep_logs` | download with `rwx logs`, then `rg`/`grep` |
| Artifacts | `rwx_get_artifacts` | `rwx artifacts …` |

Rules:

1. Always start with structured results (`rwx_get_run_results` or `rwx results --json`), then task-scoped logs.
2. Do not diagnose an RWX failure from the GitHub status description alone.
3. Do not loop identical failing MCP requests. After two hard MCP failures on the same call shape, fall back to the local CLI once; if both paths fail, report **BLOCKED: RWX tooling unavailable**.
4. Never claim green from an empty/partial result object.

See [RWX failure loop](references/rwx-failure-loop.md).

## Scope Guard

Prove ownership from the live GitHub remote, not from the local directory name:

```bash
git rev-parse --show-toplevel
git remote get-url origin
gh repo view --json nameWithOwner,owner,defaultBranchRef
```

Require `owner.login == "teamcurri"`. Read the repository's `AGENTS.md` and nested instructions before changing, committing, pushing, or choosing local gates. Preserve repository PR-title requirements such as `#autodeploy` when specified locally.

Refuse to proceed when:

- the remote is not `teamcurri/*`;
- the user has not authorized push/PR mutation;
- the current worktree contains unrelated changes;
- GitHub credentials are unavailable, and neither RWX MCP nor local `rwx` works;
- another actor moves the PR head and the resulting diff cannot be safely adopted.

## Terminal-Clean Contract

Bind every claim to one **exact head SHA**. The PR is complete only when all conditions hold simultaneously for the current head:

1. GitHub status `RWX: ci.yml (pull request)` exists and is `success`.
2. GitHub status `RWX: playwright-e2e.yml (pull request)` exists and is `success` when the repository emits that check. If the check never appears for this repo/PR type after CI completes, treat it as N/A only when `ci.yml` is green and the repo docs do not require Playwright for this path; otherwise missing is a blocker.
3. GitHub status `curri/pr-review` exists and is `success`.
4. The generated PR-body review block is bound to the exact head (`<!-- generated_for: <full exact head> -->` or equivalent marker) and reports **Confidence Score: 5/5** (or `5/5` in the confidence section).
5. The same generated block has **`Findings (0)`** / empty Findings (no P0, P1, P2, Important, or Suggestion items remaining).
6. An `agents-pipeline[bot]` review for the exact head is present. Prefer state `APPROVED`. `COMMENTED` alone is **not** enough to merge when findings or unresolved threads remain.
7. GraphQL `reviewThreads` contains **zero unresolved** automated-review threads: every thread authored by `agents-pipeline[bot]` has `isResolved == true`.
8. Every automated-review finding encountered during shepherding has a recorded disposition and is addressed by code, tests, docs, or an evidence-backed thread resolution (with reply + resolve).
9. Re-fetching the PR head still returns the pinned SHA.

### Merge Authorization Contract (stricter — required before any merge)

If the user asked to merge (including "shepherd and merge"), **do not merge** until Terminal-Clean holds **and**:

1. **Confidence Score is exactly 5/5** on the exact-head generated review block. Scores of 4/5 or below block merge even if CI is green.
2. **Findings (0)** on that same block.
3. **Zero unresolved** `agents-pipeline[bot]` review threads (GraphQL `isResolved == true` for all of them).
4. Every inline/body automated finding from the shepherding session is fixed on the current head **or** resolved with a reply that cites the fixing commit/test and explains why no code change was required.
5. Required CI contexts for this repo are `success` on the exact head (at minimum `RWX: ci.yml (pull request)` and `curri/pr-review`).
6. `mergeStateStatus` is `CLEAN` (or equivalent: mergeable, no blocking requirements pending).

If confidence is missing from the body, treat as **not 5/5** and keep shepherding (re-trigger review or wait for a fresh exact-head review) rather than merging.

The codeowner check is **optional** for terminal-clean reporting. Any status/check whose context or name contains `codeowner`—including `agents/codeowner-substitute`—may be missing, pending, failed, or skipped without blocking the terminal-clean *report*, but if it is a required GitHub branch-protection check and is failing, merge will fail—fix or escalate rather than force-merge.

Required contexts are fail-closed: "missing" is not "not applicable" unless the repo docs explicitly say so for that workflow. Prefer reporting a blocker over weakening this contract.

## Procedure

### 1. Open or adopt the PR

For a new PR:

1. Confirm the feature branch is not the default branch and contains only the requested change.
2. Run the repository's pre-push gates from `AGENTS.md`.
3. Commit and push the feature branch.
4. Create the PR with the repository-required title tags and a real test plan.

For an existing PR:

```bash
gh pr view <number-or-url> \
  --json number,url,state,baseRefName,headRefName,headRefOid,isDraft,mergeable,mergeStateStatus
```

Require an open PR and a local worktree on its head branch, or create an isolated worktree for that branch. Never mutate the default branch.

**Completion:** an open PR exists and local `HEAD` equals its current `headRefOid`.

### 2. Pin the head and discover all gates

```bash
PR=<number>
HEAD_SHA=$(gh pr view "$PR" --json headRefOid -q .headRefOid)
test "$(git rev-parse HEAD)" = "$HEAD_SHA"
gh api "repos/{owner}/{repo}/commits/$HEAD_SHA/status"
gh api "repos/{owner}/{repo}/commits/$HEAD_SHA/check-runs"
```

From the combined status, capture the two RWX run URLs/IDs for:

- `RWX: ci.yml (pull request)`
- `RWX: playwright-e2e.yml (pull request)`

Also capture `curri/pr-review` and any codeowner state. Do not let a successful codeowner status compensate for a missing required status.

See [gate binding](references/gate-binding.md) for exact GitHub and review-thread queries.

**Completion:** the exact head, both RWX run IDs, review status, and optional codeowner state are recorded.

### 3. Wait efficiently, then diagnose failures

Use blocking waits rather than frequent ad hoc polling.

**MCP (preferred):**

```text
rwx_wait_for_ci_run(run_id=<ci-run-id>)
rwx_wait_for_ci_run(run_id=<playwright-run-id>)
rwx_get_run_results(run_id=<failed-run-id>)
```

**CLI fallback:**

```bash
rwx results <ci-run-id> --wait
rwx results <playwright-run-id> --wait
rwx results <failed-run-id> --json
```

When an RWX or Playwright run fails, diagnosis must use RWX task evidence (MCP or CLI), never GitHub prose alone. Structured results first, then task-scoped logs:

**MCP:**

```text
rwx_get_run_results(run_id=<run-id>)
rwx_get_task_logs(run_id=<run-id>, task_key=<failed-task-key>)
rwx_tail_logs(id=<run-id>, task_key=<failed-task-key>, lines=50)
rwx_grep_logs(id=<run-id>, pattern=<focused-error-pattern>, context=3)
```

**CLI fallback:**

```bash
rwx results <run-id> --json
rwx logs <run-id> --task <failed-task-key> --output /tmp/rwx-<run-id>-<task>.log
# then inspect with tail/rg as needed
```

See [RWX failure loop](references/rwx-failure-loop.md) for task and log discipline.

**Completion:** each failed required run has a specific failing task, actionable error, and local reproduction plan.

### 4. Build the automated-review finding ledger

Fetch all three review surfaces for the pinned head:

1. PR body generated block from `<!-- generated_for: ... -->` through `<!-- curri:pr-review:end -->`.
2. REST review events and inline comments from `agents-pipeline[bot]`.
3. GraphQL `reviewThreads`, including `isResolved`, comment author, path, line, and URL.

Track every automated finding, not only P0/P1. The final contract is strict `Findings (0)` **and** `Confidence Score: 5/5`: P0, P1, P2, Important, Suggestion, body-only findings, inline findings, and older unresolved automated threads all require a disposition. A 4/5 confidence with zero findings is still **not** merge-ready under the Merge Authorization Contract.

A finding is addressed only when:

- the underlying code/docs/tests are corrected or evidence proves no change is needed;
- the correction is committed and pushed;
- the current exact-head generated block no longer contains the finding;
- any corresponding automated review thread is resolved with evidence.

Never resolve a thread merely to make the count zero. Human comments are outside the automated-review ledger unless the user asks to include them.

**Completion:** every extant automated finding has an ID, source, path/line when present, proposed fix, and open/addressed state.

### 5. Fix, test, commit, and push

For each CI failure or finding:

1. Reproduce the defect locally using the narrowest real repository gate.
2. For behavior changes, write or identify a failing test before changing production code.
3. Implement the smallest complete fix.
4. Run the focused gate, then the repository-required pre-push suite.
5. Inspect `git diff` for scope and secrets.
6. Commit with a focused conventional message and push the PR branch.

After every push:

```bash
git push
NEW_HEAD=$(git rev-parse HEAD)
test "$(gh pr view "$PR" --json headRefOid -q .headRefOid)" = "$NEW_HEAD"
```

The new head invalidates all prior green CI and review evidence. Clear terminal claims, retain the finding-history ledger, re-discover run IDs, and return to Step 2.

Do not stop after one remediation round. Continue until the Terminal-Clean Contract holds, or report a concrete external blocker that cannot be fixed in the repository.

**Completion:** every local fix is committed/pushed and gate evidence is bound only to the resulting exact head.

### 6. Reconcile review threads with evidence

When a pushed head demonstrably addresses an automated inline finding:

1. Reply with the exact head SHA and the fixing file/test evidence when repository policy permits.
2. Resolve only the corresponding automated thread.
3. Re-fetch `reviewThreads` and verify `isResolved == true`.
4. Do not resolve unrelated, human-authored, or unproven threads.

A fresh review may mint new findings after old ones are resolved. Add them to the ledger and return to Step 5. `APPROVED` alone is insufficient while the body has findings or an automated thread remains unresolved.

**Completion:** zero unresolved automated threads remain, without hiding unaddressed findings.

### 7. Perform the final exact-head bind

Re-fetch, in one final pass:

- PR head SHA;
- combined commit statuses;
- both RWX result records;
- exact generated body block;
- exact-head reviews;
- all review threads;
- optional codeowner state.

Require the full Terminal-Clean Contract. If any required evidence is stale, pending, missing, or bound to another SHA, continue monitoring or remediation.

Final verdicts:

- **TERMINAL CLEAN** — all required CI/review/findings conditions pass on the exact head, including Confidence 5/5 and Findings (0).
- **NOT CLEAN** — terminal evidence exists but one or more required conditions fail (including confidence &lt; 5/5 or unresolved bot threads).
- **BLOCKED** — a required external service/tool/credential is unavailable, or the head cannot be safely adopted.

Do not merge by default. Report the PR as ready for merge and wait for explicit merge direction.

When merge was requested: only after Merge Authorization Contract holds, run `gh pr merge` (squash unless the user/repo requires otherwise), verify `state == MERGED`, and report the merge commit.

**Completion:** one exact SHA has complete, mutually consistent CI, review, Confidence 5/5, and zero-finding evidence.

## Pitfalls

1. **Green status on an old head.** Any push invalidates every previous result.
2. **Only checking top-level RWX.** Playwright is a separate required RWX workflow and run ID.
3. **Diagnosing RWX through GitHub prose.** Use RWX MCP or local `rwx` task results and logs for failures.
4. **Treating approval as Findings(0).** `APPROVED`, exact body findings, confidence score, and unresolved threads are independent gates.
5. **Merging on 4/5 confidence.** Merge requires **5/5** even when findings are empty and CI is green.
6. **Ignoring older unresolved automated threads.** "Extant" spans the whole PR, not only the latest summary body.
7. **Resolving without evidence.** Thread state is not a substitute for a fix.
8. **Severity filtering.** This workflow requires all findings addressed, including P2 and Suggestions.
9. **Codeowner false blocker.** Codeowner is optional for the report; still respect branch protection on merge.
10. **Missing required context called N/A.** `RWX: ci.yml` and `curri/pr-review` must exist and pass unless repo docs say otherwise.
11. **Stopping after a fix push.** Re-bind CI, review, Findings(0), Confidence 5/5, and threads on the new head.
12. **Automatic merge without authorization.** Do not merge unless the user asked; when they did, still enforce Merge Authorization Contract.
13. **Merging with open bot comments.** Unresolved `agents-pipeline` threads always block merge.
14. **Head moved by another actor.** Fetch, inspect the new delta, and re-bind; never overwrite it with force-push.
15. **Skipping CLI fallback.** If Switchboard RWX MCP flakes, use local `rwx` before declaring blocked.

## Verification

Report:

- repository and PR URL;
- exact terminal head SHA;
- RWX CI run ID/URL and success;
- RWX Playwright run ID/URL and success;
- `curri/pr-review` run URL and success;
- exact `generated_for` SHA, **Confidence Score 5/5**, `Findings (0)`, and exact-head review ID/state;
- automated findings addressed, with fixing commits/tests;
- unresolved automated thread count: **zero**;
- codeowner state labeled optional/non-gating (unless branch protection blocked merge);
- final verdict: **TERMINAL CLEAN**, **NOT CLEAN**, or **BLOCKED**;
- if merge was requested: whether Merge Authorization Contract passed and the merge commit SHA, or why merge was withheld.
