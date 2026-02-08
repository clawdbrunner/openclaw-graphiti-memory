#!/usr/bin/env bash
# Get relevant shared memory context for a task
# Usage: graphiti-context.sh "task description" [agent_id]
# Searches cross-group + agent's own group for comprehensive context
set -euo pipefail

GRAPHITI_URL="${GRAPHITI_URL:-http://localhost:8001}"
TASK="${1:?Usage: graphiti-context.sh \"task description\" [agent_id]}"
AGENT_ID="${2:-}"

echo "=== Shared Memory Context ==="
echo ""

# 1. Cross-group search (all agents' knowledge)
echo "--- Cross-Agent Knowledge ---"
PAYLOAD=$(jq -n --arg q "$TASK" '{query: $q, max_facts: 10}')
curl -s -X POST "${GRAPHITI_URL}/search" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" | jq -r '.facts[]? | "• \(.fact)"' 2>/dev/null

echo ""

# 2. User context (Chris's profile/preferences)
echo "--- User Context ---"
PAYLOAD=$(jq -n --arg q "$TASK" --arg g "user-chris" '{query: $q, group_id: $g, max_facts: 5}')
curl -s -X POST "${GRAPHITI_URL}/search" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" | jq -r '.facts[]? | "• \(.fact)"' 2>/dev/null

echo ""

# 3. System shared context
echo "--- System Context ---"
PAYLOAD=$(jq -n --arg q "$TASK" --arg g "system-shared" '{query: $q, group_id: $g, max_facts: 5}')
curl -s -X POST "${GRAPHITI_URL}/search" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" | jq -r '.facts[]? | "• \(.fact)"' 2>/dev/null

# 4. Agent's own memory (if agent_id provided)
if [ -n "$AGENT_ID" ]; then
  echo ""
  echo "--- My Memory (${AGENT_ID}) ---"
  PAYLOAD=$(jq -n --arg q "$TASK" --arg g "clawdbot-${AGENT_ID}" '{query: $q, group_id: $g, max_facts: 5}')
  curl -s -X POST "${GRAPHITI_URL}/search" \
    -H 'Content-Type: application/json' \
    -d "$PAYLOAD" | jq -r '.facts[]? | "• \(.fact)"' 2>/dev/null
fi
