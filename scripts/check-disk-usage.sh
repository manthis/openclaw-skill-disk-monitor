#!/bin/bash
# check-disk-usage.sh - Monitor disk space usage with tiered alerts
# Part of openclaw-skill-disk-monitor
#
# Performance: Single jq invocation at the end instead of per-volume.

set -euo pipefail

# Thresholds
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90
EMERGENCY_THRESHOLD=95

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Collect all volume data as newline-delimited JSON (one object per line)
VOLUMES_NDJSON=""

while IFS= read -r line; do
    filesystem=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    used=$(echo "$line" | awk '{print $3}')
    avail=$(echo "$line" | awk '{print $4}')
    use_pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
    mount=$(echo "$line" | awk '{print $9}')

    [ -z "$mount" ] && continue
    [ "$mount" = "Mounted" ] && continue

    case "$mount" in
        /dev|/dev/*|/private/var/vm|/private/var/vm/*) continue ;;
    esac
    case "$filesystem" in
        devfs|tmpfs|map*) continue ;;
    esac
    [[ "$use_pct" =~ ^[0-9]+$ ]] || continue

    # Determine alert level inline
    if [ "$use_pct" -ge "$EMERGENCY_THRESHOLD" ]; then
        level="emergency"
    elif [ "$use_pct" -ge "$CRITICAL_THRESHOLD" ]; then
        level="critical"
    elif [ "$use_pct" -ge "$WARNING_THRESHOLD" ]; then
        level="warning"
    else
        level="ok"
    fi

    # Convert sizes to GB using awk (no bc dependency, no subshell per call)
    # Extract numeric value and unit suffix
    size_val=$(echo "$size" | sed 's/[^0-9.]//g')
    size_unit=$(echo "$size" | sed 's/[0-9.]//g')
    used_val=$(echo "$used" | sed 's/[^0-9.]//g')
    used_unit=$(echo "$used" | sed 's/[0-9.]//g')
    avail_val=$(echo "$avail" | sed 's/[^0-9.]//g')
    avail_unit=$(echo "$avail" | sed 's/[0-9.]//g')

    # Use awk for all conversions at once (1 process instead of 6× bc)
    read -r total_gb used_gb avail_gb <<< $(awk -v sv="$size_val" -v su="${size_unit:-K}" \
        -v uv="$used_val" -v uu="${used_unit:-K}" \
        -v av="$avail_val" -v au="${avail_unit:-K}" '
    function to_gb(val, unit) {
        if (unit ~ /^T/) return val * 1024
        if (unit ~ /^G/) return val
        if (unit ~ /^M/) return val / 1024
        if (unit ~ /^K/) return val / 1024 / 1024
        return 0
    }
    BEGIN { printf "%.2f %.2f %.2f\n", to_gb(sv,su), to_gb(uv,uu), to_gb(av,au) }')

    # Accumulate as NDJSON (no jq needed per iteration)
    VOLUMES_NDJSON+=$(printf '{"mount":"%s","total_gb":%s,"used_gb":%s,"avail_gb":%s,"use_pct":%s,"level":"%s"}\n' \
        "$mount" "$total_gb" "$used_gb" "$avail_gb" "$use_pct" "$level")

done < <(df -H | tail -n +2)

# Single jq call to build final output
echo "$VOLUMES_NDJSON" | jq -s --arg ts "$TIMESTAMP" '{
    timestamp: $ts,
    volumes: .,
    alerts: [.[] | select(.level != "ok") | {
        mount: .mount,
        level: .level,
        use_pct: .use_pct,
        message: "Only \(.avail_gb)GB remaining"
    }]
}'
