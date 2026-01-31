#!/bin/bash
# graphiti-log.sh - Log a message to Graphiti knowledge graph
# Usage: graphiti-log.sh <group_id> <role_type> <role> <content> [timestamp]

GRAPHITI_URL="${GRAPHITI_URL:-http://localhost:8001}"

GROUP_ID="${1:-clawdbot-main}"
ROLE_TYPE="${2:-user}"
ROLE="${3:-Unknown}"
CONTENT="${4}"
TIMESTAMP="${5:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

if [ -z "$CONTENT" ]; then
    echo "Usage: graphiti-log.sh <group_id> <role_type> <role> <content> [timestamp]"
    echo "  role_type: user, assistant, or system"
    exit 1
fi

# Escape JSON special characters
CONTENT_ESCAPED=$(echo "$CONTENT" | jq -Rs '.')

curl -sf -X POST "${GRAPHITI_URL}/messages" \
    -H 'Content-Type: application/json' \
    -d "{
        \"group_id\": \"${GROUP_ID}\",
        \"messages\": [
            {
                \"role_type\": \"${ROLE_TYPE}\",
                \"role\": \"${ROLE}\",
                \"content\": ${CONTENT_ESCAPED},
                \"timestamp\": \"${TIMESTAMP}\"
            }
        ]
    }" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ Logged to Graphiti (${GROUP_ID})"
else
    echo "✗ Failed to log to Graphiti"
    exit 1
fi
