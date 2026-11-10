#!/usr/bin/env fish
# Save to ~/.config/fish/functions/zj-worktree.fish

function zj-worktree --description "Manage git worktrees with Zellij tabs"
    # Parse flags
    argparse 'a/ai=' -- $argv
    or return 1

    set -l cmd $argv[1]
    set -l branch $argv[2]

    # AI CLI selection: flag > env var > default
    set -l ai_cmd
    if set -q _flag_ai
        set ai_cmd $_flag_ai
    else if set -q ZJ_WORKTREE_AI
        set ai_cmd $ZJ_WORKTREE_AI
    else
        set ai_cmd claude
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    or begin
        echo "Error: Not in a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l worktree_base (dirname $repo_root)/$repo_name-worktrees

    switch $cmd
        case new n
            if test -z "$branch"
                set branch (_zj_worktree_pick_branch $repo_root)
                test -z "$branch" && return 1
            end
            _zj_worktree_new $branch $repo_root $worktree_base $ai_cmd

        case open o
            set -l wt (_zj_worktree_pick_existing $repo_root)
            test -z "$wt" && return 1
            _zj_worktree_open $wt "" $ai_cmd

        case list ls
            _zj_worktree_list $repo_root

        case clean cleanup
            _zj_worktree_cleanup $repo_root $worktree_base

        case remove rm
            if test -z "$branch"
                set branch (_zj_worktree_pick_existing $repo_root | xargs basename)
                test -z "$branch" && return 1
            end
            _zj_worktree_remove $branch $repo_root $worktree_base

        case ai
            # Interactive AI picker, then open existing or new
            set ai_cmd (_zj_worktree_pick_ai)
            test -z "$ai_cmd" && return 1
            if test -n "$branch"
                _zj_worktree_new $branch $repo_root $worktree_base $ai_cmd
            else
                set branch (_zj_worktree_pick_branch $repo_root)
                test -z "$branch" && return 1
                _zj_worktree_new $branch $repo_root $worktree_base $ai_cmd
            end

        case '*'
            if test -n "$cmd"
                _zj_worktree_new $cmd $repo_root $worktree_base $ai_cmd
            else
                echo "Usage: zj-worktree [options] [command] [branch-name]"
                echo ""
                echo "Options:"
                echo "  -a, --ai <cmd>      AI CLI to use (claude, crush, etc.)"
                echo ""
                echo "Commands:"
                echo "  new, n [branch]     Create worktree and open tab (fzf if no branch)"
                echo "  open, o             Open existing worktree (fzf picker)"
                echo "  ai [branch]         Pick AI CLI interactively, then branch"
                echo "  list, ls            List all worktrees"
                echo "  clean, cleanup      Remove worktrees for merged/deleted branches"
                echo "  remove, rm [branch] Remove specific worktree (fzf if no branch)"
                echo ""
                echo "Quick usage: zj-worktree <branch-name>"
                echo "With AI:     zj-worktree -a crush <branch-name>"
                echo ""
                echo "Environment:"
                echo "  ZJ_WORKTREE_AI      Default AI CLI (default: claude)"
                echo ""
                echo "Current AI: $ai_cmd"
            end
    end
end

function _zj_worktree_pick_ai
    printf "claude\ncrush" | fzf \
        --height=40% \
        --layout=reverse \
        --border \
        --prompt="AI CLI> " \
        --header="Select AI agent"
end

function _zj_worktree_pick_branch
    set -l repo_root $argv[1]

    begin
        git -C $repo_root branch --format='%(refname:short)'
        git -C $repo_root branch -r --format='%(refname:short)' | sed 's|^origin/||' | grep -v '^HEAD$'
    end | sort -u | fzf \
        --height=40% \
        --layout=reverse \
        --border \
        --prompt="Branch> " \
        --header="Select branch (or type new name)" \
        --print-query | tail -1
end

function _zj_worktree_pick_existing
    set -l repo_root $argv[1]

    git -C $repo_root worktree list | grep -v "$repo_root " | fzf \
        --height=40% \
        --layout=reverse \
        --border \
        --prompt="Worktree> " \
        --header="Select existing worktree" | awk '{print $1}'
end

