function new_worktree_tab
    set -l branch_name $argv[1]

    if test -z "$branch_name"
        echo "Usage: new_worktree_tab <branch-name>"
        return 1
    end

    # Get git root and worktrees directory
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$git_root"
        echo "Not in a git repository"
        return 1
    end

    set -l worktrees_base (dirname $git_root)
    set -l new_worktree "$worktrees_base/$branch_name"

    # Create worktree if it doesn't exist
    if not test -d "$new_worktree"
        git worktree add "$new_worktree" -b "$branch_name" 2>/dev/null
        or git worktree add "$new_worktree" "$branch_name"
    end

    # Create new Zellij tab with branch name and switch to worktree
    if set -q ZELLIJ
        zellij action new-tab --layout worktree --name "$branch_name" --cwd "$new_worktree"
    else
        echo "Not in a Zellij session"
        return 1
    end
end
