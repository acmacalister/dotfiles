function dk --wraps='docker kill' --description 'alias dk=docker kill'
  docker kill $argv; 
end
