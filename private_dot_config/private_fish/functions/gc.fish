function gc
  set -l branch (git branch --format "%(refname:short)" | fzf)
  if test "git rev-parse --verify $branch 2>/dev/null"
    git checkout $branch
  end
end
