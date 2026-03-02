function k
    set -l subcommand $argv[1]
    set -l rest $argv[2..-1]
    set current_time (date +%s)

    switch $subcommand
        case pods
            kubectl get pods -o json | jq -r '
            # Header row (using "Age" now)
            ["Name", "Phase", "Restarts", "Age"],
            (
            .items[] |
            # Calculate age in seconds first, using -1 to signal error
            (try (now - (.metadata.creationTimestamp | fromdateiso8601)) catch -1) as $age_seconds |

            # Format the age based on its value
            (
                if $age_seconds < 0 then "N/A" # Error case from try/catch
                # Less than 60 seconds: show seconds
                elif $age_seconds < 60 then ($age_seconds | floor | tostring) + "s"
                # Less than 1 hour (3600s): show minutes
                elif $age_seconds < 3600 then (($age_seconds / 60) | floor | tostring) + "m"
                # Less than 1 day (86400s): show hours
                elif $age_seconds < 86400 then (($age_seconds / 3600) | floor | tostring) + "h"
                # Otherwise show days
                else (($age_seconds / 86400) | floor | tostring) + "d"
                end
            ) as $human_age | # Store the formatted string

            # Construct the output row
            [
                .metadata.name,
                .status.phase,
                (.status.containerStatuses[0].restartCount // 0),
                $human_age # Use the human-readable age
            ]
            )
            # Format the stream of arrays (header + data) as TSV
            | @tsv
            ' | column -t | fzf --header-lines 1 --preview 'kubectl describe pod {1} | bat --style=numbers --color=always --language yaml'
        case jobs
             kubectl get jobs -o json | jq -r '
            # Header row (using "Age" now)
            ["Name", "Phase", "Restarts", "Age"],
            (
            .items[] |
            # Calculate age in seconds first, using -1 to signal error
            (try (now - (.metadata.creationTimestamp | fromdateiso8601)) catch -1) as $age_seconds |

            # Format the age based on its value
            (
                if $age_seconds < 0 then "N/A" # Error case from try/catch
                # Less than 60 seconds: show seconds
                elif $age_seconds < 60 then ($age_seconds | floor | tostring) + "s"
                # Less than 1 hour (3600s): show minutes
                elif $age_seconds < 3600 then (($age_seconds / 60) | floor | tostring) + "m"
                # Less than 1 day (86400s): show hours
                elif $age_seconds < 86400 then (($age_seconds / 3600) | floor | tostring) + "h"
                # Otherwise show days
                else (($age_seconds / 86400) | floor | tostring) + "d"
                end
            ) as $human_age | # Store the formatted string

            # Construct the output row
            [
                .metadata.name,
                .status.phase,
                (.status.containerStatuses[0].restartCount // 0),
                $human_age # Use the human-readable age
            ]
            )
            # Format the stream of arrays (header + data) as TSV
            | @tsv
            ' | column -t | fzf --header-lines 1 --preview 'kubectl describe job {1} | bat --style=numbers --color=always --language yaml'
        case ll
            set -l pod (kubectl get pods --no-headers -o custom-columns=":metadata.name" | fzf)
            if test -n "$pod"
                kubectl logs -f $pod $rest
            end
        case exec
            set -l pod (kubectl get pods --no-headers -o custom-columns=":metadata.name" | fzf)
            if test -n "$pod"
                set -l shell (kubectl exec -it $pod -- sh -c "command -v bash || command -v sh")
                kubectl exec -it $pod -- $shell
            end
        case ctx
            set -l ctx (kubectl config get-contexts -o name | fzf)
            if test -n "$ctx"
                kubectl config use-context $ctx
            end
        case ns
            set -l ns (kubectl get namespaces --no-headers -o custom-columns=":metadata.name" | fzf)
            if test -n "$ns"
                kubectl config set-context --current --namespace=$ns
            end
        case '*'
            kubectl $argv
    end
end
