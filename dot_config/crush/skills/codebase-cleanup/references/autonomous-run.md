# Autonomous Weekly Run

How the skill runs unattended on a schedule (cron flow, CI job, `crush run`)
and finishes without a human: one run, one PR, shepherded to review-ready,
with a report. Nobody should need to check on it mid-run.

## Operating principles

- **Never ask.** There is no one to answer. Every decision has a default
  below. Anything that would need a human decision becomes a recorded
  finding in the PR body and the tracking issue, not a question.
- **Never stop early for perceived difficulty.** Stop only for a hard
  external blocker (no git/gh credentials, CI tooling down after the
  documented fallbacks, base branch red and not fixable within the run).
  Even then, finish every unblocked step and write the report.
- **Never merge.** The output is a review-ready PR. Merging is a human
  decision unless the invocation explicitly says to merge.
- **Never weaken the contract to make progress.** Skipping a risky change
  is always acceptable; shipping one is not.
- **Bounded output.** A weekly PR a human can review in under 30 minutes is
  worth more than a giant one that sits. Defaults below.

## Run identity and state

- Branch: `chore/codebase-cleanup-YYYY-MM-DD` (run date, UTC).
- Label: `codebase-cleanup` (create it if missing:
  `gh label create codebase-cleanup --color 0E8A16 --description "Automated weekly cleanup" || true`).
- State lives in the PR body, not in the repo, inside a marker block that
  the next run parses:

```html
<!-- codebase-cleanup:state
{"version":1,"run":"2026-11-07","base_sha":"<sha>",
 "audited":["http","slack","postgres"],
 "queue":["nativeagent","durable","remotedev"],
 "deferred":[{"id":"L1","title":"Linear OAuth routes unauthenticated","first_seen":"2026-11-07"}],
 "skipped":[{"id":"GOFIX","reason":"356 files; shipped as separate PR #1052"}]}
-->
```

Find the previous run:

```bash
gh pr list --state all --label codebase-cleanup --limit 5 \
  --json number,state,headRefName,mergedAt,body,url
```

Use the newest PR's state block. If none exists, this is the first run:
build the queue from top-level packages ordered by risk (HTTP/webhook and
auth adapters, stores, concurrency-heavy workers first), then by size.

## Open PR policy

Check for an open `codebase-cleanup` PR first.

| Situation | Action |
|---|---|
| No open cleanup PR | Normal run: new branch from the latest base, new PR. |
| Open PR, not yet review-ready (CI red, findings, < 5/5) | Adopt it: check out its branch, merge the latest base into it (no force-push), fix, re-shepherd. Do not start new cleanup work in this run. |
| Open PR, review-ready, waiting for humans | Keep it fresh: merge the latest base in if it has conflicts or is behind by more than a week, re-run verification, re-shepherd. Do not stack a second cleanup PR. Report "waiting for review since <date>". |
| Open PR older than 3 weeks | Same as above, and flag it at the top of the report. |

At most one open cleanup PR and one open mechanical-modernization PR
(`chore/go-fix-YYYY-MM-DD`, also labeled) at any time.

## Size budget per run

- Hand-written changes: aim for at most ~800 changed lines (excluding
  deletions of dead code, generated files, and new test files), and at most
  ~6 concerns. Stop starting new batches when the budget is reached and
  carry the rest in the state `queue` or `deferred`.
- Mechanical `go fix` output never goes in the cleanup PR. If `go fix -diff`
  is non-empty and no go-fix PR is open, open one per run with the fixers
  that apply (excluding `omitzero`), capped at ~150 files; take the
  next-highest-churn fixers first next week if capped.
- Soft time budget: stop starting new batches about 4 hours in, then
  shepherd and report.

## Weekly sequence

1. **Preflight** (abort with a report only if these fail):
   - Prove the remote/org (`gh repo view`), credentials (`gh auth status`),
     and that the worktree is clean. Work in a fresh worktree off the base
     branch so a human's checkout is never touched.
   - Toolchain: if the repo pins a local Go version (Taskfile/CI checks
     `GOTOOLCHAIN=local go version`) and the runner differs, install it with
     `go install golang.org/dl/goX.Y.Z@latest && goX.Y.Z download` and put
     its `bin` first on `PATH` for the run.
   - Read the previous run's state block and apply the open PR policy.
2. **Baseline** with [`scripts/safe-env.sh`](../scripts/safe-env.sh)
   wrapping every test command. Start every full or cluster-suite run on a
   fresh database (`safe-env.sh --stop-db` first): suites that leave rows
   behind fail on rerun against the same database, and that looks exactly
   like a regression. Record pre-existing failures (rerun each
   once). Pre-existing failures are not blockers; they are the first
   candidates to fix if they are hermeticity or compile problems.
