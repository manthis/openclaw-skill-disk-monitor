# Disk Monitor Skill

**Purpose:** Monitor disk space usage with tiered alerts for proactive disk management.

## Overview

This skill monitors all mounted volumes and generates alerts when disk space usage reaches configurable thresholds. It's designed to integrate with OpenClaw's heartbeat system for periodic monitoring.

## Features

- **Main disk monitoring** - Tracks only the main system disk (default: `/System/Volumes/Data`)
- **Tiered alerts** - Warning (80%), Critical (90%), Emergency (95%)
- **JSON output** - Structured data for easy parsing
- **Telegram-friendly formatting** - Human-readable alert messages
- **Smart filtering** - Automatically excludes iOS simulator volumes, system temps, and small volumes

## Requirements

- **bash** (4.0+)
- **df** - Disk space reporting (standard on macOS/Linux)
- **jq** - JSON processing
- **bc** - Floating point calculations

Install jq if needed:
```bash
# macOS
brew install jq

# Debian/Ubuntu
apt-get install jq

# RHEL/CentOS
yum install jq
```

## Installation

### Quick Install (Recommended)

```bash
# Clone the skill
git clone https://github.com/manthis/openclaw-skill-disk-monitor.git ~/.openclaw/workspace/skills/disk-monitor

# Copy scripts to ~/bin
cp ~/.openclaw/workspace/skills/disk-monitor/scripts/*.sh ~/bin/
chmod +x ~/bin/check-disk-usage.sh ~/bin/format-disk-alert.sh
```

### Manual Install

1. Copy `scripts/check-disk-usage.sh` to `~/bin/`
2. Copy `scripts/format-disk-alert.sh` to `~/bin/`
3. Make both executable: `chmod +x ~/bin/*.sh`

## Configuration

### Alert Thresholds

Edit `check-disk-usage.sh` to customize thresholds:

```bash
# Default thresholds (%)
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90
EMERGENCY_THRESHOLD=95
```

### Monitored Volumes

**Default behavior:** The script monitors **only the main system disk** (`/System/Volumes/Data` on macOS).

**Automatically excluded:**
- iOS simulator volumes (`/Library/Developer/CoreSimulator/*`)
- System/temp volumes (`/dev`, `/private/var/vm`, tmpfs, devfs)
- Autofs mounts (`map*`)
- Small system volumes (`/System/Volumes/Preboot`, `/System/Volumes/VM`, etc.)

**To monitor additional volumes:**

Edit the script's mount filter:

```bash
# Change this line to include other volumes:
if [ "$mount" != "/System/Volumes/Data" ]; then
    continue
fi

# Example - monitor multiple volumes:
if [[ "$mount" != "/System/Volumes/Data" && "$mount" != "/Volumes/External" ]]; then
    continue
fi
```

**To monitor ALL volumes (legacy behavior):**

Comment out the main disk filter:

```bash
# Only monitor main system disk (exclude small system volumes)
# Main disk is typically /System/Volumes/Data with size >= 200GB
# if [ "$mount" != "/System/Volumes/Data" ]; then
#     continue
# fi
```

## Usage

### Standalone Usage

**Check disk usage:**
```bash
~/bin/check-disk-usage.sh
```

**Output:** JSON with volume stats and alerts

**Format alerts:**
```bash
~/bin/check-disk-usage.sh | ~/bin/format-disk-alert.sh
```

**Output:** Human-readable Telegram messages (only if alerts exist)

### Integration with OpenClaw HEARTBEAT

Add to `HEARTBEAT.md`:

```markdown
## Disk Monitoring (every heartbeat)

**Frequency:** 2x per day (morning & evening)

**Action:**
1. Run `~/bin/check-disk-usage.sh`
2. Parse JSON output
3. If alerts exist:
   - Format with `~/bin/format-disk-alert.sh`
   - Send via Telegram
4. If no alerts: silent (HEARTBEAT_OK)

**State tracking:** Store last check timestamp in `memory/heartbeat-state.json`:
```json
{
  "lastChecks": {
    "disk": 1703275200
  }
}
```

**Example integration code:**

```bash
DISK_JSON=$(~/bin/check-disk-usage.sh)
ALERT_COUNT=$(echo "$DISK_JSON" | jq '.alerts | length')

if [ "$ALERT_COUNT" -gt 0 ]; then
    MESSAGE=$(echo "$DISK_JSON" | ~/bin/format-disk-alert.sh)
    # Send $MESSAGE via Telegram
fi
```

## Output Format

### JSON Structure

```json
{
  "timestamp": "2026-02-18T20:10:00Z",
  "volumes": [
    {
      "mount": "/",
      "total_gb": 500,
      "used_gb": 450,
      "avail_gb": 50,
      "use_pct": 90,
      "level": "critical"
    }
  ],
  "alerts": [
    {
      "mount": "/",
      "level": "critical",
      "use_pct": 90,
      "message": "Only 50GB remaining"
    }
  ]
}
```

### Alert Levels

| Level | Threshold | Icon | Action |
|-------|-----------|------|--------|
| `ok` | < 80% | - | No alert |
| `warning` | 80-89% | ⚠️ | Alert only |
| `critical` | 90-94% | 🚨 | Alert + cleanup suggestions |
| `emergency` | ≥ 95% | 🔴 | Urgent alert + immediate action needed |

### Formatted Alert Examples

**Warning (80%):**
```
⚠️ Disk Warning: / at 82%
Space: 410GB / 500GB
Available: 90GB remaining
```

**Critical (90%):**
```
🚨 Disk Critical: / at 92%
Space: 460GB / 500GB
Available: 40GB remaining

Consider cleaning:
- ~/Downloads
- Docker images/volumes
- Old logs
- ~/.Trash
```

**Emergency (95%):**
```
🔴 DISK EMERGENCY: / at 98%
Space: 490GB / 500GB
Available: 10GB remaining

⚠️ URGENT: Free up space immediately!

Quick cleanup:
- ~/Downloads
- Docker: docker system prune -a
- Old logs: ~/.cache, /var/log
- Trash: ~/.Trash
```

## Testing

**Test with current system:**
```bash
~/bin/check-disk-usage.sh | jq .
```

**Test alert formatting:**
```bash
~/bin/check-disk-usage.sh | ~/bin/format-disk-alert.sh
```

**Test with sample data:**
```bash
cat examples/sample-output.json | ~/bin/format-disk-alert.sh
```

## Troubleshooting

**Issue:** Script fails with `jq: command not found`
**Solution:** Install jq (`brew install jq` on macOS)

**Issue:** Script fails with `bc: command not found`
**Solution:** Install bc (`brew install bc` on macOS, usually pre-installed on Linux)

**Issue:** No volumes detected
**Solution:** Check that `df -H` works and returns data

**Issue:** Wrong volume sizes
**Solution:** Script uses `df -H` (SI units, base 1000). For binary units (1024), use `df -h` and adjust parsing.

## Security Considerations

- No hardcoded paths with personal data
- No secrets or credentials
- Read-only operations (safe to run frequently)
- Excludes sensitive system volumes automatically

## License

MIT License - See repository for full license text.

## Contributing

Contributions welcome! Please submit PRs to the GitHub repository.

## Author

Created for OpenClaw by Maxime Auburtin
