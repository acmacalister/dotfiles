#!/bin/bash
# One-time migration: copies secrets that currently live in plaintext on this
# machine (fish config, fish universal variables, crush.json, ~/.npmrc) into
# 1Password so the chezmoi templates can read them on a new machine.
# Existing items are never modified; items that already exist are skipped.
set -euo pipefail

VAULT="${VAULT:-Private}"
FISH_CONFIG="$HOME/.config/fish/config.fish"
CRUSH_CONFIG="$HOME/.config/crush/crush.json"
NPMRC="$HOME/.npmrc"

fish_config_value() {
  grep -E "^set -x $1 " "$FISH_CONFIG" | head -1 | awk '{print $4}'
}

fish_universal_value() {
  fish -c "printf %s \$$1"
}

item_exists() {
  op item get "$1" --vault "$VAULT" >/dev/null 2>&1
}

create_api_credential() {
  local title="$1" value="$2"
  if item_exists "$title"; then
    echo "skip: '$title' already exists"
    return
  fi
  if [ -z "$value" ]; then
    echo "skip: no local value found for '$title'" >&2
    return
  fi
  jq -n --arg title "$title" --arg value "$value" '{
    title: $title,
    category: "API_CREDENTIAL",
    fields: [{id: "credential", label: "credential", type: "CONCEALED", value: $value}]
  }' | op item create --vault "$VAULT" >/dev/null
  echo "created: '$title'"
}

create_login() {
  local title="$1" username="$2" password="$3"
  if item_exists "$title"; then
    echo "skip: '$title' already exists"
    return
  fi
  if [ -z "$username" ] || [ -z "$password" ]; then
    echo "skip: no local value found for '$title'" >&2
    return
  fi
  jq -n --arg title "$title" --arg username "$username" --arg password "$password" '{
    title: $title,
    category: "LOGIN",
    fields: [
      {id: "username", label: "username", purpose: "USERNAME", type: "STRING", value: $username},
      {id: "password", label: "password", purpose: "PASSWORD", type: "CONCEALED", value: $password}
    ]
  }' | op item create --vault "$VAULT" >/dev/null
  echo "created: '$title'"
}

op vault get "$VAULT" >/dev/null

create_api_credential "GitHub PAT" "$(fish_config_value GH_PAT)"
create_api_credential "Sentry Access Token" "$(fish_config_value SENTRY_ACCESS_TOKEN)"
create_api_credential "Datadog API Key" "$(fish_config_value DD_API_KEY)"
create_api_credential "Datadog Application Key" "$(fish_config_value DD_APPLICATION_KEY)"
create_api_credential "Curri Read Replica URI" "$(fish_config_value CURRI_READ_REPLICA_URI)"
create_login "K6 Load Test" "$(fish_config_value K6_LOAD_TEST_EMAIL)" "$(fish_config_value K6_LOAD_TEST_PASSWORD)"
create_api_credential "DigitalOcean Access Token" "$(fish_universal_value DIGITALOCEAN_ACCESS_TOKEN)"
create_api_credential "Stitch API Key" "$(jq -r '.mcp.stitch.headers["X-Goog-Api-Key"] // empty' "$CRUSH_CONFIG" | grep -v '^\$' || true)"
create_api_credential "Switchboard MCP Token" "$(jq -r '.mcp.switchboard.headers.Authorization // empty' "$CRUSH_CONFIG" | sed 's/^Bearer //' | grep -v '^\$' || true)"
create_api_credential "npm Token" "$(sed -n 's#^//registry.npmjs.org/:_authToken=##p' "$NPMRC" 2>/dev/null || true)"

cat <<'EOF'

Items the templates read that this script does not create (they already
exist in 1Password): AWS Bedrock Token, AWS ECR Registry, OpenAI API Key,
Cloudflare AI Gateway Token ("Austin Token" field), Expo Access Token,
Linear MCP. Verify everything resolves with:

  chezmoi cat ~/.config/fish/conf.d/secrets.fish >/dev/null
EOF
