function secrets --description 'List, load, or unload 1Password-backed env vars by context'
    set -l dir $HOME/.config/secrets
    set -l cmd $argv[1]
    set -l contexts $argv[2..-1]

    if not test -d $dir
        echo "No secrets contexts found in $dir"
        return 1
    end

    set -l available (path change-extension '' (path basename $dir/*.env))

    switch "$cmd"
        case list ls ''
            if test (count $contexts) -eq 0
                set contexts $available
            end
            for context in $contexts
                if not contains -- $context $available
                    echo "Unknown context '$context' (available: $available)"
                    return 1
                end
                echo $context
                for entry in (_secrets_entries $dir/$context.env)
                    set -l name (string split -m1 = -- $entry)[1]
                    test "$name" = OP_ACCOUNT; and continue
                    if set -q $name
                        echo "  set    $name"
                    else
                        echo "  unset  $name"
                    end
                end
            end

        case load
            if test (count $contexts) -eq 0
                echo "Usage: secrets load <context>... (available: $available)"
                return 1
            end
            if not command -q op
                echo "1Password CLI (op) is not installed"
                return 1
            end
            for context in $contexts
                if not contains -- $context $available
                    echo "Unknown context '$context' (available: $available)"
                    return 1
                end
                set -l account
                for entry in (_secrets_entries $dir/$context.env)
                    set -l parts (string split -m1 = -- $entry)
                    set -l name $parts[1]
                    set -l value $parts[2]
                    if test "$name" = OP_ACCOUNT
                        set account --account $value
                    else if string match -q 'op://*' -- $value
                        set -l secret (op read --no-newline $account $value)
                        or begin
                            echo "Failed to read $name from $value"
                            return 1
                        end
                        set -gx $name $secret
                    else if string match -q '$*' -- $value
                        set -l source_name (string sub -s 2 -- $value)
                        set -gx $name $$source_name
                    else
                        set -gx $name $value
                    end
                end
                echo "Loaded $context"
            end

        case unload
            if test (count $contexts) -eq 0
                echo "Usage: secrets unload <context>... (available: $available)"
                return 1
            end
            for context in $contexts
                if not contains -- $context $available
                    echo "Unknown context '$context' (available: $available)"
                    return 1
                end
                for entry in (_secrets_entries $dir/$context.env)
                    set -l name (string split -m1 = -- $entry)[1]
                    test "$name" = OP_ACCOUNT; and continue
                    set -e $name
                end
                echo "Unloaded $context for this shell"
            end

        case '*'
            echo "Usage: secrets [list|load|unload] [context...]"
            echo ""
            echo "  list [context...]     Show each context's variables and whether they are set"
            echo "  load <context>...     Read a context's variables from 1Password into this shell"
            echo "  unload <context>...   Remove a context's variables from this shell"
            echo ""
            echo "Contexts live in $dir: $available"
            return 1
    end
end

function _secrets_entries --description 'Print NAME=VALUE lines from a secrets .env file'
    for line in (string trim < $argv[1])
        test -z "$line"; and continue
        string match -q '#*' -- $line; and continue
        string match -q '*=*' -- $line; or continue
        set -l parts (string split -m1 = -- $line)
        echo (string trim -- $parts[1])=(string trim -- $parts[2])
    end
end
