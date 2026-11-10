#!/usr/bin/env bash
# Read-only audit sweep for a Go module. Never edits source files.
#
# Usage: audit.sh [module-dir] [output-dir]
#   TAGS="integration cluster"  extra build tags for vet/test/deadcode
#   SKIP_TESTS=1                skip the coverage run (slow suites)
#   SKIP_NETWORK=1              skip tools fetched with `go run pkg@latest`
#
# Every step writes to <output-dir>/<step>.txt and a one-line status to
# <output-dir>/SUMMARY.txt. A failing step never aborts the sweep.

set -uo pipefail

MOD_DIR="$(cd "${1:-.}" && pwd)"
OUT_DIR="${2:-${TMPDIR:-/tmp}/codebase-cleanup-$(basename "$MOD_DIR")-$(date +%Y%m%d-%H%M%S)}"
TAGS="${TAGS:-}"
mkdir -p "$OUT_DIR"
cd "$MOD_DIR" || exit 1

if [[ ! -f go.mod ]]; then
	echo "no go.mod in $MOD_DIR" >&2
	exit 1
fi

TAG_FLAG=()
[[ -n "$TAGS" ]] && TAG_FLAG=(-tags "${TAGS// /,}")

SUMMARY="$OUT_DIR/SUMMARY.txt"
: >"$SUMMARY"

have() { command -v "$1" >/dev/null 2>&1; }

# run <name> <cmd...>: capture output, record exit status and line count.
run() {
	local name="$1"
	shift
	local file="$OUT_DIR/$name.txt"
	{
		echo "\$ $*"
		echo
	} >"$file"
	"$@" >>"$file" 2>&1
	local rc=$?
	local lines
	lines=$(($(wc -l <"$file") - 2))
	printf '%-14s rc=%-3s lines=%-6s %s\n' "$name" "$rc" "$lines" "$file" >>"$SUMMARY"
	return 0
}

skip() {
	printf '%-14s SKIPPED (%s)\n' "$1" "$2" >>"$SUMMARY"
}

MODULE_PATH="$(go list -m)"
GO_DIRECTIVE="$(go mod edit -json | sed -n 's/.*"Go": "\(.*\)".*/\1/p' | head -1)"
{
	echo "module:      $MODULE_PATH"
	echo "go directive: $GO_DIRECTIVE"
	echo "toolchain:   $(go version)"
	echo "tags:        ${TAGS:-<none>}"
	echo "output:      $OUT_DIR"
	echo
} >>"$SUMMARY"

# Baseline: the codebase must be green before any cleanup starts.
run build go build ${TAG_FLAG[@]+"${TAG_FLAG[@]}"} ./...
run vet go vet ${TAG_FLAG[@]+"${TAG_FLAG[@]}"} ./...
run mod-tidy go mod tidy -diff

# Tagged suites (integration, cluster, e2e) silently rot when nobody builds
# them; vet each build tag the repo uses.
REPO_TAGS="$(grep -rhoE '^//go:build [A-Za-z0-9_]+$' --include='*.go' . 2>/dev/null |
	awk '{print $2}' | grep -vE '^(ignore|tools|race|linux|darwin|windows|unix|amd64|arm64)$' | sort -u | tr '\n' ' ')"
for tag in $REPO_TAGS; do
	run "vet-tag-$tag" go vet -tags "$tag" ./...
done

# Linting: prefer the project's own pinned lint command (LINT_CMD, e.g.
# "task lint" or "make lint") over a globally installed golangci-lint, which
# is often built with an older Go and panics on newer go directives.
if [[ -n "${LINT_CMD:-}" ]]; then
	run lint bash -c "$LINT_CMD"
elif have golangci-lint; then
	run lint golangci-lint run --max-issues-per-linter=0 --max-same-issues=0 ./...
else
	skip lint "no LINT_CMD and golangci-lint not installed"
fi

# Modernizers. `go fix -diff` exits non-zero when it has suggestions.
run go-fix go fix ${TAG_FLAG[@]+"${TAG_FLAG[@]}"} -diff ./...

# gotool <name> <binary> <package> <args...>
# Builds the tool with the current toolchain via `go run pkg@latest` so it can
# type-check code using the newest Go version. Installed binaries built with an
# older Go fail with "requires newer Go version". SKIP_NETWORK falls back to the
# installed binary.
gotool() {
	local name="$1" bin="$2" pkg="$3"
	shift 3
	if [[ -z "${SKIP_NETWORK:-}" ]]; then
		run "$name" go run "$pkg@latest" "$@"
	elif have "$bin"; then
		run "$name" "$bin" "$@"
	else
		skip "$name" "$bin not installed and SKIP_NETWORK set"
	fi
}

