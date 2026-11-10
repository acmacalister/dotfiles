# Observability Audit

Goal: when something breaks in production, an engineer (or agent) can answer
"what happened, to which request/run, and why" from logs, metrics, and traces
without attaching a debugger. **Use the stack the project already has**
(slog, OpenTelemetry, Datadog, Sentry, Prometheus). Never introduce a new
vendor SDK in a cleanup without approval.

**Observability names are contracts.** Log message text, log keys, metric
names, metric labels, and span names may feed dashboards, monitors, alerts,
and saved searches. Do not rename them in a cleanup. Add new fields; flag
inconsistent names in the report for a coordinated migration.

## Logging

- **One structured logger: `log/slog`.** Flag `log.Printf`, `fmt.Println`
  for diagnostics, and bespoke logger interfaces that wrap slog for no
  reason. Keep `fmt.Print*` for CLI user output.
- **Key/value pairs, not interpolation.** `slog.Info("Run finished", "run_id", id, "duration", d)`
  not `slog.Info(fmt.Sprintf("run %d finished in %s", id, d))`.
- **Consistent keys.** Pick one spelling per concept (`error` vs `err`,
  `run_id` vs `runID`) and follow what dashboards use. Define frequently
  used keys as constants or helper attrs when the codebase has many call
  sites (`slog.String(logkey.RunID, id)`).
- **Use `*Context` variants and a context-aware handler** so request IDs,
  trace/span IDs, and run IDs attach automatically. Flag request-scoped code
  that logs without the context it has.
- **Log or return, not both.** An error should be logged once, at the
  boundary that handles it (handler, worker loop, main). Intermediate layers
  wrap and return. Flag `slog.Error(...); return err`.
- **Levels mean something.** Error: needs a human. Warn: degraded but
  handled. Info: lifecycle events (start, stop, job finished). Debug:
  everything else. Flag Error logs for expected conditions (not found,
  validation, client cancellations: `errors.Is(err, context.Canceled)`).
- **Never log secrets or PII**: tokens, Authorization headers, cookies,
  webhook signatures, passwords, full request bodies, DSNs with passwords.
  Use `slog.LogValuer` on sensitive types to redact by construction.
- **Background work logs its lifecycle**: goroutines, cron jobs, queue
  workers log start, finish, duration, and outcome, and recover panics with
  a logged stack (only where a panic must not kill the process).
- **Hot paths**: avoid building expensive attributes when the level is
  disabled (`logger.Enabled(ctx, slog.LevelDebug)`, `LogValuer`).
- Follow the project's message style (crush enforces capitalised messages
  via a lint script).

## Errors as observability

- Wrap errors with what was being attempted and the identifying input:
  `fmt.Errorf("finding flow %d: %w", id, err)`. Avoid "failed to" prefixes
  stacking up (`failed to x: failed to y: failed to z`).
- Errors returned to clients must not leak internals (SQL, stack, paths);
  log the detail server-side with a correlation ID and return the ID.
- Error reporting tools (Sentry etc.) should receive errors once, at the
  boundary, with request/run tags.

## Metrics

Services: RED per endpoint/job type (Rate, Errors, Duration). Resources and
pools: USE (Utilization, Saturation, Errors). Flag:

- Queues, worker pools, channels, and connection pools without saturation
  visibility (depth, drops, wait time). crush's pubsub broker exposes drop
  counters for this reason.
- Unbounded label cardinality (user IDs, URLs with IDs, error strings as
  labels).
- Retries without a retry counter.
- External calls (HTTP, DB, LLM, Slack, GitHub) without latency and error
  metrics or spans.

## Tracing

- Spans at port boundaries: inbound requests, outbound adapters (DB, HTTP,
  queues). Prefer a decorator around the port or middleware over sprinkling
  span code through domain logic.
- Propagate `context.Context` everywhere; flag `context.Background()` /
  `context.TODO()` inside request paths (they break cancellation and trace
  propagation). `context.WithoutCancel(ctx)` keeps values (trace IDs) for
  intentionally detached work.
- Propagate trace context across async hops (NATS/queue headers, job args).

## Operability

- Health (`/healthz`) and readiness (`/readyz`) endpoints that check real
  dependencies for readiness but not for liveness.
- Graceful shutdown: `signal.NotifyContext`, `http.Server.Shutdown`, workers
  drain on context cancel, with a bounded timeout.
- `net/http/pprof` only on an internal/admin listener or behind auth, never
  on the public mux.
- Build info (`debug.ReadBuildInfo`, version/commit) logged at startup and
  exposed on a version endpoint.
- Config logged at startup with secrets redacted.

## Audit procedure

1. Grep: `log\.Print|fmt\.Print|slog\.|logger\.` to map logging style.
2. List every external call site (`http.Client`, `sql`, SDK clients) and
   check each has timeout, error wrapping, and a metric/span (or a decorator).
3. List every goroutine/worker (`go func`, `.Go(`, `errgroup`) and check
   lifecycle logs, panic handling, shutdown, and saturation metrics.
4. Check request middleware for request ID, access logging, panic recovery,
   and trace extraction.
5. Report gaps with a concrete proposal per gap; implement additive ones
   (new fields, new metrics, new spans) that do not rename existing names.
