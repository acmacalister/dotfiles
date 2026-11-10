# Architecture: Standard Package Layout as Ports and Adapters

Ben Johnson's [Standard Package Layout](https://medium.com/@benbjohnson/standard-package-layout-7cdbc8391fc1)
is hexagonal architecture expressed with Go packages. Map the vocabulary
before auditing:

| Hexagonal term | Standard Package Layout | Typical location |
|---|---|---|
| Domain / core | Root package: domain types, errors, service interfaces | `myapp.go`, `user.go`, `order.go` at module root |
| Port | Interface declared in the root package (`UserService`, `Store`) | root package |
| Driven adapter | Subpackage named after its dependency | `postgres/`, `redis/`, `slack/`, `k8s/`, `nats/` |
| Driving adapter | Subpackage that calls into the domain | `http/` (or `rest/`), `grpc/`, `cli/` |
| Test double | Shared `mock/` package implementing root interfaces | `mock/` |
| Composition root | `main` package that wires adapters together | `cmd/<binary>/main.go` |

## Rules to audit

1. **The root package depends on nothing internal.** It imports only the
   standard library and, rarely, a tiny pure dependency (ULID, decimal).
   It must never import an adapter subpackage. Check
   `imports.txt` from the audit script.
2. **Group subpackages by dependency, not by layer or feature.** `postgres/`
   holds every Postgres implementation; there is no `models/`,
   `controllers/`, `services/`, `utils/`, `common/`, `helpers/`, or `types/`
   grab bag. A package name should tell you what it talks to.
3. **Adapters do not import each other.** `http` talks to `postgres` only
   through a root interface. When an adapter needs another adapter, the
   composition root injects it through the interface. Legitimate exceptions:
   an adapter wrapping another implementation of the same interface (a
   cache in front of a store, an instrumented decorator), and a package that
   shares a low-level client (`postgres` importing an internal `sqlx`
   helper). Note exceptions in the report; do not "fix" them blindly.
4. **`main` only wires.** No business rules, SQL, HTTP handling, or retry
   logic in `cmd/`. Flag `main.go` files longer than ~200 lines for review.
5. **Business rules live in the domain or in a service in the root package,
   not in handlers or SQL.** Handlers decode, authorize, call a port, encode.
   Repositories persist and map errors. Validation that encodes a business
   rule belongs on the domain type (`func (u *User) Validate() error`).
6. **Errors cross boundaries as domain errors.** Adapters translate
   `sql.ErrNoRows`, HTTP 404s, NATS timeouts into root sentinel errors or a
   root `Error` type (code + message). Driving adapters translate domain
   errors to transport codes in one place (`ErrorStatusCode(err)`), not in
   every handler.
7. **`internal/` is for the module, not for hiding layers.** Large modules
   (like crush) put most packages under `internal/`. The same dependency
   rules apply inside `internal/`.
8. **One domain concept per file** in the root package (`user.go`,
   `flow.go`), each with its type, errors, filter/update structs, and port.

## Interfaces: where they live

Two pieces of guidance meet here; follow the codebase's existing choice and
apply it consistently:

- **Ports in the root package.** Service interfaces that multiple adapters
  implement or consume (`FlowService`, `Store`) belong in the root package.
  This is the Standard Package Layout default and enables a shared `mock/`.
- **Narrow consumer-side interfaces.** When one consumer needs one or two
  methods of a large port, declare a small interface at the call site
  (`type flowGetter interface { FindFlowByID(...) }`). "The bigger the
  interface, the weaker the abstraction."

Flag:
- Interfaces with a single implementation and no test double that exist
  "for future flexibility" (remove only if unexported, see SKILL.md
  contract).
- Interfaces declared next to their only implementation and consumed by
  nobody else.
- Kitchen-sink interfaces (>8-10 methods) where consumers use a small
  subset; propose a consumer-side interface rather than splitting the port.
- Constructors returning interfaces when callers would benefit from the
  concrete type (accept interfaces, return structs), unless the codebase
  deliberately returns root ports from adapter constructors.

## Mocks

Prefer the Ben Johnson function-field mock in `mock/`:

```go
type FlowService struct {
	FindFlowByIDFn func(ctx context.Context, id int) (*myapp.Flow, error)
}

func (s *FlowService) FindFlowByID(ctx context.Context, id int) (*myapp.Flow, error) {
	return s.FindFlowByIDFn(ctx, id)
}
```

Flag mock packages that drift from their interface (compile-time assertion
`var _ myapp.FlowService = (*FlowService)(nil)` missing), duplicated ad-hoc
mocks across test files that could reuse `mock/`, and mocks of third-party
types (wrap the dependency behind a port first, then mock the port).

## Decorators are the hexagonal way to add cross-cutting concerns

Observability, caching, retries, and authorization checks that apply to a
whole port can be added as an adapter that wraps another implementation of
the same interface, wired in `main`:

```go
var flows myapp.FlowService = postgres.NewFlowService(db)
flows = otel.NewFlowService(flows, tracer) // instrumented decorator
```

This keeps the domain and the base adapter free of logging/metrics noise.
Propose decorators when the same instrumentation is copy-pasted across many
methods of one adapter.

## Enforcing the architecture

Reviews and audits find drift after it lands; a test stops it landing.
Every repo this skill maintains should have an import-rule test at the
module root that runs in the normal `go test ./...` (and therefore CI).

1. If the repo has no such test (search for `TestArchitecture`, `depguard`
   rules in `.golangci.yml`, or an existing import-check script), copy
   [architecture_test.go.tmpl](architecture_test.go.tmpl) to
   `architecture_test.go` in the module root, set the package clause to
   `<rootpkg>_test`, and fill in:
   - `rootAllowedImports`: third-party or internal packages the root domain
     package already imports and that are acceptable leaf dependencies.
   - `adapterDirs`: the repo's adapter packages (read AGENTS.md and the
     layout doc; postgres, http, nats, slack, and similar).
   - `allowedEdges`: every current violation, each with a reason a reviewer
     can verify (and an issue link when the fix is deferred).
   The test must pass on the current tree; it is a ratchet, not a cleanup.
2. If the repo already enforces imports another way (depguard,
   go-arch-lint, a script), maintain that instead of adding a second
   mechanism.
3. Every run: try to delete `allowedEdges` entries by fixing the violation
   safely (consumer-side interface instead of a concrete adapter type,
   moving an in-memory implementation out of `mock/`, injecting through
   the composition root). The test fails when an allowed edge no longer
   exists, so stale entries get removed.
4. Never add an allowlist entry to make a new violation pass. Fix it, or if
   it cannot be fixed safely in the run, record it as a deferred finding.

The template checks four rules: the root package imports only the standard
library plus approved leaves; nothing imports a `cmd/` main package;
production code does not import `mock/`; adapters do not import each
other. Add repo-specific rules (for example, "only `nativeagent/jobqueue/river`
may import River") as more cases, reusing any rules the repo already checks
in its lint task.

## What NOT to do in a cleanup

- Do not reorganize packages wholesale. Moving packages changes import paths
  and blows up review diffs. Propose large moves in the report and do them
  only with explicit approval, one package per change.
- Do not introduce the layout into a codebase that deliberately uses a
  different, consistent one. Consistency beats purity.
- Do not create a `domain/` or `core/` package when the root package already
  plays that role.
