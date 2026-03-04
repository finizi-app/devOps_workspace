# DevOps Scripts

Utility scripts for monitoring and automation.

## check-deployment-journal.sh

Monitors the b4b deployment journal for changes and reports pending tasks.

### Usage

```bash
# Check for changes (run periodically)
./scripts/check-deployment-journal.sh

# First run creates cache, subsequent runs detect changes
```

### Output
- Latest entry info
- Pending Next Steps
- Active Blockers
- Remaining Tasks
- Unchecked items

### Automation

Add to crontab for periodic checks:

```bash
# Every 30 minutes
*/30 * * * * /Users/trunghuynh/development/finizi-dev/devops/scripts/check-deployment-journal.sh >> /tmp/devops-journal.log 2>&1

# Every hour
0 * * * * /Users/trunghuynh/development/finizi-dev/devops/scripts/check-deployment-journal.sh >> /tmp/devops-journal.log 2>&1
```

### Cache
- Location: `.cache/journal-last-check.md5`
- Tracks last known state to detect changes

## Directory Structure

```
scripts/
├── check-deployment-journal.sh  # Monitor b4b deployment journal
└── README.md                    # This file
```
