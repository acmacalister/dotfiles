# Modern Go and Idioms

[Effective Go](https://go.dev/doc/effective_go) is still the best statement
of Go's *intent* (clarity, naming, zero values, composition, "share memory by
communicating"), but it predates modules, generics, `any`, error wrapping,
`context`, `log/slog`, and iterators. Follow its spirit; let this file and
the [Go proverbs](go-proverbs.md) override its examples where they disagree.

## Gate everything on the `go` directive

Modernizations are only valid if the module's `go` directive in `go.mod`
allows them. `go test` runs the `stdversion` vet check (Go 1.27+) and will
flag symbols too new for a file. **Never bump the `go` directive as part of
a cleanup without explicit approval**; for libraries it forces every
consumer to upgrade, which is a breaking change. Upgrading the toolchain
line alone is fine.

## Let the tools do mechanical work first

```bash
go fix -diff ./...          # preview (Go 1.26+ modernizer suite)
go fix ./...                # apply; review the diff like any other PR
go tool fix help            # list fixers available in this toolchain
go tool fix help <fixer>    # details on one fixer
go fix -<fixer> ./...       # apply just one fixer
```

Run fixers as their own commit, separate from hand-written refactors, so
reviewers can trust the mechanical diff. Toolchains older than 1.26 can use
`go run golang.org/x/tools/go/analysis/passes/modernize/cmd/modernize@latest -fix ./...`.

Current fixers (Go 1.27 toolchain) include: `any`, `atomictypes`,
`embedlit`, `errorsastype`, `forvar`, `inline` (`//go:fix inline`),
`mapsloop`, `minmax`, `newexpr`, `omitzero`, `plusbuild`, `rangeint`,
`reflecttypefor`, `slicesbackward`, `slicescontains`, `slicessort`,
`stditerators`, `stringsbuilder`, `stringscut`, `stringscutprefix`,
`stringsseq`, `testingcontext`, `unsafefuncs`, `waitgroupgo`.

**Caution on `omitzero`:** changing `omitempty` to `omitzero` changes JSON
output for some types (empty slices/maps vs nil, structs). Treat it as a
wire-format change and only apply where the encoded output is proven
identical or the field is internal.

## Version cheat sheet (what to prefer, and since when)

| Prefer | Instead of | Since |
|---|---|---|
| `any` | `interface{}` | 1.18 |
| generics for 3+ copies of type-specialised code | `interface{}` + type switches, code generation | 1.18 |
| `errors.Is/As`, `%w`, `errors.Join` | `==` on errors, string matching, custom multi-errors | 1.13 / 1.20 |
| `slices`, `maps`, `cmp` packages | hand-written loops, `sort.Slice`, `sort.Strings` | 1.21 |
| `min`, `max`, `clear` builtins | if/else, delete loops | 1.21 |
| `log/slog` | `log.Printf`, ad-hoc logger interfaces | 1.21 |
| `context.WithoutCancel`, `AfterFunc`, `WithTimeoutCause` | hand-rolled detached contexts | 1.21 |
| per-iteration loop variables (drop `x := x`) | loop var copies | 1.22 |
| `for i := range n` | `for i := 0; i < n; i++` | 1.22 |
| `http.ServeMux` method + wildcard patterns (`"GET /flows/{id}"`, `r.PathValue`) | third-party routers for simple routing | 1.22 |
| `math/rand/v2` (and `crypto/rand` for anything secret) | `math/rand` with manual seeding | 1.22 |
| range-over-func iterators, `iter.Seq`/`Seq2`, `slices.Collect`, `maps.Keys` | callback-visitor APIs, building slices only to range over them | 1.23 |
| `unique.Make` for interning | custom interning maps | 1.23 |
| `strings.SplitSeq`/`Lines`/`FieldsSeq`, `bytes` equivalents | `strings.Split` when only ranging | 1.24 |
| `t.Context()`, `b.Context()`, `t.Chdir` | `context.Background()` + cancel in tests | 1.24 |
| `b.Loop()` | `for i := 0; i < b.N; i++` | 1.24 |
| `os.Root` / `os.OpenRoot` | `filepath.Join` + prefix checks for user-supplied paths | 1.24 |
| `encoding/json` `omitzero` | pointer fields just to omit zero time/structs | 1.24 |
| `go tool` directives in `go.mod` | `tools.go` blank imports | 1.24 |
| `runtime.AddCleanup`, `weak` | `runtime.SetFinalizer` | 1.24 |
| `sync.WaitGroup.Go` | `wg.Add(1); go func(){ defer wg.Done() }()` | 1.25 |
| `testing/synctest.Test` | `time.Sleep`-based tests, fake clock plumbing used only for tests | 1.25 |
| `http.CrossOriginProtection` | hand-rolled CSRF origin checks | 1.25 |
| `new(expr)` | `v := expr; &v` / `ptr(v)` helpers | 1.26 |
| `errors.AsType[T](err)` | `var t *T; errors.As(err, &t)` | 1.26 |
| `slog.NewMultiHandler` | custom fan-out handlers | 1.26 |
| `t.ArtifactDir()` | ad-hoc temp dirs for test artifacts you want to keep | 1.26 |
| `encoding/json/v2`, `jsontext` (GA) | third-party JSON libs used for speed/strictness | 1.27 |
| `uuid` package | `github.com/google/uuid` for new code | 1.27 |
| `strings.CutLast`, `bytes.CutLast` | `LastIndex` + slicing | 1.27 |
| generic methods | free functions taking the receiver as a parameter | 1.27 |
| `synctest.Sleep` | `time.Sleep` + `synctest.Wait` | 1.27 |

Replacing a third-party dependency with a stdlib equivalent (uuid, router,
JSON) can change behaviour (formatting, strictness, error text). Treat it as
its own reviewed change with tests proving equivalence, never as a drive-by.

## Collections

- Prefer the standard library: `slices`, `maps`, `iter`, `cmp`, `container/heap`.
- `golang.org/x/exp/collection` (packages `set`, `hashed`, `sorted`, `heap`)
  is a **separate, experimental, pseudo-versioned module**
  (`golang.org/x/exp/collection`). It is a preview of what may land in the
  standard library. Rules:
  - Use it only when the module already depends on it, or with explicit
    approval to add it.
  - Never expose its types in exported APIs of a library module; its API can
    change without notice.
  - Prefer it over hand-rolled `map[T]struct{}` set helpers duplicated
    across packages when the dependency is approved.
- A tiny private `set` helper (a `map[T]struct{}` with 3 methods) is
  acceptable: "a little copying is better than a little dependency."
- Concurrent maps: prefer a typed wrapper over `sync.Map` (crush uses
  `internal/csync` with `csync.Map[K, V]` and `csync.Slice[T]`). Flag raw
  `sync.Map` with `any` type assertions sprinkled through callers.

## Iterators

- Return `iter.Seq[T]` / `iter.Seq2[K, V]` from APIs that stream or that
  callers usually filter, instead of allocating a slice "just in case".
- Do not convert every slice-returning function to iterators. Slices are
  simpler when callers index, `len`, or retain results. Clear is better than
  clever.
- Iterators over resources (rows, files) must handle early `break`
  (the yield returning false) and release resources.

## Idioms checklist

- Zero values are useful: `var mu sync.Mutex`, `var buf bytes.Buffer`,
  config structs with sensible zero defaults. Flag constructors that only
  set zero values.
- Getters without `Get`; `Is/Has/Can` for booleans; `New<Type>` constructors.
- Receiver names short and consistent across a type's methods.
- No naked returns in functions longer than a few lines.
- Early returns over nested `else`.
- `context.Context` is the first parameter, never stored in structs (except
  request-scoped structs that clearly own a lifetime).
- Use functional options or a config struct for constructors with more than
  ~3 optional parameters; follow the codebase's existing choice.
- Comments explain *why*. Exported identifiers have doc comments starting
  with the name. Delete comments that restate the code.
- Use `errgroup` (with `SetLimit`) for bounded fan-out with errors;
  `WaitGroup.Go` when there are no errors.
