---
name: codebase-cleanup
description: Use when asked to clean up, tidy, refactor, modernize, or audit a Go codebase, or when invoked on a schedule (weekly cleanup, cron flow, "run codebase-cleanup"). Runs unattended end to end, from tool sweep through fixes to a shepherded review-ready PR, covering architecture drift, dead code, duplication, observability, security, performance, tests, and docs, without introducing breaking changes.
license: MIT
compatibility: Go modules, git, gh (authenticated), Docker (for the disposable test database), network access for `go run tool@latest`. Go 1.26+ toolchain for `go fix` modernizers. Uses the pr-shepherd skill for teamcurri repos.
metadata:
  author: Austin
  version: "0.2.0"
---

# Go Codebase Cleanup

Keep a Go codebase clean, safe, tested, and easy for humans and agents to
work in, **without breaking anything**, on a weekly cadence with no human in
the loop. The target style is Ben Johnson's
[Standard Package Layout](https://medium.com/@benbjohnson/standard-package-layout-7cdbc8391fc1)
read as ports and adapters, the [Go proverbs](https://go-proverbs.github.io/),
the spirit of [Effective Go](https://go.dev/doc/effective_go), and modern
standard-library Go. Reference codebases: `charmbracelet/crush`
(`~/code/crush`) and `~/code/chapterchamp`.

`SKILL_DIR` below means this skill's directory
(`~/.config/crush/skills/codebase-cleanup`).

## Run Mode: Autonomous by Default

Every invocation runs to completion without asking questions:

1. Preflight, baseline, and automated sweep.
2. Audit: everything changed since the last run, plus the next packages in
   the rotation.
3. Fix in small verified batches, including architecture enforcement.
4. Open (or maintain) one PR, then shepherd it until it is review-ready:
   CI green, automated review 5/5 with zero findings, and no unresolved
   bot threads.
5. Record deferred decisions in the tracking issue and write the final
   report.

**Do not stop to ask, and do not stop because the work is large.** Make
every decision from the defaults in this skill and in
[references/autonomous-run.md](references/autonomous-run.md). A change that
would need a human is skipped and recorded as a deferred finding, never
asked about. Stop early only for a hard external blocker (credentials, CI
tooling down after fallbacks). Even then, finish every unblocked step and
report. **Never merge** unless the invocation explicitly says to.

Two exceptions:
- **Audit only:** if the user explicitly asks only for an audit or report,
  skip phases 4-5.
- **Interactive:** if a user is present and explicitly asks to approve
  changes, list `approval` items for them before implementing.

Neither exception is the default.

Read [references/autonomous-run.md](references/autonomous-run.md) before
starting. It defines the run state, the open-PR policy, the size budget,
the weekly sequence, no-op runs, and the subagent brief.

## The Non-Breaking Contract

A change that violates this is never made in an unattended run. Record it
as a deferred finding instead.

**Must not change:**

1. **Public Go API** of any package another module can import. For library
   modules, snapshot and diff it:
   ```bash
   go run golang.org/x/exp/cmd/apidiff@latest -m -w /tmp/base.api "$(go list -m)"   # before
   go run golang.org/x/exp/cmd/apidiff@latest -m /tmp/base.api "$(go list -m)"      # after; nothing incompatible
   ```
   In application modules, exported identifiers may change if every caller
   in the module is updated and `gh search code` finds no other repo
   requiring the module.
2. **Wire formats:**
   - HTTP routes, methods, status codes for valid requests, and headers.
   - JSON field names and omit behavior (`omitempty` -> `omitzero` is a
     wire change).
   - Protobuf, NATS subjects, queue job kinds and args, webhook payloads,
     and Slack/Block Kit output.
3. **Persistence:** schema, indexes, applied migrations (never edit them),
   data at rest, cache keys. Additive store methods are fine; a new
   migration is not a cleanup.
4. **Operator interfaces:** CLI flags and commands, env vars, config keys
   and defaults, and Taskfile/Makefile targets that people or CI call.
5. **Observability names:** log messages and keys, metric names and labels,
   span names, Sentry tags. Adding new ones is fine.
6. **Floors:** the `go` directive and major versions of dependencies.
   Patch and minor bumps that fix a reachable vulnerability are allowed.
7. **Semantics:** ordering, retries, idempotency, delivery guarantees,
   timeouts, concurrency limits, and error types or messages that callers
   match on.
8. **Access control:** adding authentication or authorization to a route
   changes who can call it. Record it as a deferred finding with severity;
   do not apply it unattended.

**Allowed security hardening:** rejecting input no legitimate caller sends
is allowed when the limit is far above real traffic and a test proves it.
Examples: body size caps well above real payloads, an empty secret that
must never verify, constant-time compares.

**Bugs:** fix one only as its own commit with a regression test that fails
first, and say so in the PR. If the fix changes valid behavior, defer it.

**Add, don't rewrite.** The safest wins are:
- new tests, logs, metrics, and docs
- deletion of provably dead code
- enforcement tests

Package moves and large rewrites are deferred proposals.

## Phase 0: Preflight and Baseline

1. Follow the preflight in [autonomous-run.md](references/autonomous-run.md):
   - Prove the remote, gh auth, and a clean fresh worktree.
   - Match the pinned toolchain.
   - Read the previous run's state.
   - Apply the open-PR policy.
2. Read the project's agent and style docs: `AGENTS.md`, `CLAUDE.md`,
   `CRUSH.md`, `CODE_STYLE.md`, `CONTRIBUTING.md`, the docs index,
   `.golangci.yml`, `Taskfile.yml`/`Makefile`, and CI config (`.github/`,
   `.rwx/`). **Project rules override this skill.**
3. Record the exact verification commands, including tagged suites, and the
   `go` directive.
4. **Every test command goes through `SKILL_DIR/scripts/safe-env.sh --db --`.**
   - It drops every environment variable except an allowlist, so
     credentials never reach tests.
   - It points `DATABASE_URL` at a disposable local Postgres container.
   - Developer and runner shells often hold production URLs and tokens.
   - Tests that depend on ambient env vars are a hermeticity finding.
5. Run the full verification on the base branch.
   - Rerun each failure once and record the ones that remain as
     pre-existing.
   - Pre-existing failures are not blockers. Compile errors and
     hermeticity failures are the first things to fix.
   - If the base does not build at all, the run's only job is to fix that
     (smallest safe change) or report it.

## Phase 1: Automated Sweep

```bash
SKILL_DIR/scripts/safe-env.sh --db -- SKILL_DIR/scripts/audit.sh <module-dir> [out-dir]
# env: LINT_CMD="task lint"  TAGS="..."  SKIP_TESTS=1  SKIP_NETWORK=1
# safe-env.sh passes LINT_CMD, TAGS, SKIP_TESTS and SKIP_NETWORK through
```

The script never edits files. It runs:
- build, vet, `go vet -tags <tag>` for every build tag in the repo, and
  `go mod tidy -diff`
- lint, `go fix -diff`, staticcheck, deadcode, govulncheck, and gosec
- an import-graph dump, marker greps, and coverage

Results go to one file per tool plus `SUMMARY.txt`. `TOOL-ERROR` lines
mean the tool could not load the code; fix the tool rather than trusting
its output. Tool output is a lead, not a verdict: triage every item.
Prioritize regressions since the previous run's `base_sha`.

## Phase 2: Audit

Scope:
- All packages changed since the last run (full audit).
- The next 2-4 packages from the state `queue` (rotating deep audit).
- Repo-wide items from the sweep.

Fan out **read-only** subagents per category or package with the reference
path, the scope, this contract, and the ledger format. Every claim must be
verified by reading the code.

| Category | Reference | Core questions |
|---|---|---|
| Architecture | [architecture.md](references/architecture.md) | Root package dependency-free? Adapters importing each other? Business logic in handlers, SQL, or `main`? Is the import-rule test present and its allowlist shrinking? |
| Idioms, modern Go | [modern-go.md](references/modern-go.md), [go-proverbs.md](references/go-proverbs.md) | What would `go fix` change? Which hand-rolled code has a stdlib replacement allowed by the `go` directive? |
| Dead code, DRY | [dead-code-and-dry.md](references/dead-code-and-dry.md) | What is unreachable? Which business rules are duplicated three or more times? |
| Observability | [observability.md](references/observability.md) | Are errors swallowed or logged twice? Is trace context lost in background work? Are queues and external calls measured? |
| Security | [security-and-performance.md](references/security-and-performance.md) | Reachable vulns? Unbounded reads? Unverified or replayable webhooks? Unauthenticated routes? Secrets in logs? |
| Performance | [security-and-performance.md](references/security-and-performance.md) | N+1 queries, per-call compilation, locks held across I/O, unbounded fan-out? Is there evidence? |
| Tests | [testing.md](references/testing.md) | Untested risky packages? Broken tagged suites? Sleep-based or env-dependent tests? |
| Docs, agent ergonomics | below | Do AGENTS.md commands and links work? Do package docs exist and are they accurate? Does the layout doc match the tree? |

**Docs and agent ergonomics checks:**
- **AGENTS.md and README:** every command runs and every link resolves.
- **Layout doc:** every entry exists on disk, and every package is listed.
- **Package docs:** every package has an accurate `// Package x` comment.
  Skip test-only packages and vendored UI kits.
- **Size:** flag files over ~1000 lines and functions over ~80 lines, to
  be split along responsibility lines.
- **Names:** no `util`, `common` or `misc` packages.
- **Generated code:** check that it is not stale (e.g. `task ui:check`).

## Phase 3: Findings Ledger

Track findings in a todo list or a temp file. They are not committed.

| ID | Category | Severity | Location | Finding | Proposed change | Risk class | Evidence |
|---|---|---|---|---|---|---|---|

- **Severity:** critical / high / medium / low / nit.
- **Risk class:**
  - `safe`: behavior-preserving and covered by tests, or tests are added
    first. Implement it this run, within budget.
  - `deferred`: needs a human because it touches the contract, changes
    behavior, adds a dependency, moves packages, or changes access control.
    It goes in the PR body, the state `deferred` list, and the tracking
    issue.
  - `noted`: informational, or a false positive with the reason. It goes
    in the report only.
- **Critical and high security findings** go at the top of the PR body and
  the tracking issue, even when deferred.

## Phase 4: Fix in Batches

Work in this order, one concern per commit:

1. **Behavior-preserving security fixes.**
2. **Tests:**
   - Fix compile failures in tagged suites.
   - Fix hermeticity problems.
   - Add characterization and integration tests before touching
     untested code.
3. **Architecture guard.**
   - Add or maintain the import-rule test (see "Enforcing the
     architecture" in [architecture.md](references/architecture.md)).
   - Fix new violations.
   - Shrink the allowlist.
4. **Dead code removal**, verified against the false-positive checklist and
   all build tags.
5. **Idiom and modern-stdlib changes** written by hand. Mechanical
   `go fix` output goes in its own PR (see autonomous-run.md).
6. **DRY and architecture:**
   - Consumer-side interfaces.
   - Duplicated rules moved into the package that owns them.
   - Decorators for cross-cutting concerns.
7. **Observability.** Add logs for swallowed errors and keep trace context
   with `context.WithoutCancel`. Do not rename anything.
8. **Performance**, with evidence.
9. **Docs** for everything the run changed, plus new or corrected package
   docs and layout docs.

Use worktree subagents for parallel batches with non-overlapping scopes,
following the brief template in autonomous-run.md. Cherry-pick their
commits onto the run branch.

For every batch:
- **Verify:** run the full verification through `safe-env.sh`, plus
  `go test -race` on touched packages and the tagged suites that cover
  them.
- **Self-review the diff:**
  - no unrelated edits
  - no narrating comments
  - no new dependencies
  - no em dashes in source
  - no renamed observability names
- **Commit** with a message that explains the benefit for a reader
  unfamiliar with the code, plus the repo's required trailers.
- **If verification fails** and two or three distinct fixes don't work,
  drop the batch. Record it as `deferred` with the failure, then move on.

Respect the size budget in autonomous-run.md. Carry leftovers in the state
`queue` and `deferred` lists.

## Phase 5: PR, Shepherd, Report

1. **Doc review:** have a separate subagent verify every new or changed doc
   comment and doc file against the code before pushing.
2. **Push and open the PR.** The body contains the report below and ends
   with the state block. Apply the `codebase-cleanup` label. Do not tag for
   autodeploy.
3. **Shepherd until terminal-clean.**
   - Use `pr-shepherd` for teamcurri repos.
   - Re-bind CI, the review score, findings, and threads after every push.
   - Fix every automated finding, or resolve it with a reply that cites
     evidence.
4. **Tracking issue:** update the tracking issue with the deferred list.
5. **Clean up:** remove worktrees and local branches, and run
   `safe-env.sh --stop-db`.
6. **Final message:** end with the report.

Report template (also the PR body, minus the state block):

```markdown
**Security**: changes, plus deferred security findings (always present)
**Architecture**: rule test status, allowlist delta, violations fixed
**Observability / Dead code / Tests / Performance / Docs**: what changed and why
**Deferred (needs a decision)**: id, severity, location, why; link to tracking issue
**Tests run**: exact commands; pre-existing failures (also on base); flakes rerun
**Next run**: packages queued for deep audit
<!-- codebase-cleanup:state {...} -->
```

## Rules of Thumb

- Clear is better than clever; a boring loop beats a clever iterator chain.
- A little copying is better than a little dependency. DRY up knowledge,
  not keystrokes, and wait for three copies.
- Don't add a linter, formatter, or framework the project doesn't use. The
  import-rule test is the one exception: it is a plain Go test.
- Don't sprinkle `//nolint`. Fix the code or explain the exception inline.
- Don't rename for taste. Don't widen visibility; narrow it when safe.
- Delete instead of commenting out.
- Never edit applied migrations, generated files (regenerate them instead),
  or vendored code.
- Prefer a decorator over editing every method of a port.
- When in doubt, skip the change and record it. An unattended run that
  breaks production costs more than a week of mess.
