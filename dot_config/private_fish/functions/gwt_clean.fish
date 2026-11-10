function gwt_clean --description 'Interactively select and delete git worktrees'
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$git_root"
        echo "Not in a git repository"
        return 1
    end

    # Parse worktree list into parallel arrays
    set -l paths
    set -l branches

    for line in (git worktree list --porcelain)
        if string match -q 'worktree *' $line
            set -a paths (string replace 'worktree ' '' $line)
        else if string match -q 'branch *' $line
            set -a branches (string replace 'branch refs/heads/' '' $line)
        else if string match -q detached $line
            set -a branches '(detached)'
        else if string match -q bare $line
            set -a branches '(bare)'
        end
    end

    if test (count $paths) -le 1
        echo "No removable worktrees found"
        return 0
    end

    # Build display labels (skip first entry — main worktree / bare repo)
    # Use paths as the selectable values, display branch + path
    set -l display_lines
    set -l selectable_paths

    for i in (seq 2 (count $paths))
        set -a display_lines "$branches[$i]  →  $paths[$i]"
        set -a selectable_paths $paths[$i]
    end

    set -l selected_display (printf '%s\n' $display_lines | fzf --multi --header 'Select worktrees to delete (TAB to multi-select)')

    if test -z "$selected_display"
        echo "Nothing selected"
        return 0
    end

    # Map selected display lines back to paths
    set -l selected_paths
    for sel in $selected_display
        for i in (seq 1 (count $display_lines))
            if test "$sel" = "$display_lines[$i]"
                set -a selected_paths $selectable_paths[$i]
                break
            end
        end
    end

    echo "Will delete:"
    for p in $selected_paths
        echo "  $p"
    end

    read -l -P "Confirm? [y/N] " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo Aborted
        return 0
    end

    for p in $selected_paths
        echo "Removing $p..."
        git worktree remove --force "$p"
    end

    git worktree prune
    echo Done
end
