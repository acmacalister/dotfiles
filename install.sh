#!/bin/bash
# Bootstraps a new Mac: Homebrew, 1Password, chezmoi, then applies these
# dotfiles. chezmoi's run scripts take care of the Brewfile, language
# toolchains, fish plugins, and Ollama models.
set -euo pipefail

DOTFILES_REPO="acmacalister"

echo "==> Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo "Finish the Command Line Tools installer, then re-run this script."
  exit 1
fi

echo "==> Homebrew"
if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

echo "==> 1Password (needed to render secrets in chezmoi templates)"
brew list --cask 1password >/dev/null 2>&1 || brew install --cask 1password
brew list --cask 1password-cli >/dev/null 2>&1 || brew install --cask 1password-cli

until op vault list >/dev/null 2>&1; do
  cat <<'EOF'

1Password CLI is not connected yet. To fix:
  1. Open 1Password and sign in.
  2. Settings > Developer > enable "Integrate with 1Password CLI".
EOF
  read -r -p "Press Enter to check again (Ctrl-C to abort)... " _ </dev/tty
done

echo "==> fish and chezmoi"
brew list fish >/dev/null 2>&1 || brew install fish
brew list chezmoi >/dev/null 2>&1 || brew install chezmoi

echo "==> Applying dotfiles"
if [ ! -d "$HOME/.local/share/chezmoi" ]; then
  INIT_ARGS=()
  if [ -n "${DOTFILES_CONTEXTS:-}" ]; then
    INIT_ARGS+=(--promptString "contexts=$DOTFILES_CONTEXTS")
  fi
  chezmoi init --apply ${INIT_ARGS[@]+"${INIT_ARGS[@]}"} "$DOTFILES_REPO" </dev/tty
else
  chezmoi update </dev/tty
fi

echo "==> Default shell"
FISH_PATH="$(brew --prefix)/bin/fish"
if ! grep -qx "$FISH_PATH" /etc/shells; then
  echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
fi
if [ "${SHELL:-}" != "$FISH_PATH" ]; then
  chsh -s "$FISH_PATH" </dev/tty
fi

cat <<'EOF'

Done. Remaining manual steps:
  - gh auth login, then: gh extension install dlvhdr/gh-dash
  - Create or import SSH keys (~/.ssh/id_ed25519) and add them to GitHub
  - Install Xcode from the App Store if you need iOS tooling
  - Open a new terminal to start using fish
EOF
