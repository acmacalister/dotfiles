function restart
    if test (count $argv) -lt 1
        echo "Usage: restart <deployment-name> [namespace]"
        return 1
    end

    set deployment $argv[1]

    if test (count $argv) -ge 2
        set namespace $argv[2]
    else
        set namespace default
    end

    kubectl rollout restart deployment $deployment -n $namespace
    kubectl rollout status deployment $deployment -n $namespace
end
