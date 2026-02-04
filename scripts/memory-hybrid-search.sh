#!/bin/bash
# memory-hybrid-search.sh - Search both QMD (files) AND Graphiti (temporal facts)
#                        with cross-referenced results
# Usage: memory-hybrid-search.sh <query> [group_id] [--json] [--no-cross-ref]

QUERY="${1}"
GROUP_ID="${2:-clawdbot-main}"
JSON_MODE=false
NO_CROSS_REF=false
QMD_PATH="${QMD_PATH:-$HOME/.bun/bin/qmd}"
GRAPHITI_URL="${GRAPHITI_URL:-http://localhost:8001}"

# Parse optional flags
for arg in "$@"; do
    if [ "$arg" = "--json" ]; then
        JSON_MODE=true
    fi
    if [ "$arg" = "--no-cross-ref" ]; then
        NO_CROSS_REF=true
    fi
done

if [ -z "$QUERY" ]; then
    echo "Usage: memory-hybrid-search.sh <query> [group_id] [--json] [--no-cross-ref]" >&2
    exit 1
fi

# Helper: Get related facts for a file
get_related_facts() {
    local file_path="$1"
    local file_name=$(basename "$file_path" .md)
    
    # Search Graphiti for facts mentioning this file
    curl -s -X POST "$GRAPHITI_URL/search" \
        -H 'Content-Type: application/json' \
        -d "{\"group_id\":\"$GROUP_ID\",\"query\":\"$file_name\",\"max_facts\":3}" 2>/dev/null | \
        grep -oE '\[.*\]' | head -3
}

# Run searches in parallel and capture output
GRAPHITI_OUT=$(~/clawd/scripts/graphiti-search.sh "$QUERY" "$GROUP_ID" 5 2>/dev/null)
GRAPHITI_STATUS=$?

if [ -x "$QMD_PATH" ]; then
    # Get QMD results with more context
    QMD_OUT=$($QMD_PATH search "$QUERY" -n 5 --min-score 0.35 2>/dev/null)
    QMD_STATUS=$?
else
    QMD_OUT=""
    QMD_STATUS=1
fi

# Extract file paths from QMD results for cross-referencing
declare -a QMD_FILES
if [ -n "$QMD_OUT" ] && [ "$NO_CROSS_REF" = false ]; then
    while IFS= read -r line; do
        # Extract file path from qmd:// lines
        if [[ "$line" == qmd://* ]]; then
            file_path=$(echo "$line" | sed 's/qmd:\/\///' | cut -d':' -f1)
            QMD_FILES+=("$file_path")
        fi
    done <<< "$QMD_OUT"
fi

# Build cross-reference data
if [ "$JSON_MODE" = true ]; then
    # JSON output for programmatic use
    printf '{\n'
    printf '  "query": "%s",\n' "$QUERY"
    printf '  "group_id": "%s",\n' "$GROUP_ID"
    printf '  "graphiti": {\n'
    printf '    "status": "%s",\n' "$(if [ $GRAPHITI_STATUS -eq 0 ]; then echo "ok"; else echo "error"; fi)"
    printf '    "results": %s\n' "$(echo "$GRAPHITI_OUT" | grep -E '^\[' | head -5 | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')"
    printf '  },\n'
    printf '  "qmd": {\n'
    printf '    "status": "%s",\n' "$(if [ $QMD_STATUS -eq 0 ]; then echo "ok"; else echo "error"; fi)"
    printf '    "results": %s,\n' "$(echo "$QMD_OUT" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')"
    printf '    "cross_references": {\n'
    
    # Add cross-references for each file
    first=true
    for file_path in "${QMD_FILES[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            printf ',\n'
        fi
        file_name=$(basename "$file_path")
        related=$(get_related_facts "$file_path" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')
        printf '      "%s": %s' "$file_name" "$related"
    done
    printf '\n    }\n'
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
        # Display QMD results with cross-references
        current_file=""
        while IFS= read -r line; do
            echo "$line"
            
            # Check if this is a file header line (contains qmd://)
            if [[ "$line" == qmd://* ]] && [ "$NO_CROSS_REF" = false ]; then
                file_path=$(echo "$line" | sed 's/qmd:\/\///' | cut -d':' -f1)
                file_name=$(basename "$file_path" .md)
                
                # Get and display related facts
                related_facts=$(get_related_facts "$file_path")
                if [ -n "$related_facts" ]; then
                    echo ""
                    echo "  ↳ Related facts:"
                    echo "$related_facts" | sed 's/^/    /'
                fi
            fi
        done <<< "$QMD_OUT"
    else
        echo "  (no matching documents found)"
    fi
    echo ""
    echo "========================================"
    
    # Tip for users
    if [ ${#QMD_FILES[@]} -gt 0 ] && [ "$NO_CROSS_REF" = false ]; then
        echo ""
        echo "💡 Tip: Use --no-cross-ref to skip fact lookup (faster)"
    fi
fi
