# AGENTS.md

## Overview

Personal macOS dotfiles managed with **[chezmoi](https://www.chezmoi.io/)**. This repo is the chezmoi source directory: files here are templates/sources that chezmoi transforms and deploys into `~` and `~/.config/`. chezmoi run scripts also provision the machine (Homebrew packages, language toolchains, fish plugins).

## Chezmoi Conventions

| Prefix / suffix | Meaning |
|--------|---------|
| `dot_` | Deployed as `.` (e.g., `dot_config/` → `~/.config/`) |
| `private_` | File/directory gets restrictive permissions (0700/0600) |
| `executable_` | File is deployed with the executable bit |
| `empty_` | File is deployed even if empty |
| `.tmpl` suffix | Processed as a Go template before deployment |
| `.literal` suffix | Stops suffix parsing (e.g. `foo.tmpl.literal` deploys as `foo.tmpl`, not rendered) |
| `run_onchange_` | Script in `.chezmoiscripts/` that reruns when its rendered content changes |

- **Everything under `~/.config` lives in `dot_config/`.** Never add a `private_dot_config/` directory: two source dirs for the same target puts chezmoi into an "inconsistent state" error. Use `private_` on the subdirectory instead (e.g. `dot_config/private_fish/`).
- `.chezmoiignore` is a template. Root files (README, AGENTS.md, install.sh, Brewfile, scripts/) are never deployed, and context-specific files are skipped on machines without that context.
- `.chezmoitemplates/` holds fragments that other templates `include` (not deployed).

## Contexts (machine profiles)

Each machine has a comma-separated `contexts` value (`personal`, `curri`, `render`), prompted once by `.chezmoi.toml.tmpl` and stored in `~/.config/chezmoi/chezmoi.toml`. Change it there and run `chezmoi apply`, or pass `DOTFILES_CONTEXTS=render` to `install.sh`.

A context controls:

| Mechanism | Where |
|-----------|-------|
| Which env vars are rendered into `~/.config/fish/conf.d/secrets.fish` | `dot_config/private_secrets/<context>.env` |
| Which crush providers/MCP servers are configured | `.chezmoitemplates/crush/<context>.json`, merged over `base.json` |
| Which files are deployed at all | `{{ if not (has "<context>" $contexts) }}` blocks in `.chezmoiignore` |
| Inline conditionals | e.g. `dot_config/zed/private_settings.json.tmpl`, `private_dot_npmrc.tmpl` |

**Curri-only things must stay gated behind the `curri` context** (secrets, Curri gateway/Switchboard in crush and Zed, `kcurri`, `subnet_ips`, `rollback`, the `curri` zellij layout, switchboard config, the `pr-shepherd` and `sentry-debug` skills). When adding anything employer-specific, gate it the same way.

### Secrets `.env` format

```
NAME=op://Vault/Item/field     # read from 1Password
NAME=$OTHER                    # copy another variable defined earlier in the file
NAME=literal value             # plain, non-secret value
OP_ACCOUNT=my.1password.com    # optional; applies to the op:// refs after it
```

These files contain only 1Password references, never secret values. The `secrets` fish function (`secrets list|load|unload <context>`) reads the same files at runtime.

### Templates and secrets

Secrets come from **1Password** via `onepasswordRead`. Never commit a literal secret. Templates that read 1Password:

- `dot_config/private_fish/conf.d/secrets.fish.tmpl` — generated from the context `.env` files
- `dot_config/private_fish/functions/rollback.fish.tmpl` — ECR registry (curri only)
- `dot_config/private_switchboard/private_config.json.tmpl` — local switchboard (curri only)
- `private_dot_npmrc.tmpl` — npm token (personal only)

`dot_config/crush/crush.json.tmpl` and `dot_config/zed/private_settings.json.tmpl` contain no secrets; crush expands `$CF_AIG_TOKEN`, `$STITCH_API_KEY`, `$SWITCHBOARD_MCP_TOKEN` from the environment.

If `chezmoi apply` fails on a template, a 1Password item or field is missing. `scripts/seed-1password.sh` creates the items from an existing machine's plaintext config (it never overwrites).

### Provisioning scripts (`.chezmoiscripts/`)

| Script | When it reruns | What it does |
|--------|----------------|--------------|
| `run_onchange_before_10-brew-bundle.sh.tmpl` | `Brewfile` changes | `brew bundle` |
| `run_onchange_after_20-dev-tools.sh` | script changes | `go install` tools, `fisher update`, Node via nvm + npm globals, rustup, gh extensions |

Local Ollama models are **not** pulled automatically. `~/.local/bin/local-models` (source `dot_local/bin/executable_local-models`) pulls them on demand and only recommends models that fit the machine's memory. Models from restricted origins (e.g. Qwen) require `--allow-restricted-origin`.

### Commands

```bash
chezmoi apply          # Deploy all managed files and run changed scripts
chezmoi diff           # Preview changes before applying
chezmoi managed        # List managed targets (also catches layout errors)
chezmoi cat <target>   # Render one target (needs 1Password CLI for secrets)
chezmoi update         # Pull latest from remote and apply
```

To test templates without 1Password, point `[onepassword] command` at a fake `op` script in a throwaway `--config` file.

## Repository Structure

```
.
├── .chezmoi.toml.tmpl                  # Prompts: git name/email, contexts
├── .chezmoiignore                      # Template; gates files by context
├── .chezmoiscripts/                    # Provisioning scripts
├── .chezmoitemplates/crush/            # base.json + per-context crush fragments
├── Brewfile
├── install.sh                          # Bootstrap: Homebrew → 1Password → chezmoi init --apply → fish shell
├── scripts/seed-1password.sh           # One-time: move local plaintext secrets into 1Password
├── dot_actrc
├── dot_gitconfig.tmpl
├── dot_local/bin/executable_local-models
├── private_dot_npmrc.tmpl
├── private_dot_ssh/private_config      # Generic SSH defaults; host entries go in ~/.ssh/config.local
└── dot_config/
    ├── crush/                          # crush.json.tmpl + skills/
    ├── gh/, gh-dash/
    ├── ghostty/config
    ├── helix/config.toml
    ├── herdr/config.toml
    ├── nvim/                           # LazyVim
    ├── private_fish/                   # config.fish, conf.d/, functions/, fish_plugins
    ├── private_git/private_ignore      # Global gitignore
    ├── private_secrets/                # <context>.env (1Password refs only)
    ├── private_switchboard/
    ├── starship.toml
    ├── zed/
    └── zellij/
```

## Fish Shell Functions

One function per file in `dot_config/private_fish/functions/`, filename matches function name (private `_helpers` may live in the same file). Plugins (fisher, nvm.fish, fish-rbenv) are listed in `fish_plugins` and installed by `fisher update`.

Simple aliases use `--wraps` and `--description`:

```fish
function d --wraps=docker --description 'alias d docker'
  docker $argv
end
```

Complex functions validate args with `test (count $argv)`, print usage on misuse, and `return 1` on error.

## Gotchas

1. **1Password CLI must be connected** (1Password app → Settings → Developer → Integrate with 1Password CLI) before `chezmoi apply`, or secret templates fail.
2. **`conf.d/00-homebrew.fish` puts Homebrew on PATH** before the other conf.d files; a fresh Mac's fish has no Homebrew on PATH and `rbenv`/`go`/`brew` are needed early.
3. **Zellij keybinds use `clear-defaults=true`** — only bindings in `config.kdl` work.
4. **Node is pinned** to v22.18.0 (`nvm use` in `config.fish`, installed by the dev-tools script).
5. **Offensive security tools** in the Brewfile are skipped when `DOTFILES_SKIP_SECURITY_TOOLS=1` is set.
6. **crush.json is a template now.** Settings changed in the Crush UI are overwritten by the next `chezmoi apply`; move them into `.chezmoitemplates/crush/*.json` instead.
7. **The repo is public.** Only 1Password references go in the repo, never values.
