# OpenClaw Disk Monitor Skill

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)

A proactive disk space monitoring skill for [OpenClaw](https://github.com/openclaw/openclaw) with tiered alerts and Telegram integration.

## Features

- 📊 **Multi-volume monitoring** - Track all mounted volumes automatically
- 🚨 **Tiered alerts** - Warning (80%), Critical (90%), Emergency (95%)
- 📱 **Telegram-friendly** - Formatted messages ready for chat delivery
- 🎯 **Smart filtering** - Ignores system/temp volumes
- 📦 **JSON output** - Structured data for easy integration
- 🔄 **Heartbeat integration** - Designed for OpenClaw's periodic checks

## Quick Start

```bash
# Clone into OpenClaw workspace
git clone https://github.com/manthis/openclaw-skill-disk-monitor.git ~/.openclaw/workspace/skills/disk-monitor

# Install scripts
cp ~/.openclaw/workspace/skills/disk-monitor/scripts/*.sh ~/bin/
chmod +x ~/bin/check-disk-usage.sh ~/bin/format-disk-alert.sh

# Test it
~/bin/check-disk-usage.sh | ~/bin/format-disk-alert.sh
```

## Requirements

- **bash** 4.0+
- **jq** - JSON processor
- **bc** - Calculator (usually pre-installed)

Install jq:
```bash
brew install jq  # macOS
apt-get install jq  # Debian/Ubuntu
```

## Usage

### Standalone

**Check disk usage (JSON output):**
```bash
~/bin/check-disk-usage.sh
```

**Format alerts for Telegram:**
```bash
~/bin/check-disk-usage.sh | ~/bin/format-disk-alert.sh
```

### OpenClaw Integration

Add to your `HEARTBEAT.md`:

```markdown
## Disk Monitoring

**Frequency:** 2x per day

**Action:**
1. Run `~/bin/check-disk-usage.sh`
2. Parse JSON for alerts
3. If alerts exist → format and send via Telegram
4. If no alerts → silent
```

**Example agent code:**

```bash
DISK_JSON=$(~/bin/check-disk-usage.sh)
ALERT_COUNT=$(echo "$DISK_JSON" | jq '.alerts | length')

if [ "$ALERT_COUNT" -gt 0 ]; then
    MESSAGE=$(echo "$DISK_JSON" | ~/bin/format-disk-alert.sh)
    # Send MESSAGE via telegram
fi
```

## Alert Examples

**Warning (80%+):**
```
⚠️ Disk Warning: / at 82%
Space: 410GB / 500GB
Available: 90GB remaining
```

**Critical (90%+):**
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

**Emergency (95%+):**
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

## Configuration

Edit `check-disk-usage.sh` to customize thresholds:

```bash
WARNING_THRESHOLD=80    # Default: 80%
CRITICAL_THRESHOLD=90   # Default: 90%
EMERGENCY_THRESHOLD=95  # Default: 95%
```

## JSON Output Format

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

## Excluded Volumes

The following are automatically excluded from monitoring:

- `/dev` and subpaths
- `/private/var/vm` (macOS swap)
- `tmpfs`, `devfs`, `map*` filesystems

## Testing

**Test with current system:**
```bash
~/bin/check-disk-usage.sh | jq .
```

**Test alert formatting:**
```bash
cat ~/.openclaw/workspace/skills/disk-monitor/examples/sample-output.json | ~/bin/format-disk-alert.sh
```

## Documentation

See [SKILL.md](SKILL.md) for complete documentation including:
- Detailed configuration options
- HEARTBEAT integration guide
- Troubleshooting
- Security considerations

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT License - see LICENSE file for details

## Author

Created for OpenClaw by [Maxime Auburtin](https://github.com/manthis)

## Related

- [OpenClaw](https://github.com/openclaw/openclaw) - AI agent framework
- [OpenClaw Skills](https://github.com/topics/openclaw-skill) - Browse all skills

---

**Like this skill?** ⭐ Star the repo and share it!