gotool staticcheck staticcheck honnef.co/go/tools/cmd/staticcheck ${TAG_FLAG[@]+"${TAG_FLAG[@]}"} ./...
# Dead code: whole-program reachability from main packages and tests.
gotool deadcode deadcode golang.org/x/tools/cmd/deadcode -test ${TAG_FLAG[@]+"${TAG_FLAG[@]}"} ./...
gotool govulncheck govulncheck golang.org/x/vuln/cmd/govulncheck ${TAG_FLAG[@]+"${TAG_FLAG[@]}"} ./...
gotool gosec gosec github.com/securego/gosec/v2/cmd/gosec -quiet -fmt=text ${TAG_FLAG[@]+"${TAG_FLAG[@]}"} ./...

# Flag tool runs that failed for toolchain reasons rather than findings.
for file in "$OUT_DIR"/*.txt; do
	if grep -q -E 'requires newer Go version|built with go1|without types was imported|Loading packages failed' "$file"; then
		printf '%-14s TOOL-ERROR (toolchain mismatch or load failure; results unusable) %s\n' "$(basename "$file" .txt)" "$file" >>"$SUMMARY"
	fi
done

# Architecture: import graph for the root (domain) package and adapters.
{
	echo "# Root package imports (should be stdlib or tiny pure deps only)"
	go list -f '{{join .Imports "\n"}}' . 2>/dev/null | grep -v '^[a-z]*$' | grep '\.' || echo "(stdlib only or no root package)"
	echo
	echo "# Intra-module edges, excluding imports of the root package and from cmd/"
	echo "# (adapter -> adapter edges are suspect; see references/architecture.md)"
	go list -f '{{.ImportPath}}{{range .Imports}}{{"\n  -> "}}{{.}}{{end}}' ./... 2>/dev/null |
		awk -v mod="$MODULE_PATH" '
			/^[^ ]/ {pkg=$0; next}
			index($2, mod) != 1 {next}
			$2 == mod {next}
			index(pkg, mod "/cmd/") == 1 {next}
			{print pkg " -> " $2}'
} >"$OUT_DIR/imports.txt" 2>&1
printf '%-14s %s\n' "imports" "$OUT_DIR/imports.txt" >>"$SUMMARY"

# Hygiene markers that usually point at dead or unfinished code.
{
	echo "# TODO/FIXME/HACK/XXX"
	grep -rn --include='*.go' -E '\b(TODO|FIXME|HACK|XXX)\b' . | grep -v '/vendor/' | head -200
	echo
	echo "# Deprecated markers"
	grep -rn --include='*.go' 'Deprecated:' . | grep -v '/vendor/' | head -100
	echo
	echo "# nolint directives"
	grep -rn --include='*.go' '//nolint' . | grep -v '/vendor/' | head -200
	echo
	echo "# Panics outside main/tests"
	grep -rn --include='*.go' -E '\bpanic\(' . | grep -v -E '_test\.go|/vendor/|/cmd/' | head -100
	echo
	echo "# Old-style APIs (interface{}, ioutil, sort.Slice, math/rand, log.Print)"
	grep -rn --include='*.go' -E 'interface\{\}|io/ioutil|sort\.(Slice|Strings|Ints)\(|"math/rand"|\blog\.(Print|Fatal)' . | grep -v '/vendor/' | head -200
} >"$OUT_DIR/markers.txt" 2>&1
printf '%-14s %s\n' "markers" "$OUT_DIR/markers.txt" >>"$SUMMARY"

# Refuse to run tests against a non-local database: developer shells often
# export DATABASE_URL for real environments.
if [[ -z "${SKIP_TESTS:-}" && -n "${DATABASE_URL:-}" ]] &&
	! [[ "$DATABASE_URL" =~ @(localhost|127\.0\.0\.1|\[::1\]|postgres|db)(:|/) ]]; then
	skip test "DATABASE_URL points at a non-local host; set it to a disposable local database or SKIP_TESTS=1"
	SKIP_TESTS=1
fi

if [[ -z "${SKIP_TESTS:-}" ]]; then
	run test go test ${TAG_FLAG[@]+"${TAG_FLAG[@]}"} -count=1 -coverprofile="$OUT_DIR/cover.out" ./...
	if [[ -s "$OUT_DIR/cover.out" ]]; then
		{
			echo "# Lowest-covered functions (excluding 100%)"
			go tool cover -func="$OUT_DIR/cover.out" | grep -v '100.0%' | sort -k3 -n | head -80
			echo
			go tool cover -func="$OUT_DIR/cover.out" | tail -1
		} >"$OUT_DIR/coverage.txt" 2>&1
		printf '%-14s %s\n' "coverage" "$OUT_DIR/coverage.txt" >>"$SUMMARY"
	fi
else
	skip test "SKIP_TESTS set"
fi

cat "$SUMMARY"
