#!/bin/bash
# Installs language toolchains and global CLIs that Homebrew does not manage.
# Re-runs whenever this file changes.
set -uo pipefail

eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

NODE_VERSION="v22.18.0"

GO_TOOLS=(
  github.com/air-verse/air@latest
  github.com/go-delve/delve/cmd/dlv@latest
  golang.org/x/tools/cmd/goimports@latest
  github.com/nametake/golangci-lint-langserver@latest
  gotest.tools/gotestsum@latest
  honnef.co/go/tools/cmd/staticcheck@latest
  github.com/swaggo/swag/cmd/swag@latest
  github.com/go-task/task/v3/cmd/task@latest
  github.com/a-h/templ/cmd/templ@latest
  github.com/axzilla/templui/cmd/templui@latest
)

NPM_GLOBALS=(
  @microsoft/rush
  eas-cli
  vercel
  wrangler
  jscpd
)

echo "==> Go tools"
for tool in "${GO_TOOLS[@]}"; do
  go install "$tool" || echo "warning: failed to install $tool" >&2
done

echo "==> Fish plugins and Node $NODE_VERSION"
fish -c "fisher update; and nvm install $NODE_VERSION; and nvm use $NODE_VERSION; and set --universal nvm_default_version $NODE_VERSION; and corepack enable; and npm install -g ${NPM_GLOBALS[*]}" \
  || echo "warning: fish/node setup failed; run 'fisher update' and 'nvm install $NODE_VERSION' manually" >&2

echo "==> Rust"
if ! command -v rustup >/dev/null 2>&1 && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

echo "==> gh extensions"
if gh auth status >/dev/null 2>&1; then
  gh extension install dlvhdr/gh-dash 2>/dev/null || gh extension upgrade dlvhdr/gh-dash || true
else
  echo "gh is not authenticated; run 'gh auth login' then 'gh extension install dlvhdr/gh-dash'" >&2
fi
