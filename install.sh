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

# Work laptops often ship apps through MDM or direct downloads. Reuse anything
# already present instead of letting Homebrew fail on an existing app bundle.
app_installed() {
  [ -d "/Applications/$1.app" ] || [ -d "$HOME/Applications/$1.app" ]
}

echo "==> 1Password (needed to render secrets in chezmoi templates)"
if app_installed "1Password" || app_installed "1Password 7"; then
  echo "1Password app already installed; using it."
else
  brew install --cask 1password
fi
if command -v op >/dev/null 2>&1; then
  echo "1Password CLI already installed at $(command -v op); using it."
else
  brew install --cask 1password-cli
fi

until op vault list >/dev/null 2>&1; do
  cat <<'EOF'

1Password CLI is not connected yet. To fix:
  1. Open 1Password and sign in.
  2. Settings > Developer > enable "Integrate with 1Password CLI".
EOF
  read -r -p "Press Enter to check again (Ctrl-C to abort)... " _ </dev/tty
done

echo "==> fish and chezmoi"
command -v fish >/dev/null 2>&1 || brew install fish
command -v chezmoi >/dev/null 2>&1 || brew install chezmoi

echo "==> Applying dotfiles"
# DOTFILES_CONTEXTS (e.g. "personal,render") is read by .chezmoi.toml.tmpl;
# without it chezmoi prompts once and validates the answer.
if [ ! -d "$HOME/.local/share/chezmoi" ]; then
  chezmoi init --apply "$DOTFILES_REPO" </dev/tty
else
  chezmoi git pull -- --ff-only
  chezmoi init </dev/tty
  chezmoi apply </dev/tty
fi

echo "==> Default shell"
FISH_PATH="$(command -v fish)"
if ! grep -qx "$FISH_PATH" /etc/shells; then
  echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

# $SHELL is inherited from the login session and goes stale after chsh, so
# check (and verify) the account record instead.
login_shell() {
  dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}'
}
if [ "$(login_shell)" != "$FISH_PATH" ]; then
  chsh -s "$FISH_PATH" </dev/tty || true
fi
if [ "$(login_shell)" = "$FISH_PATH" ]; then
  echo "Login shell is $FISH_PATH."
else
  echo "warning: login shell is still $(login_shell). The account may be managed by" >&2
  echo "your company (MDM / directory account). Ghostty is configured to start fish" >&2
  echo "directly; for other terminals ask IT to allow: chsh -s $FISH_PATH" >&2
fi

cat <<'EOF'

Done. Remaining manual steps:
  - gh auth login, then: gh extension install dlvhdr/gh-dash
  - Create or import SSH keys (~/.ssh/id_ed25519) and add them to GitHub
  - Install Xcode from the App Store if you need iOS tooling
  - Quit your terminal app completely (Cmd+Q) and reopen it to get fish.
    Apps keep the old shell until they restart; log out and back in if
    Terminal.app or iTerm still opens zsh.
EOF
