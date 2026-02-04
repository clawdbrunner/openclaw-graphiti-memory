#!/bin/bash
# memory-status.sh - Health check for QMD + Graphiti hybrid memory system
# Usage: memory-status.sh [--json]

JSON_MODE=false
if [ "$1" = "--json" ]; then
    JSON_MODE=true
fi

# Colors (only for terminal)
if [ "$JSON_MODE" = false ] && [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

QMD_PATH="${QMD_PATH:-$HOME/.bun/bin/qmd}"
GRAPHITI_URL="${GRAPHITI_URL:-http://localhost:8001}"
MEMORY_DIR="${MEMORY_DIR:-$HOME/clawd/memory}"
CLAWD_DIR="${CLAWD_DIR:-$HOME/clawd}"

# Status variables
QMD_OK=false
GRAPHITI_OK=false
FILE_SYNC_OK=false
SESSION_SYNC_OK=false
QMD_STATUS_MSG=""
GRAPHITI_API_MSG=""
GRAPHITI_CONTAINER_MSG=""
NEO4J_CONTAINER_MSG=""
FILE_SYNC_DAEMON_MSG=""
SESSION_SYNC_DAEMON_MSG=""
QMD_INDEXED="0"
GRAPHITI_FACTS="0"
FILE_SYNC_LAST="never"
SESSION_SYNC_LAST="never"

# Check QMD
check_qmd() {
    if [ ! -x "$QMD_PATH" ]; then
        QMD_STATUS_MSG="${RED}✗${NC} QMD binary not found"
        return 1
    fi
    
    if $QMD_PATH status >/dev/null 2>&1; then
        QMD_OK=true
        QMD_STATUS_MSG="${GREEN}✓${NC} QMD running"
        QMD_INDEXED="$(find ~/.cache/qmd -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
    else
        QMD_STATUS_MSG="${RED}✗${NC} QMD not responding"
    fi
}

# Check Graphiti API
check_graphiti() {
    HEALTH=$(curl -s "$GRAPHITI_URL/healthcheck" 2>/dev/null)
    if [ "$HEALTH" = '{"status":"ok"}' ]; then
        GRAPHITI_OK=true
        GRAPHITI_API_MSG="${GREEN}✓${NC} Graphiti API healthy"
    else
        GRAPHITI_API_MSG="${RED}✗${NC} Graphiti API not responding"
    fi
}

# Check Docker containers
check_docker() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^graphiti$"; then
        GRAPHITI_CONTAINER_MSG="${GREEN}✓${NC} Graphiti container running"
    else
        GRAPHITI_CONTAINER_MSG="${RED}✗${NC} Graphiti container not running"
    fi
    
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^neo4j$"; then
        NEO4J_CONTAINER_MSG="${GREEN}✓${NC} Neo4j container running"
    else
        NEO4J_CONTAINER_MSG="${RED}✗${NC} Neo4j container not running"
    fi
}

# Check sync daemons
check_daemons() {
    if launchctl list 2>/dev/null | grep -q "com.clawd.graphiti-file-sync"; then
        FILE_SYNC_OK=true
        FILE_SYNC_DAEMON_MSG="${GREEN}✓${NC} File sync daemon running"
    else
        FILE_SYNC_DAEMON_MSG="${RED}✗${NC} File sync daemon not loaded"
    fi
    
    if launchctl list 2>/dev/null | grep -q "com.clawd.graphiti-sync"; then
        SESSION_SYNC_OK=true
        SESSION_SYNC_DAEMON_MSG="${GREEN}✓${NC} Session sync daemon running"
    else
        SESSION_SYNC_DAEMON_MSG="${RED}✗${NC} Session sync daemon not loaded"
    fi
}

# Check last sync times
check_sync_times() {
    LOG_DIR="$HOME/.clawdbot/logs"
    
    if [ -f "$LOG_DIR/graphiti-file-sync.log" ]; then
        FILE_SYNC_LAST=$(stat -f %Sm "$LOG_DIR/graphiti-file-sync.log" 2>/dev/null | sed 's/ / T/')
    fi
    
    if [ -f "$LOG_DIR/graphiti-sync.log" ]; then
        SESSION_SYNC_LAST=$(stat -f %Sm "$LOG_DIR/graphiti-sync.log" 2>/dev/null | sed 's/ / T/')
    fi
}

# Run all checks
check_qmd
check_graphiti
check_docker
check_daemons
check_sync_times

# Output
if [ "$JSON_MODE" = true ]; then
    printf '{\n'
    printf '  "timestamp": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "overall": {\n'
    printf '    "qmd": %s,\n' "$(if $QMD_OK; then echo "true"; else echo "false"; fi)"
    printf '    "graphiti": %s,\n' "$(if $GRAPHITI_OK; then echo "true"; else echo "false"; fi)"
    printf '    "file_sync": %s,\n' "$(if $FILE_SYNC_OK; then echo "true"; else echo "false"; fi)"
    printf '    "session_sync": %s\n' "$(if $SESSION_SYNC_OK; then echo "true"; else echo "false"; fi)"
    printf '  },\n'
    printf '  "qmd": {\n'
    printf '    "status": "%s",\n' "$QMD_STATUS_MSG"
    printf '    "indexed_files": %s\n' "$QMD_INDEXED"
    printf '  },\n'
    printf '  "graphiti": {\n'
    printf '    "api_status": "%s",\n' "$GRAPHITI_API_MSG"
    printf '    "container_status": "%s",\n' "$GRAPHITI_CONTAINER_MSG"
    printf '    "neo4j_status": "%s"\n' "$NEO4J_CONTAINER_MSG"
    printf '  },\n'
    printf '  "sync": {\n'
    printf '    "file_sync_daemon": "%s",\n' "$FILE_SYNC_DAEMON_MSG"
    printf '    "session_sync_daemon": "%s",\n' "$SESSION_SYNC_DAEMON_MSG"
    printf '    "file_sync_last": "%s",\n' "$FILE_SYNC_LAST"
    printf '    "session_sync_last": "%s"\n' "$SESSION_SYNC_LAST"
    printf '  }\n'
    printf '}\n'
else
    echo "🔍 Hybrid Memory System Status"
    echo "================================"
    echo ""
    echo "QMD (Vector Store):"
    echo "  $QMD_STATUS_MSG"
    echo "  Indexed: ~$QMD_INDEXED files"
    echo ""
    echo "Graphiti (Knowledge Graph):"
    echo "  $GRAPHITI_API_MSG"
    echo "  $GRAPHITI_CONTAINER_MSG"
    echo "  $NEO4J_CONTAINER_MSG"
    echo ""
    echo "Sync Daemons:"
    echo "  $FILE_SYNC_DAEMON_MSG"
    echo "  $SESSION_SYNC_DAEMON_MSG"
    echo "  Last file sync: $FILE_SYNC_LAST"
    echo "  Last session sync: $SESSION_SYNC_LAST"
    echo ""
    echo "================================"
    
    if $QMD_OK && $GRAPHITI_OK && $FILE_SYNC_OK && $SESSION_SYNC_OK; then
        echo -e "${GREEN}✓ All systems operational${NC}"
    else
        echo -e "${YELLOW}⚠ Some systems need attention${NC}"
    fi
fi
