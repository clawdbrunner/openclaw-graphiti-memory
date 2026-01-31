#!/bin/bash
# graphiti-search.sh - Search Graphiti knowledge graph for facts
# Usage: graphiti-search.sh <query> [group_id] [max_facts]

GRAPHITI_URL="${GRAPHITI_URL:-http://localhost:8001}"

QUERY="${1}"
GROUP_ID="${2:-clawdbot-main}"
MAX_FACTS="${3:-10}"

if [ -z "$QUERY" ]; then
    echo "Usage: graphiti-search.sh <query> [group_id] [max_facts]"
    exit 1
fi

# Escape JSON special characters
QUERY_ESCAPED=$(echo "$QUERY" | jq -Rs '.')

RESULT=$(curl -sf -X POST "${GRAPHITI_URL}/search" \
    -H 'Content-Type: application/json' \
    -d "{
        \"group_id\": \"${GROUP_ID}\",
        \"query\": ${QUERY_ESCAPED},
        \"max_facts\": ${MAX_FACTS}
    }" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$RESULT" | jq -r '.facts[] | "• \(.fact) (as of \(.valid_at | split("T")[0]))"' 2>/dev/null
    if [ "$(echo "$RESULT" | jq '.facts | length')" = "0" ]; then
        echo "(no facts found)"
    fi
else
    echo "✗ Failed to search Graphiti"
    exit 1
fi
