#!/bin/bash
set -euo pipefail
#
# ps-ram — List running processes ordered by RAM consumption
#
# Shows each process's memory usage (% and absolute), an RSS subtotal,
# and a system-wide RAM summary at the bottom.
# The RSS subtotal can exceed system used RAM because shared pages are
# counted once per process.
#
# INSTALL AS A COMMAND
# --------------------
# Option A – symlink (script stays here, changes are instant):
#   sudo ln -s /home/frznn/dev/frznn/linux-scripts/utils/ps-ram.sh /usr/local/bin/ps-ram
#   sudo chmod +x /home/frznn/dev/frznn/linux-scripts/utils/ps-ram.sh
#
# Option B – copy to PATH:
#   sudo cp ps-ram.sh /usr/local/bin/ps-ram && sudo chmod +x /usr/local/bin/ps-ram
#
# Then run with: ps-ram

# Read MemTotal and MemAvailable in a single pass (kB, as reported by the kernel)
read -r TOTAL_KB AVAIL_KB < <(awk '
    /MemTotal/     { total = $2 }
    /MemAvailable/ { avail = $2 }
    END            { print total, avail }
' /proc/meminfo)

if [[ ! "$TOTAL_KB" =~ ^[0-9]+$ || ! "$AVAIL_KB" =~ ^[0-9]+$ || "$TOTAL_KB" -le 0 ]]; then
    echo "Error: could not read valid MemTotal/MemAvailable from /proc/meminfo" >&2
    exit 1
fi

# Parse process RSS (kB), aggregate by process name, then print sorted output.
declare -A RSS_SUM_KB
declare -A PATH_BY_NAME

while read -r pid rss_kb; do
    [[ "$pid" =~ ^[0-9]+$ && "$rss_kb" =~ ^[0-9]+$ ]] || continue
    (( rss_kb > 0 )) || continue

    comm_file="/proc/$pid/comm"
    [[ -r "$comm_file" ]] || continue
    if ! read -r name < "$comm_file"; then
        continue
    fi
    [[ -n "$name" ]] || continue

    path=""
    # Prefer the kernel-reported executable path when available.
    path="$(readlink "/proc/$pid/exe" 2>/dev/null || true)"

    if [[ -z "$path" && -r "/proc/$pid/cmdline" ]]; then
        # /proc/<pid>/cmdline is NUL-separated; first token is argv[0].
        IFS= read -r -d '' path < "/proc/$pid/cmdline" || true
        path="${path%% *}"
    fi
    [[ -n "$path" ]] || path="$name"

    RSS_SUM_KB["$name"]=$(( ${RSS_SUM_KB["$name"]:-0} + rss_kb ))

    current_path="${PATH_BY_NAME["$name"]:-}"
    if [[ -z "$current_path" || "$current_path" == "$name" || ( "$current_path" != /* && "$path" == /* ) ]]; then
        PATH_BY_NAME["$name"]="$path"
    fi
done < <(LC_ALL=C ps -eo pid=,rss=)

{
    for name in "${!RSS_SUM_KB[@]}"; do
        printf "%s\034%s\034%s\n" \
            "${RSS_SUM_KB[$name]}" \
            "$name" \
            "${PATH_BY_NAME[$name]:-$name}"
    done
} | LC_ALL=C sort -t$'\034' -k1,1nr | awk -F'\034' -v total_kb="$TOTAL_KB" '
function fmt_kb(kb,    mb) {
    mb = kb / 1024
    if (mb >= 1024)
        return sprintf("%6.2f GB", mb / 1024)
    return sprintf("%6.0f MB", mb)
}

BEGIN {
    sep = "────────────────────────────────────────────────────────────────────────"
    printf "%5s   %8s   %-22s   %s\n", "RAM%", "Amount", "Process", "Path"
    print sep
}
{
    rss_kb = $1 + 0
    name   = $2
    path   = $3
    pct    = rss_kb / total_kb * 100
    if (pct < 0.05)
        next

    printf "%5.1f%%  %s  %-22.22s   %s\n", pct, fmt_kb(rss_kb), name, path
}
END {
    print sep
}'

# Print system-wide RAM summary using values already read above
awk -v total_kb="$TOTAL_KB" -v avail_kb="$AVAIL_KB" 'BEGIN {
    used_kb = total_kb - avail_kb
    printf "System RAM: %.1f GB total  |  %.1f GB used  |  %.1f GB free\n\n",
        total_kb/1024/1024, used_kb/1024/1024, avail_kb/1024/1024
}'
