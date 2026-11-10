function dev
    set -l session_name $argv[1]

    # Default to "dev-session" if no name provided
    if test -z "$session_name"
        set session_name dev-session
    end

    # Get current git root
    set git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$git_root"
        echo "Not in a git repository"
        return 1
    end

    # Start or attach to zellij session
    if set -q ZELLIJ
        echo "Already in a Zellij session"
    else
        zellij --layout dev attach -c $session_name
    end
end
