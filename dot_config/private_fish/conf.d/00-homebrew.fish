# Runs before the other conf.d files so Homebrew tools (rbenv, go, brew) are on
# PATH even on a fresh Mac where nothing else has added them yet.
fish_add_path /opt/homebrew/bin /opt/homebrew/sbin
