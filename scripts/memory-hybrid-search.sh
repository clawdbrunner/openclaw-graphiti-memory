#!/bin/bash
# memory-hybrid-search.sh - Search both QMD (files) AND Graphiti (temporal facts)
# Usage: memory-hybrid-search.sh <query> [group_id] [--json]

QUERY="${1}"
GROUP_ID="${2:-clawdbot-main}"
JSON_MODE=false
QMD_PATH="${QMD_PATH:-$HOME/.bun/bin/qmd}"

# Parse optional flags
for arg in "$@"; do
    if [ "$arg" = "--json" ]; then
        JSON_MODE=true
    fi
done

if [ -z "$QUERY" ]; then
    echo "Usage: memory-hybrid-search.sh <query> [group_id] [--json]" >&2
    exit 1
fi

# Determine script directory for graphiti-search.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run searches in parallel and capture output
GRAPHITI_OUT=$("$SCRIPT_DIR/graphiti-search.sh" "$QUERY" "$GROUP_ID" 5 2>/dev/null)
GRAPHITI_STATUS=$?

if [ -x "$QMD_PATH" ]; then
    QMD_OUT=$($QMD_PATH search "$QUERY" -n 5 --min-score 0.35 2>/dev/null)
    QMD_STATUS=$?
else
    QMD_OUT=""
    QMD_STATUS=1
fi

if [ "$JSON_MODE" = true ]; then
    # JSON output for programmatic use
    printf '%s\n' "{"
    printf '  "query": "%s",\n' "$QUERY"
    printf '  "group_id": "%s",\n' "$GROUP_ID"
    printf '  "graphiti": {\n'
    printf '    "status": "%s",\n' "$(if [ $GRAPHITI_STATUS -eq 0 ]; then echo "ok"; else echo "error"; fi)"
    printf '    "results": %s\n' "$(echo "$GRAPHITI_OUT" | grep -E '^\[' | head -5 | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')"
    printf '  },\n'
    printf '  "qmd": {\n'
    printf '    "status": "%s",\n' "$(if [ $QMD_STATUS -eq 0 ]; then echo "ok"; else echo "error"; fi)"
    printf '    "results": %s\n' "$(echo "$QMD_OUT" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')"
    printf '  }\n'
    printf '}\n'
else
    # Human-readable output
    echo "🔍 Hybrid Memory Search: '$QUERY'"
    echo "========================================"
    echo ""
    
    echo "🧠 Graphiti (Temporal Facts):"
    if [ -n "$GRAPHITI_OUT" ]; then
        echo "$GRAPHITI_OUT"
    else
        echo "  (no temporal facts found)"
    fi
    echo ""
    
    echo "📄 QMD (Document Search):"
    if [ -n "$QMD_OUT" ]; then
        echo "$QMD_OUT"
    else
        echo "  (no matching documents found)"
    fi
    echo ""
    echo "========================================"
fi
JSON_MODE=false
QMD_PATH="${QMD_PATH:-$HOME/.bun/bin/qmd}"

# Parse optional flags
for arg in "$@"; do
    if [ "$arg" = "--json" ]; then
        JSON_MODE=true
    fi
done

if [ -z "$QUERY" ]; then
    echo "Usage: memory-hybrid-search.sh <query> [group_id] [--json]" >&2
    exit 1
fi

# Determine script directory for graphiti-search.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run searches in parallel and capture output
GRAPHITI_OUT=$("$SCRIPT_DIR/graphiti-search.sh" "$QUERY" "$GROUP_ID" 5 2>/dev/null)
GRAPHITI_STATUS=$?

if [ -x "$QMD_PATH" ]; then
    QMD_OUT=$($QMD_PATH search "$QUERY" -n 5 --min-score 0.35 2>/dev/null)
    QMD_STATUS=$?
else
    QMD_OUT=""
    QMD_STATUS=1
fi

if [ "$JSON_MODE" = true ]; then
    # JSON output for programmatic use
    printf '%s\n' "{"
    printf '  "query": "%s",\n' "$QUERY"
    printf '  "group_id": "%s",\n' "$GROUP_ID"
    printf '  "graphiti": {\n'
    printf '    "status": "%s",\n' "$(if [ $GRAPHITI_STATUS -eq 0 ]; then echo "ok"; else echo "error"; fi)"
    printf '    "results": %s\n' "$(echo "$GRAPHITI_OUT" | grep -E '^\[' | head -5 | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')"
    printf '  },\n'
    printf '  "qmd": {\n'
    printf '    "status": "%s",\n' "$(if [ $QMD_STATUS -eq 0 ]; then echo "ok"; else echo "error"; fi)"
    printf '    "results": %s\n' "$(echo "$QMD_OUT" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')"
    printf '  }\n'
    printf '}\n'
else
    # Human-readable output
    echo "🔍 Hybrid Memory Search: '$QUERY'"
    echo "========================================"
    echo ""
    
    echo "🧠 Graphiti (Temporal Facts):"
    if [ -n "$GRAPHITI_OUT" ]; then
        echo "$GRAPHITI_OUT"
    else
        echo "  (no temporal facts found)"
    fi
    echo ""
    
    echo "📄 QMD (Document Search):"
    if [ -n "$QMD_OUT" ]; then
        echo "$QMD_OUT"
    else
        echo "  (no matching documents found)"
    fi
    echo ""
    echo "========================================"
fi
