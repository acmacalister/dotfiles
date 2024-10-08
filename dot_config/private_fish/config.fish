if status is-interactive
    starship init fish | source
end
set -gx GOPATH (go env GOPATH)
set -gx BREW_PATH (brew --prefix)
set -Ux EDITOR nvim
set -Ux VISUAL nvim
fish_add_path $HOME/.cargo/bin
fish_add_path $BREW_PATH/opt/python@3.9/libexec/bin
alias python python3
nvm use v18.19.1

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/austin/google-cloud-sdk/path.fish.inc' ]; . '/Users/austin/google-cloud-sdk/path.fish.inc'; end

source /Users/austin/.docker/init-fish.sh || true # Added by Docker Desktop
