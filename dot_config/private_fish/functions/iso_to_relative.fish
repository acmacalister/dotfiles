function iso_to_relative
    # The ISO8601 timestamp input
    set timestamp $argv[1]

    # Get the current time in seconds since epoch
    set now (date +%s)

    # Convert the ISO8601 timestamp to seconds since epoch
    set timestamp_sec (date -j -f "%Y-%m-%dT%H:%M:%SZ" $timestamp +"%s")

    # Calculate the time difference
    set diff (math $now - $timestamp_sec)

    # Determine the relative time
    if test $diff -lt 60
        echo "$diff seconds ago"
    else if test $diff -lt 3600
        set minutes (math $diff / 60)
        echo "$minutes minutes ago"
    else if test $diff -lt 86400
        set hours (math $diff / 3600)
        echo "$hours hours ago"
    else
        set days (math $diff / 86400)
        echo "$days days ago"
    end
end