function _zj_worktree_new
    set -l branch $argv[1]
    set -l repo_root $argv[2]
    set -l worktree_base $argv[3]
    set -l ai_cmd $argv[4]

    # Sanitize branch name for directory (replace / with -)
    set -l dir_name (string replace -a '/' '-' $branch)
    set -l worktree_path $worktree_base/$dir_name

    mkdir -p $worktree_base

    if not test -d $worktree_path
        if git -C $repo_root worktree add $worktree_path $branch 2>/dev/null
            echo "Created worktree for existing branch: $branch"
        else if git -C $repo_root worktree add -b $branch $worktree_path
            echo "Created worktree with new branch: $branch"
        else
            echo "Error: Failed to create worktree"
            return 1
        end
    else
        echo "Using existing worktree: $worktree_path"
    end

    _zj_worktree_open $worktree_path $branch $ai_cmd
end

function _zj_worktree_open
    set -l worktree_path $argv[1]
    set -l tab_name $argv[2]
    set -l ai_cmd $argv[3]

    # Use directory name as tab name if not provided
    test -z "$tab_name" && set tab_name (basename $worktree_path)

    # Default to claude if not specified
    test -z "$ai_cmd" && set ai_cmd claude

    if test -n "$ZELLIJ"
        # Inside Zellij - create new tab
        set -l tmp_layout (mktemp).kdl
        echo "layout {
    pane split_direction=\"vertical\" {
        pane command=\"$ai_cmd\"
        pane
    }
}" > $tmp_layout
        zellij action new-tab --layout $tmp_layout --cwd $worktree_path --name $tab_name
        rm -f $tmp_layout
    else
        # Outside Zellij - start new session
        set -l session_name (basename (git rev-parse --show-toplevel 2>/dev/null; or echo $tab_name))
        set -l tmp_layout (mktemp).kdl
        set -l main_repo (git rev-parse --show-toplevel)

        echo "layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location=\"tab-bar\"
        }
        children
        pane size=2 borderless=true {
            plugin location=\"status-bar\"
        }
    }
    tab name=\"main\" cwd=\"$main_repo\" {
        pane
    }
    tab name=\"$tab_name\" cwd=\"$worktree_path\" focus=true {
        pane split_direction=\"vertical\" {
            pane command=\"$ai_cmd\"
            pane
        }
    }
}" > $tmp_layout

        echo "Starting new Zellij session: $session_name"
        zellij --session $session_name --layout $tmp_layout
        rm -f $tmp_layout
    end
end

function _zj_worktree_list
    set -l repo_root $argv[1]
    echo "Current worktrees:"
    git -C $repo_root worktree list
end

function _zj_worktree_cleanup
    set -l repo_root $argv[1]
    set -l worktree_base $argv[2]
    set -l removed 0

    echo "Scanning for stale worktrees..."

    git -C $repo_root worktree prune

    set -l main_branch (git -C $repo_root symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    test -z "$main_branch" && set main_branch main

    for wt_line in (git -C $repo_root worktree list --porcelain | grep "^worktree " | sed 's/^worktree //')
        test $wt_line = $repo_root && continue

        set -l wt_branch (git -C $wt_line branch --show-current 2>/dev/null)
        test -z "$wt_branch" && continue

        if git -C $repo_root branch --merged $main_branch | grep -q "^\s*$wt_branch\$"
            echo "  Removing merged branch worktree: $wt_branch"
            git -C $repo_root worktree remove --force $wt_line 2>/dev/null
            set removed (math $removed + 1)
            continue
        end

        if not git -C $repo_root ls-remote --exit-code --heads origin $wt_branch &>/dev/null
            read -l -P "  Branch '$wt_branch' deleted on remote. Remove worktree? [y/N] " confirm
            if test "$confirm" = y -o "$confirm" = Y
                git -C $repo_root worktree remove --force $wt_line 2>/dev/null
                set removed (math $removed + 1)
            end
        end
    end

    if test $removed -eq 0
        echo "No stale worktrees found."
    else
        echo "Removed $removed worktree(s)."
    end
end

function _zj_worktree_remove
    set -l branch $argv[1]
    set -l repo_root $argv[2]
    set -l worktree_base $argv[3]

    set -l dir_name (string replace -a '/' '-' $branch)
    set -l worktree_path $worktree_base/$dir_name

    if test -d $worktree_path
        read -l -P "Remove worktree for '$branch'? [y/N] " confirm
        if test "$confirm" = y -o "$confirm" = Y
            git -C $repo_root worktree remove --force $worktree_path
            echo "Removed worktree: $branch"
        end
    else
        echo "Worktree not found: $worktree_path"
        return 1
    end
end
