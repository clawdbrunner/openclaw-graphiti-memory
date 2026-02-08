#!/usr/bin/env bash
# Shared Graphiti search for all agents
# Usage: graphiti-search.sh "query" [group_id] [max_facts]
# Omit group_id to search across ALL agents (shared memory)
set -euo pipefail

GRAPHITI_URL="${GRAPHITI_URL:-http://localhost:8001}"
QUERY="${1:?Usage: graphiti-search.sh \"query\" [group_id] [max_facts]}"
GROUP_ID="${2:-}"
MAX_FACTS="${3:-10}"

if [ -n "$GROUP_ID" ]; then
  PAYLOAD=$(jq -n --arg q "$QUERY" --arg g "$GROUP_ID" --argjson m "$MAX_FACTS" \
    '{query: $q, group_id: $g, max_facts: $m}')
else
  PAYLOAD=$(jq -n --arg q "$QUERY" --argjson m "$MAX_FACTS" \
    '{query: $q, max_facts: $m}')
fi

RESPONSE=$(curl -s -X POST "${GRAPHITI_URL}/search" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD")

# Pretty-print facts
echo "$RESPONSE" | jq -r '.facts[]? | "• \(.fact) (as of \(.valid_at // "unknown"))"' 2>/dev/null

# If no facts found
FACT_COUNT=$(echo "$RESPONSE" | jq '.facts | length' 2>/dev/null || echo "0")
if [ "$FACT_COUNT" = "0" ]; then
  echo "No facts found for query: $QUERY"
fi
