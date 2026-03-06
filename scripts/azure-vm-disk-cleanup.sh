#!/bin/bash
# Azure VM Disk Space Cleanup Script
# Run on the Azure VM to free disk space
# Usage: ./scripts/azure-vm-disk-cleanup.sh [--dry-run]

set -e

DRY_RUN="${1:-}"
if [ "$DRY_RUN" = "--dry-run" ]; then
    echo "=== DRY RUN MODE - No changes will be made ==="
    echo
fi

run_cmd() {
    if [ "$DRY_RUN" = "--dry-run" ]; then
        echo "[DRY-RUN] Would run: $*"
    else
        echo "Running: $*"
        "$@"
    fi
}

echo "=========================================="
echo "AZURE VM DISK CLEANUP"
echo "Started: $(date)"
echo "=========================================="
echo

# Show before state
echo "=== DISK USAGE BEFORE ==="
df -h / 2>/dev/null | grep -v "Filesystem"
echo

# 1. Docker cleanup (most impactful)
echo "=== 1. DOCKER CLEANUP ==="
if command -v docker &> /dev/null; then
    echo "Removing unused containers..."
    run_cmd docker container prune -f

    echo "Removing unused images..."
    run_cmd docker image prune -af

    echo "Removing unused volumes..."
    run_cmd docker volume prune -f

    echo "Removing unused networks..."
    run_cmd docker network prune -f

    echo "Removing build cache..."
    run_cmd docker builder prune -af

    echo "Full system prune..."
    run_cmd docker system prune -af --volumes
else
    echo "Docker not installed, skipping"
fi
echo

# 2. BuildKit cache
echo "=== 2. BUILDKIT CACHE ==="
for dir in "$HOME/.cache/docker/buildkit" "/root/.cache/docker/buildkit"; do
    if [ -d "$dir" ]; then
        echo "Cleaning: $dir"
        run_cmd rm -rf "$dir"/*
    fi
done
echo

# 3. Node.js/pnpm caches
echo "=== 3. NODE.JS/PNPM CACHES ==="
for dir in "$HOME/.pnpm-store" "$HOME/.cache/pnpm" "/root/.pnpm-store" "/root/.cache/pnpm"; do
    if [ -d "$dir" ]; then
        echo "Cleaning: $dir"
        run_cmd rm -rf "$dir"
    fi
done
echo

# 4. npm cache
echo "=== 4. NPM CACHE ==="
if command -v npm &> /dev/null; then
    run_cmd npm cache clean --force
fi
echo

# 5. Journal logs
echo "=== 5. JOURNAL LOGS ==="
if command -v journalctl &> /dev/null; then
    run_cmd sudo journalctl --vacuum-time=3d
fi
echo

# 6. Old log files
echo "=== 6. OLD LOG FILES ==="
run_cmd sudo find /var/log -type f -name "*.gz" -delete
run_cmd sudo find /var/log -type f -name "*.1" -delete
run_cmd sudo find /var/log -type f -name "*.old" -delete
echo

# 7. APT cache (Debian/Ubuntu)
echo "=== 7. APT CACHE ==="
if command -v apt-get &> /dev/null; then
    run_cmd sudo apt-get clean
    run_cmd sudo rm -rf /var/cache/apt/archives/*.deb
    run_cmd sudo rm -rf /var/lib/apt/lists/*
fi
echo

# 8. Temporary files
echo "=== 8. TEMPORARY FILES ==="
run_cmd sudo rm -rf /tmp/*
run_cmd sudo rm -rf /var/tmp/*
echo

# 9. Core dumps
echo "=== 9. CORE DUMPS ==="
run_cmd sudo find /var/crash -type f -delete 2>/dev/null || true
run_cmd sudo find / -name "core.*" -type f -delete 2>/dev/null || true
echo

# Show after state
echo "=========================================="
echo "DISK USAGE AFTER"
echo "=========================================="
df -h / 2>/dev/null | grep -v "Filesystem"
echo

echo "=== CLEANUP COMPLETE ==="
echo "Finished: $(date)"

if [ "$DRY_RUN" = "--dry-run" ]; then
    echo
    echo "This was a DRY RUN. Run without --dry-run to apply changes."
fi
