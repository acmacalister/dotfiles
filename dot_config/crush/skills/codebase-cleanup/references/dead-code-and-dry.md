# Dead Code and DRY

## Dead code

### Find candidates

1. `deadcode -test ./...` (from the audit script): functions unreachable from
   any `main` or test. Without `-test`, it also reveals code reachable *only*
   from tests, which is either dead production code or a test helper that
   belongs in a `_test.go` file.
2. `staticcheck` `U1000` (unused) and `golangci-lint` `unused`, `unparam`
   (always-same or unused parameters), `ineffassign`, `wastedassign`.
3. `go mod tidy -diff`: unused module requirements.
4. Manual sweeps:
   - Commented-out code blocks. Git remembers; delete them.
   - Feature flags and config keys that are always on/off in every
     environment (check deploy manifests, `.env*`, Helm/kustomize).
   - `Deprecated:` symbols with no remaining callers.
   - Old migrations helpers, one-off backfill commands in `cmd/` that already
     ran (confirm with the owner before deleting; they may be re-runnable).
   - Stale `testdata/` fixtures and golden files no test reads.
   - Docs (`*.md`) describing removed features or commands.
   - Exported identifiers in `internal/` packages that are used only inside
     their own package (unexport them).

### Verify before deleting (false positives)

Static tools cannot see these references. Grep for the identifier as a
string before removing anything:

- Reflection, `encoding/json`/`yaml` struct fields, `text/template` /
  `html/template` / templ method calls, `database/sql` scanners.
- `//go:linkname`, `//go:generate`, plugins, cgo exports (`//export`).
- Interface satisfaction used only via assertion (`var _ I = (*T)(nil)`).
- Build-tagged files (`integration`, `cluster`, `e2e`, OS-specific): rerun
  `deadcode`/tests with those tags (`TAGS=...` in the audit script).
- Handlers registered by string name, River/queue job kinds, RPC method
  tables, CLI commands registered via `init()`.
- Exported API of a library module consumed by other repos. Search the org
  (Sourcegraph/GitHub code search) before deleting exported symbols from a
  module someone else imports.

### Delete safely

- Delete in small, focused commits ("remove unused X helpers") so a revert is
  trivial.
- Remove the tests that only exercised the dead code in the same commit.
- Run build, vet, lint, and the full test suite including tagged suites.

## DRY, with judgment

"A little copying is better than a little dependency" and DRY pull in
opposite directions. Resolve it this way:

- **DRY up knowledge, not keystrokes.** Deduplicate when two copies encode
  the *same business rule or protocol detail* and must change together
  (status mapping, retry policy, auth checks, error-to-HTTP mapping, SQL
  fragments for the same filter). Leave coincidentally similar code alone.
- **Rule of three.** Two copies are a watch item; three copies of the same
  rule are a finding.
- **Prefer the standard library** (`slices`, `maps`, `cmp`, `strings`,
  `errors.Join`) over a new helper package.
- **Never create `util`, `common`, `helpers`, `shared`, or `misc`.** Put the
  extracted code in the package that owns the concept, or in the root
  domain package if it is a domain rule.
- **Generics** are the right tool when the same algorithm is copied for
  multiple types. Avoid them when one or two concrete types exist.
- **Test helpers** are the highest-yield DRY target: repeated server/DB
  setup, fixture builders, and assertion blocks belong in a shared
  `*_test.go` helper (with `t.Helper()`) or a `testdata`/`internal/testutil`
  style package the codebase already uses. Convert copy-pasted test
  functions into table-driven tests.
- **Cross-cutting concerns** copied into every method of an adapter
  (logging, metrics, tracing, retries) are better expressed as a decorator
  that wraps the port (see architecture.md).

### DRY findings checklist

- Same error-to-status mapping in multiple handlers.
- Same pagination/filter parsing in multiple handlers.
- Same SQL `WHERE` fragments or row-scanning code in multiple repository
  methods.
- Same "load, check owner, return 404" authorization sequence.
- Same HTTP client construction (timeouts, retries, headers) in multiple
  adapters.
- Repeated config/env parsing with ad-hoc defaults.
- Repeated JSON response writing without a shared `writeJSON`/`writeError`.
