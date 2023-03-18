if status is-interactive
    starship init fish | source
end
set -gx GOPATH (go env GOPATH)
set -gx BREW_PATH (brew --prefix)
set -gx VOLTA_HOME "$HOME/.volta"
fish_add_path $VOLTA_HOME/bin
fish_add_path $HOME/.cargo/bin
fish_add_path $BREW_PATH/opt/python@3.9/libexec/bin
alias python python3

# pnpm
set -gx PNPM_HOME "/Users/austin/Library/pnpm"
set -gx PATH "$PNPM_HOME" $PATH
# pnpm end
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/austin/google-cloud-sdk/path.fish.inc' ]; . '/Users/austin/google-cloud-sdk/path.fish.inc'; end

source /Users/austin/.docker/init-fish.sh || true # Added by Docker Desktop
