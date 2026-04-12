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

## tail-production-logs.sh

Tails b4b production Docker logs in real-time via SSH.

### Usage

```bash
# Tail all logs
./scripts/tail-production-logs.sh

# Tail specific service
./scripts/tail-production-logs.sh app
./scripts/tail-production-logs.sh worker
./scripts/tail-production-logs.sh frontend

# Set past lines to show
./scripts/tail-production-logs.sh --lines 500
```

### Services
| Service | Description |
|---------|-------------|
| `app` | Backend API |
| `frontend` | Next.js frontend |
| `worker` | Celery background worker |
| `webhook` | Celery webhook handler |
| `beat` | Celery scheduler |
| `redis` | Redis cache |
| `all` | All services (default) |

## add-ssh-key-to-azure.sh

Adds your SSH public key to Azure VM for passwordless login.

### Prerequisites

```bash
# Install Azure CLI
brew install azure-cli

# Login to Azure
az login
```

### Usage

```bash
# Add to production VM
./scripts/add-ssh-key-to-azure.sh production

# Add to staging VM
./scripts/add-ssh-key-to-azure.sh staging

# Use custom public key
./scripts/add-ssh-key-to-azure.sh production ~/.ssh/my_key.pub
```

### What it does
- Reads your public SSH key
- Updates Azure VM user's authorized_keys via Azure CLI
- Enables passwordless SSH login

## Directory Structure

```
scripts/
├── add-ssh-key-to-azure.sh      # Add SSH key to Azure VM
├── azure-vm-disk-cleanup.sh     # Free disk space on Azure VM
├── azure-vm-disk-diagnostic.sh  # Investigate disk space issues
├── check-deployment-journal.sh  # Monitor b4b deployment journal
├── tail-production-logs.sh      # Tail b4b production Docker logs
└── README.md                    # This file
```
