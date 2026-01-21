# Dotfiles

My personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Installation

### Quick Start

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install chezmoi and apply dotfiles
brew install chezmoi
chezmoi init --apply acmacalister
```

### Full Setup

Run the install script to set up everything:

```bash
curl -fsSL https://raw.githubusercontent.com/acmacalister/dotfiles/master/install.sh | bash
```

## What's Included

### Shell
- **Fish** - Primary shell with custom functions and aliases
- **Starship** - Cross-shell prompt

### Terminal
- **Ghostty** - Terminal emulator
- **Zellij** - Terminal workspace/multiplexer with custom layouts

### Editors
- **Helix** - Modal text editor
- **Neovim** - (local config, not synced)

### CLI Tools
Installed via Homebrew:
- `ripgrep`, `fd`, `fzf` - Search utilities
- `bat`, `git-delta` - Better cat/diff
- `lazygit` - Git TUI
- `jq`, `yq` - JSON/YAML processors
- `kubectl`, `doctl` - Cloud CLIs
- `just` - Task runner
- `mise` - Dev tool version manager
- `sops` - Secrets management

### GUI Apps
- Docker
- Zed
- Postico
- 1Password

## Fish Functions

| Function | Description |
|----------|-------------|
| `d` | Docker alias |
| `dc` | Docker Compose alias |
| `k` | Kubectl alias |
| `dev` | Start Zellij dev session |
| `new_tab` | Create new Zellij tab with dev layout |
| `new_worktree_tab` | Create git worktree in new Zellij tab |
| `gc` | Git checkout with fzf |
| `gd` | Git delete branches with fzf |
| `n` | Fuzzy search + open in nvim |
| `restart` | Restart k8s deployment |
| `rollback` | Rollback k8s deployment image |

## Zellij Layouts

- **dev** - Split panes for development
- **worktree** - Layout for git worktrees
- **curri** - Custom work layout with Helix, Overmind, and Crush

## Key Bindings (Zellij)

| Key | Action |
|-----|--------|
| `Ctrl+g` | Toggle locked mode (pass all keys to app) |
| `Ctrl+p` | Pane mode |
| `Ctrl+t` | Tab mode |
| `Ctrl+n` | Resize mode |
| `Ctrl+h` | Move mode |
| `Ctrl+s` | Scroll mode |
| `Ctrl+o` | Session mode |
| `Ctrl+b` | Tmux mode |

## Secrets Management

Secrets are managed via 1Password templates. Required items:
- `Private/AWS Bedrock Token` (field: `credential`)
- `Private/AWS ECR Registry` (field: `credential`)

## Requirements

- macOS
- [Homebrew](https://brew.sh/)
- [1Password CLI](https://developer.1password.com/docs/cli/) (for secrets)

## License

MIT