3. **Sweep** with `scripts/audit.sh` (also wrapped). Compare against the
   previous run where possible (new deadcode items, new lint issues, new
   vulns) and prioritize regressions since `base_sha`.
4. **Diff-scoped audit**: every package changed since the previous run's
   `base_sha` (`git diff --name-only <base_sha>..HEAD -- '*.go'`) gets the
   full category audit. New drift is cheapest to fix while it is fresh.
5. **Rotating deep audit**: pop the next 2-4 packages from `queue` (more
   if they are small) for a full category audit. Append audited packages to
   `audited`; when `queue` empties, rebuild it from the tree.
6. **Architecture guard** (see "Enforcing the architecture" in
   [architecture.md](architecture.md)): ensure the import-rule test exists,
   shrink its allowlist where a violation can be fixed safely, and fix any
   new violation introduced since the last run.
7. **Fix** in batches in the SKILL.md order, using worktree subagents for
   parallel, non-overlapping scopes (brief template below). Merge their
   branches with cherry-pick, then run the full verification.
8. **Docs review**: a separate read-only or doc-only subagent verifies every
   new or changed doc comment and doc file against the code. The PR
   reviewer is strict about inaccurate docs.
9. **PR**: push, open (or update) the PR with the report as the body and
   the state block at the end. Then shepherd it with `pr-shepherd` (Curri
   repos) or the repo's equivalent until terminal-clean: CI green, review
   5/5 with zero findings, zero unresolved bot threads. Address every
   finding by fixing or by an evidence-backed reply; the reviewer usually
   runs at most three passes.
10. **Tracking issue**: keep one open issue titled
    `Codebase cleanup: findings that need a decision` (label
    `codebase-cleanup`). Update its body each run with the `deferred` list
    (id, severity, location, why it needs a human, first seen). Close items
    that a human resolved. Create it only when there is at least one item.
11. **Clean up**: remove worktrees and local branches, stop the disposable
    Postgres (`safe-env.sh --stop-db`) and any background services started.
12. **Final report** (the run's last message; schedulers may forward it):
    PR URL and verdict, what changed, what was deferred and why, tracking
    issue URL, pre-existing failures, tooling problems, and next week's
    queue.

## No-op runs

If the sweep and audits find nothing safe to change and there is no open
PR to maintain, do not open a PR. Update the tracking issue if needed and
report "clean: no changes" with the tool summary. A clean week is a valid
outcome.

## Subagent brief template

Write this to a temp file and point every write subagent at it, plus a
task-specific prompt naming its worktree and exact scope:

```markdown
# Shared instructions for cleanup subagents (<repo>)

You work ONLY in your own git worktree: <WORKTREE>. Never touch other
checkouts. Never push. Never ask questions; skip anything you cannot do
safely and list it in your report.

Run every go/task command through:
  <SKILL_DIR>/scripts/safe-env.sh --db -- <command>
(it strips credentials and points DATABASE_URL at a disposable Postgres).

Read <SKILL_DIR>/SKILL.md "The Non-Breaking Contract" before editing.
Follow surrounding code style. No narrating comments. No em dashes. slog
key/value pairs with the keys nearby code uses. No new dependencies.

Before each commit: gofmt on your files, go vet and go test on touched
packages, go build ./... . Check `git diff --cached --stat` so earlier
staged changes (e.g. from `git mv`) land in the commit they belong to.
Every commit must build on its own. Run the repo lint command once at the
end.
Known pre-existing failures: <list>.

Commit with focused messages explaining the benefit (first line < 72
chars, plain sentence) and the repo's required trailers: <trailers>.

Report: commits (sha + subject), files per commit, exact verification
commands and results, skipped items with reasons. Under 80 lines.
```

Give parallel subagents non-overlapping file scopes (by category or by
package). Doc-only work should create new files (`doc.go`) rather than edit
files other agents are changing.

## Scheduling

Any scheduler that can start an agent with this skill available works: an
Overmind cron flow, a CI cron job running `crush run`, or a local cron
entry. The prompt only needs the repo and, optionally, the base branch:

```text
Run the codebase-cleanup skill on teamcurri/agents (base: master).
```

The runner needs gh credentials that can push branches, open PRs, and edit
issues; Docker for the disposable database; and enough wall-clock time for
CI plus up to three automated review passes (plan for 4-6 hours). Run it
early in the week so the PR is reviewed while the changes are fresh.
