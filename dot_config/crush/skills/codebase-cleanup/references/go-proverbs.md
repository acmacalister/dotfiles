# Go Proverbs as Audit Checks

Source: <https://go-proverbs.github.io/>. Each proverb maps to something
concrete to look for. Cite the proverb in findings when it is the reason for
a change; it makes reviews shorter.

| Proverb | What to flag | Typical fix |
|---|---|---|
| Don't communicate by sharing memory, share memory by communicating. | Several goroutines mutating shared structs guarded by ad-hoc flags; mutex-protected queues reimplementing channels. | Channel ownership, or a single owner goroutine. Keep mutexes where they are simpler (see next row). |
| Concurrency is not parallelism. | Goroutines spawned per item with no bound "to make it faster"; `GOMAXPROCS` tweaks without measurement. | `errgroup` with `SetLimit`, worker pool, or plain sequential code. |
| Channels orchestrate; mutexes serialize. | Channels used as locks (`chan struct{}` of size 1 guarding a map); mutexes used to coordinate lifecycles. | `sync.Mutex` / typed concurrent map for state; channels/context for signalling. |
| The bigger the interface, the weaker the abstraction. | Interfaces with many methods where consumers use 1-3. | Consumer-side narrow interfaces (see architecture.md). |
| Make the zero value useful. | Constructors that only set zero values; nil-map panics on zero structs; required `Init()` calls. | Lazy init in methods, usable zero `struct{}`. |
| `interface{}` says nothing. | `any` / `map[string]any` crossing package boundaries; type switches on `any` in business logic. | Concrete types, generics, or a small interface. |
| Gofmt's style is no one's favorite, yet gofmt is everyone's favorite. | Unformatted files; style debates in review. | `gofmt -w .` (or `gofumpt` if the project uses it). Never hand-format. |
| A little copying is better than a little dependency. | New third-party deps for trivial helpers (`lo`, `funk`, tiny utils); shared `util` packages that couple unrelated packages. | Inline the 5 lines, or use `slices`/`maps`. Balance against DRY (see dead-code-and-dry.md). |
| Syscall must always be guarded with build tags. | `syscall`/`golang.org/x/sys` calls in files without `//go:build` constraints. | Split into `_unix.go` / `_windows.go` or add build tags. |
| Cgo must always be guarded with build tags. Cgo is not Go. | Cgo in packages that should be pure Go; cgo without a pure-Go fallback for builds with `CGO_ENABLED=0`. | Isolate behind a port with build-tagged adapters. |
| With the unsafe package there are no guarantees. | `unsafe` for micro-optimizations without benchmarks; pointer arithmetic. | Remove unless benchmarked and documented; `go fix -unsafefuncs`. |
| Clear is better than clever. | Dense one-liners, reflection tricks, deep generic constraints, iterator chains where a loop reads better. | The boring version. |
| Reflection is never clear. | `reflect` in business logic; struct-tag driven magic outside encoding/validation libraries. | Explicit code, generics. |
| Errors are values. | Errors compared by string; sentinel errors created inline (`errors.New` in a function body used for comparison). | Package-level sentinels, typed errors, `errors.Is/As/AsType`. |
| Don't just check errors, handle them gracefully. | `if err != nil { return err }` with no context across package boundaries; errors logged *and* returned (double reporting); `_ =` on errors that matter (Close on writers, Rollback results ignored is fine). | Wrap with `fmt.Errorf("doing x: %w", err)` once per boundary; log once at the top. |
| Design the architecture, name the components, document the details. | Packages named `util`, `common`, `misc`, `helpers`, `base`; missing package docs. | Rename by responsibility; add `// Package x ...` docs. |
| Documentation is for users. | Doc comments that describe implementation instead of behavior and contracts; exported symbols without docs. | Describe what, when, errors returned, and concurrency safety. |
| Don't panic. | `panic` in library code for recoverable conditions; `log.Fatal` outside `main`; `Must*` helpers used at request time. | Return errors. `panic` is fine for programmer errors at init and in `Must*` used at package init. |
