#!/bin/bash

# Function to check and install packages via Homebrew
install_brew_package() {
  if ! brew list "$1" &> /dev/null; then
    echo "Installing $1..."
    brew install "$1"
  else
    echo "$1 is already installed."
  fi
}

# Function to install cask apps (for GUI applications like Docker, etc.)
install_brew_cask() {
  if ! brew list --cask "$1" &> /dev/null; then
    echo "Installing $1 (cask)..."
    brew install --cask "$1"
  else
    echo "$1 is already installed (cask)."
  fi
}

# Check if Homebrew is installed, if not install it
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew is already installed."
fi

# Install 1Password CLI (needed for chezmoi templates)
install_brew_cask 1password-cli

# Install Fish shell
install_brew_package fish

# Install ChezMoi
install_brew_package chezmoi

# Initialize ChezMoi with your dotfiles repository
DOTFILES_REPO="https://github.com/acmacalister/dotfiles.git"
if [ ! -d "$HOME/.local/share/chezmoi" ]; then
  echo "Initializing ChezMoi with dotfiles repository..."
  chezmoi init --apply "$DOTFILES_REPO"
else
  echo "ChezMoi is already initialized."
fi

# Set Fish as the default shell if it's not already
if [[ "$SHELL" != *fish ]]; then
  echo "Setting Fish as the default shell..."
  chsh -s "$(which fish)"
else
  echo "Fish is already the default shell."
fi

# Install additional tools via Homebrew
CLI_TOOLS=(
  bun        # JavaScript runtime
  curl       # Command-line HTTP client
  dbmate     # Database migration tool
  doctl      # DigitalOcean CLI
  just       # Task runner
  ripgrep    # Fast grep alternative
  fd         # Simple, fast alternative to 'find'
  fzf        # Fuzzy finder
  jq         # JSON processor
  kubectl    # Kubernetes CLI
  lazygit    # Simple terminal UI for Git
  lego       # Let's Encrypt client
  mise       # Dev tool version manager
  scc        # Code counter
  bottom     # System monitor
  neovim     # Modern Vim alternative
  helix      # Modal text editor
  starship   # Customizable shell prompt
  rust       # Rust programming language
  go         # Go programming language
  zellij     # Terminal workspace manager
  gh         # GitHub CLI
  bat        # Cat command alternative with syntax highlighting
  git-delta  # Syntax-highlighting pager for Git
  sops       # Secrets management tool
  yq         # YAML processor
  postgresql # PostgreSQL database
)

for tool in "${CLI_TOOLS[@]}"; do
  install_brew_package "$tool"
done

# Install GUI apps via Homebrew Cask
CASK_APPS=(
  zed         # Zed code editor
  docker      # Docker for Mac
  ghostty     # Ghostty terminal emulator
  postico     # PostgreSQL client
  1password   # 1Password password manager
)

for app in "${CASK_APPS[@]}"; do
  install_brew_cask "$app"
done

echo "All tools and applications installed successfully!"
