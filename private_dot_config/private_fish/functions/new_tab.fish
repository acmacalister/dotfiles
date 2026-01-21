function new_tab
    set -l tab_name $argv[1]

    if not set -q ZELLIJ
        echo "Not in a Zellij session"
        return 1
    end

    if test -z "$tab_name"
        # Create tab with dev layout, let Zellij auto-name it
        zellij action new-tab --layout dev
    else
        # Create tab with dev layout and custom name
        zellij action new-tab --layout dev --name "$tab_name"
    end
end
