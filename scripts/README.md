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

## azure-vm-disk-diagnostic.sh

Investigates disk space issues on Azure VM. Shows detailed breakdown of disk usage.

### Usage

```bash
# Run on Azure VM
./scripts/azure-vm-disk-diagnostic.sh

# Save report to file
./scripts/azure-vm-disk-diagnostic.sh --save-report
```

### Output
- Disk usage overview
- Docker images, containers, volumes
- BuildKit cache size
- Node.js/pnpm caches
- Largest directories
- Log files
- Recommendations

## azure-vm-disk-cleanup.sh

Frees disk space on Azure VM by cleaning up Docker, caches, logs, and temp files.

### Usage

```bash
# Dry run (preview what will be deleted)
./scripts/azure-vm-disk-cleanup.sh --dry-run

# Execute cleanup
./scripts/azure-vm-disk-cleanup.sh
```

### What it cleans
- Docker: unused images, containers, volumes, build cache
- BuildKit cache
- Node.js/pnpm caches
- Journal logs (keeps 3 days)
- Old log files (*.gz, *.1, *.old)
- APT cache
- Temporary files

## Directory Structure

```
scripts/
├── azure-vm-disk-cleanup.sh     # Free disk space on Azure VM
├── azure-vm-disk-diagnostic.sh  # Investigate disk space issues
├── check-deployment-journal.sh  # Monitor b4b deployment journal
└── README.md                    # This file
```
