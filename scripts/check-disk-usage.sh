#!/bin/bash
# check-disk-usage.sh - Monitor disk space usage with tiered alerts
# Part of openclaw-skill-disk-monitor

set -euo pipefail

# Thresholds
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90
EMERGENCY_THRESHOLD=95

# Get current timestamp in ISO 8601 format
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize JSON arrays
VOLUMES_JSON="[]"
ALERTS_JSON="[]"

# Function to convert size to GB
bytes_to_gb() {
    local size=$1
    local unit=$2
    case $unit in
        K*) echo "scale=2; $size / 1024 / 1024" | bc ;;
        M*) echo "scale=2; $size / 1024" | bc ;;
        G*) echo "scale=2; $size" | bc ;;
        T*) echo "scale=2; $size * 1024" | bc ;;
        *) echo "0" ;;
    esac
}

# Function to determine alert level
get_alert_level() {
    local pct=$1
    if [ "$pct" -ge "$EMERGENCY_THRESHOLD" ]; then
        echo "emergency"
    elif [ "$pct" -ge "$CRITICAL_THRESHOLD" ]; then
        echo "critical"
    elif [ "$pct" -ge "$WARNING_THRESHOLD" ]; then
        echo "warning"
    else
        echo "ok"
    fi
}

# Parse df output and build JSON
while IFS= read -r line; do
    # Extract fields from df output
    filesystem=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    used=$(echo "$line" | awk '{print $3}')
    avail=$(echo "$line" | awk '{print $4}')
    use_pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
    mount=$(echo "$line" | awk '{print $9}')
    
    # Skip header, empty lines, and excluded mounts
    [ -z "$mount" ] && continue
    [ "$mount" = "Mounted" ] && continue
    
    # Skip system/temp volumes
    case "$mount" in
        /dev|/dev/*|/private/var/vm|/private/var/vm/*) continue ;;
    esac
    
    case "$filesystem" in
        devfs|tmpfs|map*) continue ;;
    esac
    
    # Skip if use_pct is not a number
    if ! [[ "$use_pct" =~ ^[0-9]+$ ]]; then
        continue
    fi
    
    # Extract size unit (last char) and value
    size_val=$(echo "$size" | sed 's/[^0-9.]//g')
    size_unit=$(echo "$size" | sed 's/[0-9.]//g')
    [ -z "$size_unit" ] && size_unit="K"
    
    used_val=$(echo "$used" | sed 's/[^0-9.]//g')
    used_unit=$(echo "$used" | sed 's/[0-9.]//g')
    [ -z "$used_unit" ] && used_unit="K"
    
    avail_val=$(echo "$avail" | sed 's/[^0-9.]//g')
    avail_unit=$(echo "$avail" | sed 's/[0-9.]//g')
    [ -z "$avail_unit" ] && avail_unit="K"
    
    # Convert to GB
    total_gb=$(bytes_to_gb "$size_val" "$size_unit")
    used_gb=$(bytes_to_gb "$used_val" "$used_unit")
    avail_gb=$(bytes_to_gb "$avail_val" "$avail_unit")
    
    # Determine alert level
    level=$(get_alert_level "$use_pct")
    
    # Build volume JSON object
    volume_obj=$(jq -n \
        --arg mount "$mount" \
        --arg total "$total_gb" \
        --arg used "$used_gb" \
        --arg avail "$avail_gb" \
        --arg pct "$use_pct" \
        --arg level "$level" \
        '{
            mount: $mount,
            total_gb: ($total | tonumber),
            used_gb: ($used | tonumber),
            avail_gb: ($avail | tonumber),
            use_pct: ($pct | tonumber),
            level: $level
        }')
    
    VOLUMES_JSON=$(echo "$VOLUMES_JSON" | jq --argjson vol "$volume_obj" '. += [$vol]')
    
    # Add alert if needed
    if [ "$level" != "ok" ]; then
        message="Only ${avail_gb}GB remaining"
        alert_obj=$(jq -n \
            --arg mount "$mount" \
            --arg level "$level" \
            --arg pct "$use_pct" \
            --arg msg "$message" \
            '{
                mount: $mount,
                level: $level,
                use_pct: ($pct | tonumber),
                message: $msg
            }')
        
        ALERTS_JSON=$(echo "$ALERTS_JSON" | jq --argjson alert "$alert_obj" '. += [$alert]')
    fi
    
done < <(df -H | tail -n +2)

# Build final JSON output
jq -n \
    --arg ts "$TIMESTAMP" \
    --argjson vols "$VOLUMES_JSON" \
    --argjson alerts "$ALERTS_JSON" \
    '{
        timestamp: $ts,
        volumes: $vols,
        alerts: $alerts
    }'
