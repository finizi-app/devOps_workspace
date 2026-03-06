#!/bin/bash
# Azure VM Disk Space Diagnostic Script
# Run on the Azure VM to investigate disk space issues
# Usage: ./scripts/azure-vm-disk-diagnostic.sh [--save-report]

set -e

SAVE_REPORT="${1:-}"
REPORT_FILE="/tmp/disk-diagnostic-$(date +%Y%m%d-%H%M%S).txt"

echo "=========================================="
echo "AZURE VM DISK DIAGNOSTIC REPORT"
echo "Generated: $(date)"
echo "=========================================="
echo

# 1. Overall disk usage
echo "=== 1. DISK USAGE OVERVIEW ==="
df -h
echo

# 2. Docker disk usage
echo "=== 2. DOCKER DISK USAGE ==="
if command -v docker &> /dev/null; then
    docker system df 2>/dev/null || echo "Docker not running or no permission"
    echo
    echo "--- Docker Images ---"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null | head -30
    echo
    echo "--- Docker Containers ---"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" 2>/dev/null
    echo
    echo "--- Docker Volumes ---"
    docker volume ls -q 2>/dev/null | wc -l | xargs -I{} echo "Total volumes: {}"
else
    echo "Docker not installed"
fi
echo

# 3. BuildKit cache (often huge)
echo "=== 3. BUILDKIT CACHE ==="
if [ -d "$HOME/.cache/docker/buildkit" ]; then
    du -sh "$HOME/.cache/docker/buildkit" 2>/dev/null
    find "$HOME/.cache/docker/buildkit" -type f 2>/dev/null | wc -l | xargs -I{} echo "Files: {}"
fi
if [ -d "/var/lib/docker/buildkit" ]; then
    sudo du -sh /var/lib/docker/buildkit 2>/dev/null
fi
echo

# 4. pnpm/Node.js caches
echo "=== 4. NODE.JS/PNPM CACHES ==="
for dir in "$HOME/.pnpm-store" "$HOME/.cache/pnpm" "$HOME/.npm" "/root/.pnpm-store" "/root/.cache/pnpm"; do
    if [ -d "$dir" ]; then
        du -sh "$dir" 2>/dev/null
    fi
done
echo

# 5. Largest directories (top-level)
echo "=== 5. LARGEST TOP-LEVEL DIRECTORIES ==="
du -sh /* 2>/dev/null | sort -hr | head -20
echo

# 6. /var breakdown
echo "=== 6. /var BREAKDOWN ==="
du -sh /var/* 2>/dev/null | sort -hr | head -15
echo

# 7. Docker directory breakdown
echo "=== 7. DOCKER DIRECTORY (/var/lib/docker) ==="
if [ -d "/var/lib/docker" ]; then
    sudo du -sh /var/lib/docker/* 2>/dev/null | sort -hr | head -15
fi
echo

# 8. Logs
echo "=== 8. LOG FILES ==="
echo "--- Journal logs ---"
journalctl --disk-usage 2>/dev/null || echo "Cannot access journal"
echo
echo "--- Large log files ---"
find /var/log -type f -size +10M -exec ls -lh {} \; 2>/dev/null | head -20
echo

# 9. Temporary files
echo "=== 9. TEMPORARY FILES ==="
du -sh /tmp /var/tmp 2>/dev/null
echo

# 10. Package manager caches
echo "=== 10. PACKAGE MANAGER CACHES ==="
for dir in "/var/cache/apt" "/var/lib/apt/lists"; do
    if [ -d "$dir" ]; then
        du -sh "$dir" 2>/dev/null
    fi
done
echo

# 11. Dangling Docker resources
echo "=== 11. DANGling DOCKER RESOURCES ==="
if command -v docker &> /dev/null; then
    echo "--- Dangling images ---"
    docker images -f "dangling=true" -q 2>/dev/null | wc -l | xargs -I{} echo "Count: {}"
    echo
    echo "--- Stopped containers ---"
    docker ps -a -f "status=exited" -q 2>/dev/null | wc -l | xargs -I{} echo "Count: {}"
    echo
    echo "--- Unused volumes ---"
    docker volume ls -qf "dangling=true" 2>/dev/null | wc -l | xargs -I{} echo "Count: {}"
fi
echo

# Summary
echo "=========================================="
echo "DIAGNOSTIC COMPLETE"
echo "=========================================="

if [ "$SAVE_REPORT" = "--save-report" ]; then
    echo "Report saved to: $REPORT_FILE"
fi

# Recommendations
echo
echo "=== RECOMMENDATIONS ==="
echo "1. Run: docker system prune -af --volumes"
echo "2. Run: docker builder prune -af"
echo "3. Check: rm -rf ~/.cache/docker/buildkit/*"
echo "4. Run: sudo journalctl --vacuum-time=3d"
echo "5. Run: sudo rm -rf /var/cache/apt/archives/*.deb"
echo
echo "For full cleanup, run: ./scripts/azure-vm-disk-cleanup.sh"
