#!/bin/bash
# check-deployment-journal.sh - Monitor b4b deployment journal for new entries
# Run periodically to check for new devops tasks

set -e

JOURNAL_PATH="/Users/trunghuynh/development/b4b-api/docs/journals/deployment-azure-production.md"
CACHE_DIR="/Users/trunghuynh/development/finizi-dev/devops/.cache"
CACHE_FILE="$CACHE_DIR/journal-last-check.md5"
REPORTS_DIR="/Users/trunghuynh/development/finizi-dev/devops/plans/reports"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$CACHE_DIR"

echo -e "${BLUE}=== B4B Deployment Journal Monitor ===${NC}"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if journal exists
if [ ! -f "$JOURNAL_PATH" ]; then
    echo -e "${RED}Error: Journal not found at $JOURNAL_PATH${NC}"
    exit 1
fi

# Calculate current MD5
CURRENT_MD5=$(md5 -q "$JOURNAL_PATH" 2>/dev/null || md5sum "$JOURNAL_PATH" | cut -d' ' -f1)

# Check for changes
if [ -f "$CACHE_FILE" ]; then
    LAST_MD5=$(cat "$CACHE_FILE")
    if [ "$CURRENT_MD5" = "$LAST_MD5" ]; then
        echo -e "${GREEN}No changes detected since last check.${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Changes detected! Analyzing...${NC}"
fi

# Save current MD5
echo "$CURRENT_MD5" > "$CACHE_FILE"

# Extract latest entry
LATEST_ENTRY=$(grep -E "^## Entry" "$JOURNAL_PATH" | tail -1)
LATEST_DATE=$(grep -E "^\*\*Date\*\*:" "$JOURNAL_PATH" | tail -1 | cut -d':' -f2- | xargs)

echo -e "${BLUE}Latest Entry:${NC} $LATEST_ENTRY"
echo -e "${BLUE}Date:${NC} $LATEST_DATE"
echo ""

# Extract "Next Steps" and "Blockers" from latest entry
echo -e "${YELLOW}=== Pending Tasks ===${NC}"

# Find the line number of the latest entry
ENTRY_LINE=$(grep -n "^## Entry" "$JOURNAL_PATH" | tail -1 | cut -d':' -f1)

# Extract content until next entry or end of file
NEXT_ENTRY_LINE=$(grep -n "^## Entry" "$JOURNAL_PATH" | tail -2 | head -1 | cut -d':' -f1)
if [ -z "$NEXT_ENTRY_LINE" ]; then
    NEXT_ENTRY_LINE=$(wc -l < "$JOURNAL_PATH")
fi

# Get content between entries
ENTRY_CONTENT=$(sed -n "${ENTRY_LINE},${NEXT_ENTRY_LINE}p" "$JOURNAL_PATH")

# Extract Next Steps
if echo "$ENTRY_CONTENT" | grep -q "### Next Steps"; then
    echo -e "\n${GREEN}Next Steps:${NC}"
    echo "$ENTRY_CONTENT" | sed -n '/### Next Steps/,/###/p' | grep -E "^\d+\." | while read line; do
        echo "  $line"
    done
fi

# Extract Blockers
if echo "$ENTRY_CONTENT" | grep -q "### Blockers"; then
    echo -e "\n${RED}Blockers:${NC}"
    echo "$ENTRY_CONTENT" | sed -n '/### Blockers/,/---/p' | grep -v "### Blockers" | grep -v "^---" | while read line; do
        [ -n "$line" ] && echo "  $line"
    done
fi

# Extract Remaining Tasks
if echo "$ENTRY_CONTENT" | grep -q "### Remaining Tasks"; then
    echo -e "\n${YELLOW}Remaining Tasks:${NC}"
    echo "$ENTRY_CONTENT" | sed -n '/### Remaining Tasks/,/---/p' | grep -E "^\d+\." | while read line; do
        echo "  $line"
    done
fi

# Check for unchecked checkboxes
UNCHECKED=$(echo "$ENTRY_CONTENT" | grep -E "^\s*- \[ \]" | wc -l | tr -d ' ')
if [ "$UNCHECKED" -gt 0 ]; then
    echo -e "\n${YELLOW}Unchecked Items: $UNCHECKED${NC}"
    echo "$ENTRY_CONTENT" | grep -E "^\s*- \[ \]" | while read line; do
        echo "  $line"
    done
fi

echo ""
echo -e "${BLUE}=== End Report ===${NC}"
echo "Journal path: $JOURNAL_PATH"
echo "Run 'open $JOURNAL_PATH' to view full journal"
