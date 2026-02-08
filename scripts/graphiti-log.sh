#!/usr/bin/env bash
# Shared Graphiti logger for all agents
# Usage: graphiti-log.sh <agent_id> <role_type> <role> <content> [timestamp]
# Agents should ONLY log to their own group: clawdbot-<agent_id>
set -euo pipefail

GRAPHITI_URL="${GRAPHITI_URL:-http://localhost:8001}"
AGENT_ID="${1:?Usage: graphiti-log.sh <agent_id> <role_type> <role> <content> [timestamp]}"
ROLE_TYPE="${2:?Missing role_type (user|assistant|system)}"
ROLE="${3:?Missing role (speaker name)}"
CONTENT="${4:?Missing content}"
TIMESTAMP="${5:-$(date -u +%Y-%m-%dT%H:%M:%S+00:00)}"

GROUP_ID="clawdbot-${AGENT_ID}"

PAYLOAD=$(jq -n \
  --arg g "$GROUP_ID" \
  --arg rt "$ROLE_TYPE" \
  --arg r "$ROLE" \
  --arg c "$CONTENT" \
  --arg t "$TIMESTAMP" \
  '{
    group_id: $g,
    messages: [{
      role_type: $rt,
      role: $r,
      content: $c,
      timestamp: $t
    }]
  }')

curl -s -X POST "${GRAPHITI_URL}/messages" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" | jq -r '.result // .message // "Logged successfully"' 2>/dev/null || echo "Logged to ${GROUP_ID}"
