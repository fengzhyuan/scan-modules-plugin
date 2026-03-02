#!/bin/bash
# scan-modules: SessionStart hook — check module cache freshness
# Output is injected into conversation as a system reminder

INDEX_FILE=".claude/modules/INDEX.md"

# Silent exit if no module cache
[ -f "$INDEX_FILE" ] || exit 0

# Extract SCAN_META
META_LINE=$(head -1 "$INDEX_FILE")
CACHED_HASH=$(echo "$META_LINE" | grep -o 'hash=[a-f0-9]*' | cut -d= -f2)
CACHED_DATE=$(echo "$META_LINE" | grep -o 'date=[0-9-]*' | cut -d= -f2)

# Get current HEAD
CURRENT_HASH=$(git rev-parse --short HEAD 2>/dev/null)

if [ -z "$CURRENT_HASH" ]; then
  exit 0
fi

# Determine freshness
if [ "$CACHED_HASH" = "$CURRENT_HASH" ]; then
  STATUS="fresh"
else
  STATUS="stale (run \`/scan-modules:scan-modules update\` to refresh)"
fi

cat <<EOF
[scan-modules] Module cache found at .claude/modules/INDEX.md
Cache status: ${STATUS} | Last scan: ${CACHED_DATE} | Hash: ${CACHED_HASH} | HEAD: ${CURRENT_HASH}
IMPORTANT: When exploring or searching the codebase, read .claude/modules/INDEX.md FIRST to locate relevant modules, then read .claude/modules/{module-name}.md for function signatures, BEFORE falling back to grep/glob.
EOF
