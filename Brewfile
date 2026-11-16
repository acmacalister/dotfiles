# Work laptops often ship apps via MDM or direct download. Declaring a cask for
# an app that is already present (but not managed by Homebrew) makes
# `brew bundle` fail, so reuse the existing install instead.
def existing_install?(apps: [], bins: [], paths: [])
  app_dirs = ["/Applications", File.expand_path("~/Applications")]
  search_path = (ENV["HOMEBREW_PATH"] || ENV["PATH"] || "").split(":")
  apps.any? { |app| app_dirs.any? { |dir| File.directory?(File.join(dir, "#{app}.app")) } } ||
    bins.any? { |bin| search_path.any? { |dir| File.executable?(File.join(dir, bin)) } } ||
    paths.any? { |path| File.exist?(path) }
end

def app_cask(token, apps: [], bins: [], paths: [])
  prefix = ENV["HOMEBREW_PREFIX"] || "/opt/homebrew"
  managed_by_brew = File.directory?(File.join(prefix, "Caskroom", token.split("/").last))
  return if !managed_by_brew && existing_install?(apps: apps, bins: bins, paths: paths)

  cask token
end

tap "1password/tap", trusted: true
tap "charmbracelet/tap", trusted: true
tap "derailed/k9s", trusted: true
tap "derailed/popeye", trusted: true
tap "fairwindsops/tap", "https://github.com/FairwindsOps/homebrew-tap", trusted: true
tap "goreleaser/tap", trusted: true
tap "hashicorp/tap", trusted: true
tap "nats-io/nats-tools", trusted: true
tap "ory/tap", trusted: true
tap "oven-sh/bun", trusted: true
tap "pulumi/tap", trusted: true
tap "runreveal/runreveal", trusted: true
tap "rwx-cloud/tap", trusted: true
tap "trufflesecurity/trufflehog", trusted: true

# Shell, prompt, terminal workspace
brew "fish"
brew "starship"
brew "zellij"
brew "herdr"
brew "chezmoi"
brew "coreutils"
brew "curl"
brew "expect"
brew "telnet"
brew "mosh"

# Editors and language servers
brew "neovim"
brew "helix"
brew "micro"
brew "gopls"
brew "rust-analyzer"
brew "typescript-language-server"
brew "zls"
brew "stylua"
brew "hashicorp/tap/terraform-ls"

# Search, files, and text
brew "bat"
brew "fd"
brew "fzf"
brew "ripgrep"
brew "jq"
brew "yq"
brew "gdu"
brew "yazi"
brew "superfile"
brew "pandoc"
brew "docutils"
brew "gnuplot"
brew "mpv"
brew "watchman"
brew "bottom"

# Git and code quality
brew "gh"
brew "git-delta"
brew "lazygit"
brew "lefthook"
brew "forgejo-cli"
brew "act"
brew "actionlint"
brew "yamllint"
brew "black"
brew "cloc"
brew "scc"

# Languages and runtimes
brew "go"
brew "golangci-lint"
brew "gosec"
brew "govulncheck"
brew "zig"
brew "oven-sh/bun/bun"
brew "elixir"
brew "rbenv"
brew "ruby-build"
brew "pipx"
brew "python@3.10"
brew "python@3.11"
brew "python@3.12"
brew "cmake"
brew "wasmtime"
brew "tailwindcss"
brew "hugo"
brew "mise"

# AI and local models
brew "charmbracelet/tap/crush"
brew "charmbracelet/tap/mods"
brew "charmbracelet/tap/glow"
brew "llama.cpp"
brew "ollama"

# Containers, VMs, Kubernetes
brew "colima", restart_service: :changed
brew "docker"
brew "docker-compose"
brew "docker-credential-helper"
brew "qemu"
brew "macpine"
brew "kubernetes-cli"
brew "helm"
brew "kube-score"
brew "kubeconform"
brew "kubent"
brew "derailed/k9s/k9s"
brew "derailed/popeye/popeye"
brew "fairwindsops/tap/pluto"

# Cloud, infra, and deploy
brew "awscli"
brew "doctl"
brew "flyctl"
brew "ansible"
brew "ansible-lint"
brew "hashicorp/tap/packer"
brew "hashicorp/tap/terraform"
brew "pulumi/tap/pulumi"
brew "rwx-cloud/tap/rwx"
brew "ory/tap/cli"
brew "runreveal/runreveal/runreveal"
brew "lego"
brew "rclone"
brew "fastlane"

# Data, messaging, and load testing
brew "libpq"
brew "postgresql@18"
brew "dbmate"
brew "redis"
brew "nats-server"
brew "nats-io/nats-tools/nats"
brew "overmind"
brew "k6"
brew "hey"

# Secrets and supply chain
brew "age"
brew "sops"
brew "gitleaks"
brew "trivy"
brew "osv-scanner"
brew "semgrep"
brew "checkov"
brew "trufflesecurity/trufflehog/trufflehog"

# Offensive security / pentest tooling. Some corporate endpoint security
# flags these, so set DOTFILES_SKIP_SECURITY_TOOLS=1 to leave them out.
unless ENV["DOTFILES_SKIP_SECURITY_TOOLS"]
  brew "nmap"
  brew "nuclei"
  brew "ffuf"
  brew "httpx"
  brew "nikto"
  brew "sqlmap"
  brew "testssl"
  app_cask "burp-suite", apps: ["Burp Suite", "Burp Suite Community Edition", "Burp Suite Professional"]
  app_cask "caido", apps: ["Caido"]
  app_cask "mitmproxy", bins: ["mitmproxy"]
end

# Apps
app_cask "1password", apps: ["1Password", "1Password 7"]
app_cask "1password-cli", bins: ["op"]
app_cask "ghostty", apps: ["Ghostty"]
app_cask "zed", apps: ["Zed"]
app_cask "claude-code", bins: ["claude"]
app_cask "claude", apps: ["Claude"]
app_cask "chatgpt", apps: ["ChatGPT"]
app_cask "cmux", apps: ["cmux"]
app_cask "raycast", apps: ["Raycast"]
app_cask "cleanshot", apps: ["CleanShot X"]
app_cask "tailscale-app", apps: ["Tailscale"]
app_cask "google-chrome", apps: ["Google Chrome"]
app_cask "slack", apps: ["Slack"]
app_cask "postico", apps: ["Postico 2", "Postico"]
app_cask "multipass", bins: ["multipass"]
app_cask "fossa", bins: ["fossa"]
app_cask "goreleaser/tap/goreleaser", bins: ["goreleaser"]
app_cask "android-platform-tools", bins: ["adb"]
app_cask "zulu@17", paths: ["/Library/Java/JavaVirtualMachines/zulu-17.jdk"]
app_cask "swiftcord", apps: ["Swiftcord"]
