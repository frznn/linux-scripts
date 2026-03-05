#!/bin/bash
set -euo pipefail
#
# ps-cpu — List running processes ordered by CPU usage
#
# Shows each process's recent CPU usage (%), aggregated by process name.
# On multi-core systems values can exceed 100% (each core adds up to 100%).
#
# INSTALL AS A COMMAND
# --------------------
# Option A – symlink (script stays here, changes are instant):
#   sudo ln -s /home/frznn/dev/frznn/linux-scripts/utils/ps-cpu.sh /usr/local/bin/ps-cpu
#   sudo chmod +x /home/frznn/dev/frznn/linux-scripts/utils/ps-cpu.sh
#
# Then run with: ps-cpu

# Parse process CPU%, aggregate by process name, then print sorted output.
# ps reports pcpu with exactly one decimal (e.g. "1.5"); strip the decimal
# point to store as a scaled integer (cpu * 10) for bash integer arithmetic.
declare -A CPU_SUM_X10
declare -A PATH_BY_NAME

while read -r pid cpu; do
    [[ "$pid" =~ ^[0-9]+$ && "$cpu" =~ ^[0-9]+\.[0-9]$ ]] || continue

    cpu_int=$(( 10#${cpu/./} ))  # "1.5" → 15 (= cpu * 10); 10# forces base-10 to avoid octal errors on "0.8" → "08"
    (( cpu_int > 0 )) || continue

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

    CPU_SUM_X10["$name"]=$(( ${CPU_SUM_X10["$name"]:-0} + cpu_int ))

    current_path="${PATH_BY_NAME["$name"]:-}"
    if [[ -z "$current_path" || "$current_path" == "$name" || ( "$current_path" != /* && "$path" == /* ) ]]; then
        PATH_BY_NAME["$name"]="$path"
    fi
done < <(LC_ALL=C ps -eo pid=,pcpu=)

nproc_count=$(nproc)

{
    for name in "${!CPU_SUM_X10[@]}"; do
        printf "%s\034%s\034%s\n" \
            "${CPU_SUM_X10[$name]}" \
            "$name" \
            "${PATH_BY_NAME[$name]:-$name}"
    done
} | LC_ALL=C sort -t$'\034' -k1,1nr | awk -F'\034' -v nproc="$nproc_count" '
BEGIN {
    sep = "────────────────────────────────────────────────────────────────────────"
    printf "%7s  %5s   %-22s   %s\n", "CORE%", "SYS%", "Process", "Path"
    print sep
}
{
    cpu_x10  = $1 + 0
    name     = $2
    path     = $3
    core_pct = cpu_x10 / 10          # % of one core (can exceed 100% for multi-threaded)
    sys_pct  = core_pct / nproc      # % of total CPU capacity across all cores

    printf "%6.1f%%  %4.1f%%  %-22.22s   %s\n", core_pct, sys_pct, name, path
}
END {
    print sep
}'

# Print load average as a utilization % of total CPU capacity
read -r avg1 _ < /proc/loadavg
utilized=$(awk "BEGIN { printf \"%.0f\", $avg1 / $nproc_count * 100 }")
printf "\nSystem CPU (%d cores)  |  ~%d%% utilized\n" \
    "$nproc_count" "$utilized"
