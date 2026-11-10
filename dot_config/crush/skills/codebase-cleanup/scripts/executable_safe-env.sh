#!/usr/bin/env bash
# Run a command with a scrubbed environment so unattended test runs can never
# reach real systems with the developer's or runner's credentials.
#
# Usage:
#   safe-env.sh [--db] [--] <command...>   run <command> with an allowlisted env
#   safe-env.sh --stop-db                   remove the disposable Postgres
#
# Only allowlisted variables survive (PATH, HOME, Go settings, Docker host,
# locale). Add more with SAFE_ENV_KEEP="NAME1 NAME2" (names only, never
# secrets). With --db, DATABASE_URL and TEST_DATABASE_URL point at a
# disposable local Postgres container (started on first use, reused after).
#   SAFE_ENV_PG_IMAGE   image to run (default postgres:17-alpine; match CI)
#   SAFE_ENV_PG_NAME    container name (default codebase-cleanup-pg)
#   SAFE_ENV_DB_URL     use this local URL instead of starting a container
#   SAFE_ENV_PG_DATA    optional host directory for the database files. Use it
#                       only when the Docker VM disk is short on space; host
#                       bind mounts make database-heavy suites several times
#                       slower. By default the data lives in an anonymous
#                       volume that --stop-db removes.

set -euo pipefail

PG_NAME="${SAFE_ENV_PG_NAME:-codebase-cleanup-pg}"
PG_IMAGE="${SAFE_ENV_PG_IMAGE:-postgres:17-alpine}"
PG_DATA="${SAFE_ENV_PG_DATA:-}"

if [[ "${1:-}" == "--stop-db" ]]; then
	docker rm -f -v "$PG_NAME" >/dev/null 2>&1 || true
	[[ -n "$PG_DATA" ]] && rm -rf "$PG_DATA"
	exit 0
fi

want_db=0
if [[ "${1:-}" == "--db" ]]; then
	want_db=1
	shift
fi
[[ "${1:-}" == "--" ]] && shift
if [[ $# -eq 0 ]]; then
	echo "usage: safe-env.sh [--db] [--] <command...>" >&2
	exit 2
fi

keep=(PATH HOME USER LOGNAME SHELL TMPDIR TERM LANG LC_ALL LC_CTYPE
	GOPATH GOROOT GOBIN GOCACHE GOMODCACHE GOFLAGS GOTOOLCHAIN GOPROXY
	GOPRIVATE GONOSUMDB GONOPROXY GOSUMDB GOEXPERIMENT GOOS GOARCH CGO_ENABLED
	DOCKER_HOST DOCKER_CONFIG XDG_CACHE_HOME CI
	LINT_CMD TAGS SKIP_TESTS SKIP_NETWORK)
# shellcheck disable=SC2206
keep+=(${SAFE_ENV_KEEP:-})

args=()
for name in "${keep[@]}"; do
	if [[ -n "${!name+x}" ]]; then
		args+=("$name=${!name}")
	fi
done

if [[ $want_db -eq 1 ]]; then
	url="${SAFE_ENV_DB_URL:-}"
	if [[ -n "$url" ]]; then
		if ! [[ "$url" =~ @(localhost|127\.0\.0\.1|\[::1\])(:|/) ]]; then
			echo "safe-env: SAFE_ENV_DB_URL must point at localhost" >&2
			exit 2
		fi
	else
		if ! docker inspect "$PG_NAME" >/dev/null 2>&1; then
			mount=()
			if [[ -n "$PG_DATA" ]]; then
				mkdir -p "$PG_DATA"
				mount=(-e PGDATA=/var/lib/postgresql/data/pgdata -v "$PG_DATA:/var/lib/postgresql/data")
			fi
			docker run -d --name "$PG_NAME" \
				-e POSTGRES_USER=cleanup -e POSTGRES_PASSWORD=cleanup -e POSTGRES_DB=cleanup \
				${mount[@]+"${mount[@]}"} \
				-p 127.0.0.1::5432 "$PG_IMAGE" -c max_connections=500 \
				-c fsync=off -c synchronous_commit=off -c full_page_writes=off >/dev/null
		elif [[ "$(docker inspect -f '{{.State.Running}}' "$PG_NAME")" != "true" ]]; then
			docker start "$PG_NAME" >/dev/null
		fi
		port="$(docker port "$PG_NAME" 5432/tcp | head -1 | sed 's/.*://')"
		for _ in $(seq 1 60); do
			docker exec "$PG_NAME" pg_isready -U cleanup >/dev/null 2>&1 && break
			sleep 1
		done
		url="postgres://cleanup:cleanup@127.0.0.1:${port}/cleanup?sslmode=disable"
	fi
	args+=("DATABASE_URL=$url" "TEST_DATABASE_URL=$url")
fi

exec env -i "${args[@]}" "$@"
