function n --wraps='fd --type f --hidden --exclude .git | fzf | xargs nvim' --description 'alias n=fd --type f --hidden --exclude .git | fzf | xargs nvim'
  fd --type f --hidden --exclude .git | fzf | xargs nvim $argv; 
end
