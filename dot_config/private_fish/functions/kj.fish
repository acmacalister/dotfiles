function kj --wraps='kubectl get jobs --sort-by=.metadata.creationTimestamp' --description 'alias kj=kubectl get jobs --sort-by=.metadata.creationTimestamp'
  kubectl get jobs --sort-by=.metadata.creationTimestamp $argv; 
end
