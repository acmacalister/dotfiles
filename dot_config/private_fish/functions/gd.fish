function gd
  set -l branches_to_delete (git branch --format "%(refname:short)" | fzf --multi)
  if test "$branches_to_delete"
    git branch --delete --force $branches_to_delete
  end
end
