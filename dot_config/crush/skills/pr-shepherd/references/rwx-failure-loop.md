# RWX failure remediation loop

Use this reference when either required RWX workflow fails.

Prefer Switchboard RWX MCP tools. Fall back to the local `rwx` CLI when MCP is unavailable, unauthorized, times out, or truncates needed log context. Do not diagnose from GitHub status prose alone.

## Required tool order

### 1. Wait for terminal state

**MCP:**

```text
rwx_wait_for_ci_run(run_id=<run-id>, timeout_seconds=1800)
```

**CLI:**

```bash
rwx results <run-id> --wait
```

### 2. Get structured failures

**MCP:**

```text
rwx_get_run_results(run_id=<run-id>)
```

**CLI:**

```bash
rwx results <run-id> --json
# or LLM-oriented default text:
rwx results <run-id>
```

Capture failed task keys before reading logs.

### 3. Read the failing task by key

**MCP:**

```text
rwx_get_task_logs(run_id=<run-id>, task_key=<task-key>)
rwx_tail_logs(id=<run-id>, task_key=<task-key>, lines=50, offset=0)
```

**CLI:**

```bash
rwx logs <run-id> --task <task-key> --output /tmp/rwx-<run-id>-<task-key>.log
tail -n 80 /tmp/rwx-<run-id>-<task-key>.log
```

### 4. Search only when task results do not identify the cause

**MCP:**

```text
rwx_grep_logs(id=<run-id>, pattern=<specific-pattern>, context=3, page=1)
```

**CLI:**

```bash
rg -n -C3 '<specific-pattern>' /tmp/rwx-<run-id>-<task-key>.log
```

Follow pagination when MCP reports more pages. Do not search broad `error|failed` patterns across an entire large run until task-scoped evidence is exhausted.

## Failure classes

- **Product/test failure:** reproduce the named test or build command locally; fix with a regression test.
- **Lint/type failure:** run the exact repository lint/type target; do not substitute a narrower compiler invocation.
- **Playwright failure:** identify the project/spec/browser and failing assertion from the Playwright RWX run; reproduce the exact spec locally before changing product code.
- **Transient infrastructure failure:** use RWX evidence and prior-run comparison. Retry only when repository policy permits and evidence shows infrastructure rather than product failure. A retry never converts an unexplained failure into green evidence.
- **Empty/partial RWX result:** inspect task-specific logs. Do not infer success from an empty result object.

## After a fix

Run the focused local reproduction, repository pre-push gates, commit, and push. The new SHA creates new RWX run IDs. Never carry the old run's success or failure state onto the new head.

## Blocked criteria

Report **BLOCKED: RWX tooling unavailable** only when both paths fail:

1. Switchboard RWX MCP calls are unavailable, unauthorized, or repeatedly time out; and
2. Local `rwx` CLI is missing, unauthenticated (`rwx whoami` fails), or cannot fetch the run/logs.

Do not guess from the GitHub status summary and do not claim the failure is transient without task-level evidence.
