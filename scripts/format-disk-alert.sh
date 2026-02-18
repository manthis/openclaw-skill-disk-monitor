#!/bin/bash
# format-disk-alert.sh - Format disk usage alerts for Telegram
# Part of openclaw-skill-disk-monitor

set -euo pipefail

# Read JSON from stdin or file
if [ $# -eq 1 ]; then
    JSON_INPUT=$(cat "$1")
else
    JSON_INPUT=$(cat)
fi

# Check if there are any alerts
ALERT_COUNT=$(echo "$JSON_INPUT" | jq '.alerts | length')

if [ "$ALERT_COUNT" -eq 0 ]; then
    exit 0
fi

# Process each alert
echo "$JSON_INPUT" | jq -r '.alerts[] | @json' | while read -r alert; do
    # Extract all fields in single jq call
    read -r MOUNT LEVEL USE_PCT TOTAL_GB USED_GB AVAIL_GB <<< $(echo "$alert" | jq -r '[.mount, .level, (.use_pct|tostring)] | @tsv')
    VOLUME_DATA=$(echo "$JSON_INPUT" | jq --arg mount "$MOUNT" '.volumes[] | select(.mount == $mount) | [(.total_gb|floor), (.used_gb|floor), (.avail_gb|floor)] | @tsv')
    read -r TOTAL_GB USED_GB AVAIL_GB <<< "$VOLUME_DATA"
    
    # Format based on level
    case "$LEVEL" in
        emergency)
            echo "🔴 DISK EMERGENCY: $MOUNT at ${USE_PCT}%"
            echo "Space: ${USED_GB}GB / ${TOTAL_GB}GB"
            echo "Available: ${AVAIL_GB}GB remaining"
            echo ""
            echo "⚠️ URGENT: Free up space immediately!"
            echo ""
            echo "Quick cleanup:"
            echo "- ~/Downloads"
            echo "- Docker: docker system prune -a"
            echo "- Old logs: ~/.cache, /var/log"
            echo "- Trash: ~/.Trash"
            ;;
        critical)
            echo "🚨 Disk Critical: $MOUNT at ${USE_PCT}%"
            echo "Space: ${USED_GB}GB / ${TOTAL_GB}GB"
            echo "Available: ${AVAIL_GB}GB remaining"
            echo ""
            echo "Consider cleaning:"
            echo "- ~/Downloads"
            echo "- Docker images/volumes"
            echo "- Old logs"
            echo "- ~/.Trash"
            ;;
        warning)
            echo "⚠️ Disk Warning: $MOUNT at ${USE_PCT}%"
            echo "Space: ${USED_GB}GB / ${TOTAL_GB}GB"
            echo "Available: ${AVAIL_GB}GB remaining"
            ;;
    esac
    echo ""
done
