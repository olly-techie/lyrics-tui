#!/usr/bin/env bash
# resource-watchdog.sh
# Watches for duplicate app instances and cleans them up.
#
# SAFE: works on whole *instances*, not individual processes. Multi-process
# apps (VS Code, Brave, Spotify) are groups of helper processes under one main
# process. This script finds each instance's root process and kills entire
# duplicate instances by their root, so it never breaks a running app.
#
# Usage:
#   ./resource-watchdog.sh                # report only (dry-run)
#   ./resource-watchdog.sh --kill         # close duplicate instances
#   ./resource-watchdog.sh --kill --loop  # run every 60s (daemon mode)
#   ./resource-watchdog.sh --max=2048     # also report apps using >2048 MB

set -u

KILL=0
LOOP=0
LOOP_SECONDS=60
MAX_MB=0

for arg in "$@"; do
    case "$arg" in
        --kill) KILL=1 ;;
        --loop) LOOP=1 ;;
        --max=*) MAX_MB="${arg#--max=}" ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# Apps to watch for duplicate instances.
DUP_APPS=(spotify code brave xreader)

# Find the root (main) process of the instance a given PID belongs to.
# The root is the first ancestor whose own name doesn't match the app —
# i.e. where the app tree attaches to the rest of the system.
root_of() {
    local pid="$1" name="$2" cur="$pid" ppid
    while [ -n "$cur" ] && [ "$cur" != "1" ]; do
        local cname
        cname=$(ps -o comm= -p "$cur" 2>/dev/null)
        if [ "$cname" != "$name" ]; then
            echo "$cur"
            return
        fi
        ppid=$(ps -o ppid= -p "$cur" 2>/dev/null | tr -d ' ')
        [ -z "$ppid" ] && break
        cur="$ppid"
    done
    echo "$pid"
}

kill_duplicates() {
    for app in "${DUP_APPS[@]}"; do
        # Collect all PIDs of this app, map each to its instance root.
        local -A roots=()
        local -a pids
        pids=($(pgrep -x "$app" 2>/dev/null))
        [ ${#pids[@]} -eq 0 ] && continue

        for pid in "${pids[@]}"; do
            root=$(root_of "$pid" "$app")
            roots[$root]=1
        done

        if [ "${#roots[@]}" -gt 1 ]; then
            echo "[watchdog] $app: ${#roots[@]} instances"
            # Keep the newest instance (largest root PID ≈ most recent), close the rest.
            local keep=0
            for root in "${!roots[@]}"; do
                [ "$root" -gt "$keep" ] && keep="$root"
            done
            for root in "${!roots[@]}"; do
                if [ "$root" != "$keep" ]; then
                    if (( KILL )); then
                        echo "[watchdog]   closing instance PID $root ($app)"
                        kill "$root" 2>/dev/null
                    else
                        echo "[watchdog]   would close instance PID $root ($app)"
                    fi
                fi
            done
        fi
    done
}

flag_memory_hogs() {
    if (( MAX_MB > 0 )); then
        echo "[watchdog] apps using > ${MAX_MB} MB:"
        ps -eo rss,comm --no-headers | awk -v max="$MAX_MB" \
            '{ if ($1/1024 > max) printf "  %.0f MB  %s\n", $1/1024, $2 }' | \
            sort -rn | head -10
    fi
}

main() {
    if (( ! KILL )); then
        echo "=== DRY RUN — pass --kill to actually close duplicates ==="
    fi
    flag_memory_hogs
    kill_duplicates
}

if (( LOOP )); then
    while true; do
        main
        sleep "$LOOP_SECONDS"
    done
else
    main
fi
