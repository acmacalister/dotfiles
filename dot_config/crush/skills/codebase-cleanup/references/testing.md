# Testing: Integration and E2E First

Tests are the safety net that makes every other cleanup non-breaking. Add
them **before** refactoring code that lacks coverage.

## Priorities

1. **Characterization tests before refactors.** Before changing untested
   code, write a test through the public entry point (HTTP route, CLI
   command, port method) that pins current behavior, including odd behavior.
   It must pass before and after the refactor unchanged.
2. **Integration over unit.** Exercise real adapters: a real Postgres
   (transaction-isolated), real NATS/Redis started by the harness, real
   routing through `httptest.NewServer`. These catch wiring, SQL, and
   serialization bugs that mocks hide.
3. **E2E for critical user journeys.** A few tests that drive the system the
   way a user or upstream system does (HTTP API, webhook payload, Slack
   event, CLI invocation) and assert on externally visible outcomes.
4. **Unit tests where they pay off:** pure functions, parsers, validation,
   state machines, tricky edge cases. Table-driven.
5. **Mocks at true external boundaries only** (third-party APIs, LLMs, time).
   Use the shared `mock/` package for root ports; use recorded fixtures
   (VCR cassettes, golden files) for third-party HTTP.

## Find the gaps

- Coverage from the audit script (`coverage.txt`) shows unit-run coverage.
  Integration suites behind build tags or env vars are not included unless
  you run them: `go test -tags integration -coverpkg=./... -coverprofile=...`.
- Rank untested code by risk, not by percentage: handlers, auth, money,
  data mutations, migrations, concurrency, error paths, webhook verification.
- List every route/command/job and check each has at least one test hitting
  it end to end.
- Bugs fixed recently (`git log --grep fix`) without a regression test.

## Patterns to follow (match the codebase first)

- **Database isolation:** each test gets its own transaction that rolls back
  (`go-txdb`) or its own schema/database from a template. Never share
  mutable rows across parallel tests. Read the project's existing harness
  (`TestMain`, `testdata/`, `storetest`, `testfixtures`) before writing new
  setup code; extend it rather than creating a second one.
- **HTTP:** `httptest.NewServer(handler)` with the real router and
  middleware; assert status, headers, and decoded body.
- **Time and concurrency:** `testing/synctest` (Go 1.25+) for code with
  timers, tickers, and goroutines instead of `time.Sleep`. Inject a clock
  only if the codebase already does.
- **Contexts:** `t.Context()` (Go 1.24+), not `context.Background()`.
- **Golden files** for large rendered outputs (templates, Block Kit JSON,
  diffs), with an `-update` flag.
- **Recorded HTTP (VCR)** for third-party APIs so tests are deterministic
  and offline (crush records LLM provider traffic as cassettes in
  `testdata/`). Scrub secrets from cassettes.
- **Assertions:** follow the project (`testify/require` for fail-fast in
  crush and chapterchamp; `require.NoError`, never `require.Nil(err)`).
- `t.Parallel()` unless the test touches process-global state
  (`t.Setenv`, `t.Chdir`, shared ports).
- `t.Helper()` in helpers; `t.Cleanup()` for teardown.
- Test names describe behavior: `TestFlowService_CreateFlow_DuplicateName`.
- **Race detector** on packages with concurrency: `go test -race`.
- **Fuzzing** (`func FuzzX(f *testing.F)`) for parsers and decoders of
  untrusted input (webhook payloads, config, signatures).
- **Benchmarks** with `b.Loop()` for any code changed for performance.

## Anti-patterns to fix

- Tests asserting on mocks' call counts rather than outcomes.
- `time.Sleep` for synchronization (flaky): use channels, `synctest`, or
  `require.Eventually` with short polls if nothing else fits.
- Tests that pass when the feature is deleted (assert nothing meaningful).
- Copy-pasted test functions differing by one input (make them a table).
- Tests depending on execution order or on a developer's local services
  without a skip message (`t.Skip("set DATABASE_URL to run")`).
- Skipped tests (`t.Skip`) with no issue link or reason; either fix or
  delete them, and report which.
- Test-only code in production files (move to `_test.go` or `testdata`/
  test helper packages).

## Definition of done for added tests

- Fails when the behavior it covers is broken (mutate the code briefly to
  confirm for critical paths).
- Deterministic: passes with `-count=5 -race` (and `-shuffle=on` if the
  suite supports it).
- Runs in the project's standard test command or a documented tagged suite
  that CI runs.
