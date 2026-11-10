# Dotfiles

My personal macOS dotfiles, managed with [chezmoi](https://www.chezmoi.io/). Secrets come from 1Password at apply time and never live in this repo.

## New machine

```bash
curl -fsSL https://raw.githubusercontent.com/acmacalister/dotfiles/master/install.sh | bash

# or pick the machine's contexts up front, e.g. a Render work laptop:
curl -fsSL https://raw.githubusercontent.com/acmacalister/dotfiles/master/install.sh | DOTFILES_CONTEXTS=personal,render bash
```

`install.sh` installs the Xcode Command Line Tools, Homebrew, 1Password and its CLI, waits until the CLI can reach your vault, then runs `chezmoi init --apply acmacalister` and makes fish the default shell. chezmoi asks for your git name, email, and contexts once, then its scripts:

1. `brew bundle` installs everything in [`Brewfile`](Brewfile)
2. install Go tools, fish plugins, Node v22.18.0 + global npm CLIs, Rust, and gh extensions

Set `DOTFILES_SKIP_SECURITY_TOOLS=1` before running to leave out the pentest tools (nmap, sqlmap, Burp, ZAP, ...), which some corporate endpoint security flags.

After it finishes: `gh auth login`, set up SSH keys, and open a new terminal.

## Contexts

A context decides which secrets, configs, and tools a machine gets. Set them at install time, or later in `~/.config/chezmoi/chezmoi.toml` (`contexts = "personal,curri"`) followed by `chezmoi apply`.

| Context | Gets |
|---------|------|
| `personal` | GitHub PAT, OpenAI, Stitch, DigitalOcean, npm token, `kcc` |
| `curri` | Sentry, Datadog, Expo, k6, read-replica DB, Bedrock, Cloudflare AI Gateway + Switchboard (crush and Zed providers), `kcurri`, `subnet_ips`, `rollback`, curri zellij layout, `pr-shepherd` and `sentry-debug` skills |
| `render` | Placeholder; add 1Password refs to `dot_config/private_secrets/render.env` |

Machines without a context get none of its files or secrets. Secret references live in `dot_config/private_secrets/<context>.env` (1Password refs only, see the format in `personal.env`).

At runtime, the `secrets` fish function works with the same files:

```fish
secrets list              # each context's variables and whether they're set
secrets load curri        # read a context from 1Password into this shell
secrets unload curri      # drop a context's variables from this shell
```

### 1Password items

| Item | Field | Context |
|------|-------|---------|
| GitHub PAT | credential | personal |
| OpenAI API Key | API Key | personal |
| Stitch API Key | credential | personal |
| DigitalOcean Access Token | credential | personal |
| npm Token | credential | personal |
| Sentry Access Token | credential | curri |
| Expo Access Token | token | curri |
| Datadog API Key / Datadog Application Key | credential | curri |
| K6 Load Test | username, password | curri |
| Curri Read Replica URI | credential | curri |
| AWS Bedrock Token | credential | curri |
| Cloudflare AI Gateway Token | Austin Token | curri |
| Switchboard MCP Token | credential | curri |
| AWS ECR Registry | credential | curri |
| Linear MCP | API Key | curri |

To move secrets from an existing machine's plaintext config into 1Password, run `scripts/seed-1password.sh` there (it only creates missing items).

## Local models (optional)

Nothing is downloaded automatically. When you want offline coding models (no AI subscription available), run:

```bash
local-models --list     # catalog, sizes, and what fits this Mac's memory
local-models            # pull the recommended models for this Mac
local-models twil-8b    # pull a specific model
```

| Name | Model | Download | Min memory |
|------|-------|----------|------------|
| `twil-8b` | TwIL-8B Q8 | 9GB | 16GB |
| `flint-q3` | Flint 40B Q3 (Unsloth) | 19GB | 32GB |
| `flint-q4` | Flint 40B Q4 (official) | 26GB | 48GB |
| `flint-q8` | Flint 40B Q8 (Unsloth) | 42GB | 64GB |
| `gpt-oss-20b` | OpenAI gpt-oss 20B | 14GB | 24GB |
| `qwen3.8-27b` | Qwen 3.8 27B Q4 | 18GB | 32GB, needs `--allow-restricted-origin` |

On a 36GB Mac the recommendation is `twil-8b` + `flint-q3`. Pulled models show up in Crush under "Local (Ollama)".

## What's included

- **Shell**: fish (config, functions, fisher plugins), starship
- **Terminal**: Ghostty, Zellij (custom keymap + layouts), herdr
- **Editors**: Neovim (LazyVim), Helix, Zed
- **AI**: Crush config and skills, Ollama + `local-models`, llama.cpp
- **Git**: gitconfig, global ignore, gh + gh-dash
- **Other**: act, npm, SSH defaults (machine-specific hosts go in `~/.ssh/config.local`)

## Fish functions

| Function | Description |
|----------|-------------|
| `secrets` | List, load, or unload 1Password-backed env vars by context |
| `d`, `dc`, `dk`, `dps` | docker, docker compose, docker kill, docker ps |
| `k`, `kj`, `kl` | kubectl, jobs by creation time, logs |
| `kcc` (personal), `kcurri` (curri) | Switch kubectl context |
| `restart`, `rollback` (curri) | Restart / set image on a k8s deployment |
| `p`, `i`, `pi`, `b` | pnpm shortcuts |
| `dev` | Start a Zellij dev session from the git root |
| `new_tab` / `nt` | New Zellij tab with the dev layout |
| `new_worktree_tab` / `nwt` | Create a git worktree in a new Zellij tab |
| `zj-worktree` | Manage git worktrees as Zellij tabs with an AI CLI pane |
| `gwt_clean` | Pick git worktrees to delete with fzf |
| `gc`, `gd` | Checkout / delete branches with fzf |
| `n` | Fuzzy-find a file and open it in nvim |
| `subnet_ips` (curri) | Free IPs across the EKS subnets |
| `iso_to_relative` | ISO8601 timestamp to "N minutes ago" |
| `tac` | `tail -r` |

## Zellij key bindings

| Key | Action |
|-----|--------|
| `Ctrl+g` | Toggle locked mode |
| `Ctrl+p` | Pane mode |
| `Ctrl+t` | Tab mode |
| `Ctrl+n` | Resize mode |
| `Ctrl+h` | Move mode |
| `Ctrl+s` | Scroll mode |
| `Ctrl+o` | Session mode |
| `Ctrl+b` | Tmux mode |

## License

MIT
