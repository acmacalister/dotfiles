# Security and Performance Audit

## Security

Run the tools, then read the code; tools miss authorization bugs entirely.

```bash
govulncheck ./...     # reachable known vulnerabilities in deps and stdlib
gosec ./...           # noisy; triage every finding, never blanket-suppress
```

If `govulncheck` reports a reachable vuln, upgrading the dependency is
usually a safe, non-breaking fix (patch/minor). Major-version upgrades go in
the report.

### Checklist

**Injection**
- SQL built with `fmt.Sprintf` / `+`. Every value must be a placeholder.
  Dynamic identifiers (sort columns, table names) must come from an
  allowlist.
- `exec.Command("sh", "-c", userInput)` or untrusted args without `--`
  separation. Prefer `exec.CommandContext` with explicit args.
- `text/template` used for HTML (use `html/template` / templ). `template.HTML`
  casts on user data.
- Untrusted input in log lines without structured logging (log injection).

**Filesystem and network**
- User-controlled paths joined with `filepath.Join` and no containment.
  Use `os.Root` (Go 1.24+) or `filepath.IsLocal` checks.
- Archive extraction without zip-slip protection.
- SSRF: outbound requests to user-supplied URLs without scheme/host
  allowlists or private-range blocking (including redirects).
- `http.Server` without `ReadHeaderTimeout` (Slowloris); `http.Client`
  without `Timeout`; `http.DefaultClient` in production paths.
- Unbounded reads: `io.ReadAll(r.Body)` without `http.MaxBytesReader` /
  `io.LimitReader`; unbounded JSON decoding of request bodies.
- `InsecureSkipVerify: true`, `MinVersion` below TLS 1.2.

**AuthN/AuthZ**
- Handlers that load resources by ID without checking the caller owns or
  may access them (IDOR). Check every route, not a sample.
- Webhook endpoints (Slack, GitHub, Sentry, Stripe) must verify signatures
  with `hmac.Equal` / `subtle.ConstantTimeCompare` and reject stale
  timestamps (replay).
- Secrets compared with `==`.
- CSRF on cookie-authenticated mutating routes (`http.CrossOriginProtection`,
  Go 1.25+).
- JWT validation: algorithm pinned, audience and issuer checked, expiry
  enforced.

**Secrets and crypto**
- Hardcoded tokens, keys, DSNs (also in tests and `testdata/`).
- Secrets in logs, error messages, panics, or JSON responses
  (`json:"-"` on secret fields; `LogValuer` redaction).
- `math/rand` for tokens, IDs, or nonces (use `crypto/rand`,
  `rand.Text()` in Go 1.24+).
- MD5/SHA1 for anything security-relevant; custom crypto.

**Concurrency and resources**
- Data races: run `go test -race ./...` on the packages you touch.
- Goroutine leaks on request paths (missing `ctx.Done()` selects, unbuffered
  sends with no receiver after timeout).
- Missing `defer rows.Close()` / `resp.Body.Close()` (linters: `bodyclose`,
  `rowserrcheck`, `sqlclosecheck`).

**Supply chain**
- Unused or abandoned dependencies (`go mod tidy`, check last release).
- `replace` directives pointing at forks or local paths left in `go.mod`.

Security findings that require behavior changes visible to clients
(rejecting previously accepted input, new auth requirements) are not
"non-breaking"; fix them only with approval, but always report them first
and prominently.

## Performance

**Measure first.** No performance change without evidence: a benchmark, a
profile, `EXPLAIN (ANALYZE, BUFFERS)`, or production telemetry. "Clear is
better than clever" wins when the gain is unmeasured.

```bash
go test -run '^$' -bench BenchmarkX -benchmem -count 10 ./pkg > old.txt
# change
go test -run '^$' -bench BenchmarkX -benchmem -count 10 ./pkg > new.txt
go run golang.org/x/perf/cmd/benchstat@latest old.txt new.txt
go test -cpuprofile cpu.out -memprofile mem.out -bench . ./pkg
go tool pprof -top cpu.out
```

Write benchmarks with `b.Loop()` (Go 1.24+). Include the benchstat output in
the PR description.

### Checklist

**Database (usually the biggest win)**
- N+1 queries: a query inside a loop over rows. Batch with `= ANY($1)` /
  `IN`, joins, or a dataloader.
- `SELECT *` on wide tables where few columns are used.
- Missing indexes for filtered/sorted columns; verify with `EXPLAIN`.
  Index additions are schema changes: propose them, do not slip them in.
- Unbounded queries without `LIMIT`/pagination on user-facing lists.
- Long transactions holding locks across network calls.
- Connection pool not configured (`SetMaxOpenConns`, `SetConnMaxIdleTime`).

**Allocation and CPU**
- Slices/maps grown in loops with a known size (`make([]T, 0, n)`).
- `regexp.MustCompile` / template parsing / JSON schema compilation inside
  functions called per request (hoist to package level or a `sync.OnceValue`).
- String concatenation in loops (`strings.Builder`).
- `strings.Split` only to range (use `SplitSeq`).
- Repeated `json.Marshal` of the same value; marshalling to `[]byte` then
  writing instead of encoding to the writer.
- `defer` inside long loops (deferred until function return).
- Reflection on hot paths.
- `sync.Pool` only with a benchmark showing it helps.

**Concurrency**
- Unbounded goroutine fan-out (one per item/request). Use `errgroup.SetLimit`.
- Mutex held across I/O or callbacks; lock contention visible in
  `-mutexprofile`.
- Busy-wait/polling loops with `time.Sleep` where a channel, condition, or
  `LISTEN/NOTIFY` fits.
- `time.Ticker` not stopped (pre-1.23 leak, still unclear code).

**I/O**
- Missing timeouts and context on outbound calls (also a reliability issue).
- Reading whole files/bodies into memory where streaming works.
- Not reusing `http.Client` (connection reuse lost per request).
- Response bodies not drained/closed (prevents keep-alive reuse).
