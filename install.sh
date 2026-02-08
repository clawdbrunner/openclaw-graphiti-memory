#!/bin/bash
# install.sh - One-command installer for QMD + Graphiti hybrid memory system
# Usage: ./install.sh [--dry-run]

set -e

DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No changes will be made"
    echo ""
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_URL="https://raw.githubusercontent.com/your-username/openclaw-graphiti-memory/main"
CLAWD_DIR="${CLAWD_DIR:-$HOME/clawd}"
SERVICES_DIR="$HOME/services"
SCRIPT_DIR="$CLAWD_DIR/scripts"
LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
fi

echo "🦞 Hybrid Memory System Installer"
echo "=================================="
echo ""
echo "OS detected: $OS"
echo "Install path: $CLAWD_DIR"
echo ""

# Track what we did
declare -a INSTALL_LOG
log_step() {
    INSTALL_LOG+=("$1")
    echo -e "${GREEN}✓${NC} $1"
}
log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}
log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Helper: Run command or echo in dry-run mode
run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

# Step 1: Check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    local missing=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    else
        log_step "Docker found"
    fi
    
    # Check docker-compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing+=("docker-compose")
    else
        log_step "Docker Compose found"
    fi
    
    # Check QMD
    if ! command -v qmd &> /dev/null && [ ! -x "$HOME/.bun/bin/qmd" ]; then
        log_warn "QMD not found. Install with: brew install qmd"
    else
        log_step "QMD found"
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        log_error "Missing prerequisites: ${missing[*]}"
        echo ""
        echo "Install on macOS:"
        echo "  brew install colima docker docker-compose qmd"
        echo ""
        echo "Install on Linux:"
        echo "  # Follow Docker installation guide for your distro"
        echo "  # Then: npm install -g qmd"
        exit 1
    fi
    
    echo ""
}

# Step 2: Create directory structure
create_directories() {
    echo "📁 Creating directory structure..."
    
    run_cmd mkdir -p "$CLAWD_DIR/memory/logs"
    run_cmd mkdir -p "$CLAWD_DIR/memory/projects"
    run_cmd mkdir -p "$CLAWD_DIR/memory/system"
    run_cmd mkdir -p "$SCRIPT_DIR"
    run_cmd mkdir -p "$SERVICES_DIR/graphiti"
    run_cmd mkdir -p "$HOME/.clawdbot/logs"
    
    if [ "$OS" = "macos" ]; then
        run_cmd mkdir -p "$LAUNCHAGENTS_DIR"
    fi
    
    log_step "Directory structure created"
    echo ""
}

# Step 3: Download scripts
download_scripts() {
    echo "⬇️  Downloading scripts..."
    
    local scripts=(
        "graphiti-search.sh"
        "graphiti-log.sh"
        "graphiti-sync-sessions.py"
        "graphiti-watch-files.py"
        "graphiti-import-files.py"
        "memory-hybrid-search.sh"
        "memory-status.sh"
    )
    
    for script in "${scripts[@]}"; do
        local url="$REPO_URL/scripts/$script"
        local dest="$SCRIPT_DIR/$script"
        
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY-RUN] Download $script → $dest"
        else
            if curl -fsSL "$url" -o "$dest" 2>/dev/null; then
                chmod +x "$dest" 2>/dev/null || true
                echo "  Downloaded: $script"
            else
                log_warn "Failed to download: $script"
            fi
        fi
    done
    
    log_step "Scripts downloaded"
    echo ""
}

# Step 4: Deploy Graphiti
deploy_graphiti() {
    echo "🐳 Deploying Graphiti..."
    
    local compose_url="$REPO_URL/docker-compose.yml"
    local compose_dest="$SERVICES_DIR/graphiti/docker-compose.yml"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] Download docker-compose.yml → $compose_dest"
        echo "  [DRY-RUN] Run: docker compose up -d"
    else
        if curl -fsSL "$compose_url" -o "$compose_dest" 2>/dev/null; then
            log_step "Docker Compose file downloaded"
            
            # Check if already running
            if docker ps | grep -q "graphiti"; then
                log_warn "Graphiti appears to already be running"
            else
                cd "$SERVICES_DIR/graphiti"
                if [ -n "$OPENAI_API_KEY" ]; then
                    docker compose up -d
                    log_step "Graphiti containers started"
                else
                    log_warn "OPENAI_API_KEY not set. Set it and run:"
                    log_warn "  cd $SERVICES_DIR/graphiti && docker compose up -d"
                fi
            fi
        else
            log_error "Failed to download docker-compose.yml"
        fi
    fi
    
    echo ""
}

# Step 5: Configure LaunchAgents (macOS only)
configure_launchd() {
    if [ "$OS" != "macos" ]; then
        log_info "Skipping LaunchAgent setup (Linux detected)"
        echo ""
        return
    fi
    
    echo "⚙️  Configuring LaunchAgents..."
    
    # File sync agent
    cat > /tmp/com.clawd.graphiti-file-sync.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clawd.graphiti-file-sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$SCRIPT_DIR/graphiti-watch-files.py</string>
    </array>
    <key>StartInterval</key>
    <integer>600</integer>
    <key>StandardOutPath</key>
    <string>$HOME/.clawdbot/logs/graphiti-file-sync.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.clawdbot/logs/graphiti-file-sync.log</string>
</dict>
</plist>
EOF
    
    # Session sync agent
    cat > /tmp/com.clawd.graphiti-sync.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clawd.graphiti-sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$SCRIPT_DIR/graphiti-sync-sessions.py</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>StandardOutPath</key>
    <string>$HOME/.clawdbot/logs/graphiti-sync.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.clawdbot/logs/graphiti-sync.log</string>
</dict>
</plist>
EOF
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] Copy LaunchAgents to $LAUNCHAGENTS_DIR"
        echo "  [DRY-RUN] launchctl load agents"
    else
        cp /tmp/com.clawd.graphiti-file-sync.plist "$LAUNCHAGENTS_DIR/"
        cp /tmp/com.clawd.graphiti-sync.plist "$LAUNCHAGENTS_DIR/"
        
        # Unload if already loaded
        launchctl unload "$LAUNCHAGENTS_DIR/com.clawd.graphiti-file-sync.plist" 2>/dev/null || true
        launchctl unload "$LAUNCHAGENTS_DIR/com.clawd.graphiti-sync.plist" 2>/dev/null || true
        
        # Load agents
        launchctl load "$LAUNCHAGENTS_DIR/com.clawd.graphiti-file-sync.plist" 2>/dev/null || true
        launchctl load "$LAUNCHAGENTS_DIR/com.clawd.graphiti-sync.plist" 2>/dev/null || true
        
        log_step "LaunchAgents configured and loaded"
    fi
    
    echo ""
}

# Step 6: Create sample MEMORY.md
create_sample_memory() {
    if [ -f "$CLAWD_DIR/MEMORY.md" ]; then
        log_info "MEMORY.md already exists, skipping"
        return
    fi
    
    echo "📝 Creating sample MEMORY.md..."
    
    cat > /tmp/MEMORY.md.sample <<'EOF'
# MEMORY.md — Long-Term Memory

*Curated memories, lessons, and context worth keeping.*

## Who I Am

Your agent identity and core context goes here.

## Who [User] Is

Information about the person you're helping.

## Key Systems

### Hybrid Memory

We use QMD (vector search) + Graphiti (temporal facts).

- Search: `~/clawd/scripts/memory-hybrid-search.sh "query"`
- Status: `~/clawd/scripts/memory-status.sh`

## Important Context

Add your ongoing projects, preferences, and important facts here.
EOF
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] Create $CLAWD_DIR/MEMORY.md"
    else
        cp /tmp/MEMORY.md.sample "$CLAWD_DIR/MEMORY.md"
        log_step "Sample MEMORY.md created"
    fi
    
    echo ""
}

# Step 7: Print OpenClaw config snippet
print_config_snippet() {
    echo "⚙️  OpenClaw Configuration"
    echo "========================="
    echo ""
    echo "Add this to your ~/.openclaw/openclaw.json:"
    echo ""
    cat <<EOF
{
  "memory": {
    "backend": "qmd",
    "qmd": {
      "command": "$HOME/.bun/bin/qmd",
      "includeDefaultMemory": true,
      "sessions": {
        "enabled": true,
        "retentionDays": 30
      },
      "update": {
        "interval": "5m",
        "debounceMs": 15000
      }
    }
  }
}
EOF
    echo ""
}

# Step 8: Run health check
run_health_check() {
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 [DRY-RUN] Would run: $SCRIPT_DIR/memory-status.sh"
        return
    fi
    
    echo "🔍 Running health check..."
    echo ""
    
    if [ -x "$SCRIPT_DIR/memory-status.sh" ]; then
        "$SCRIPT_DIR/memory-status.sh" || true
    else
        log_warn "Health check script not found"
    fi
    
    echo ""
}

# Step 9: Print summary
print_summary() {
    echo ""
    echo "=================================="
    echo "🎉 Installation Complete!"
    echo "=================================="
    echo ""
    echo "Quick commands:"
    echo "  ~/clawd/scripts/memory-hybrid-search.sh \"your query\""
    echo "  ~/clawd/scripts/memory-status.sh"
    echo "  ~/clawd/scripts/graphiti-log.sh clawdbot-main user \"Name\" \"Fact\""
    echo ""
    echo "Services:"
    echo "  Graphiti API: http://localhost:8001"
    echo "  Neo4j Browser: http://localhost:7474"
    echo ""
    echo "Useful paths:"
    echo "  Memory files: $CLAWD_DIR/memory/"
    echo "  Scripts: $SCRIPT_DIR/"
    echo "  Graphiti: $SERVICES_DIR/graphiti/"
    echo ""
    
    if [ ${#INSTALL_LOG[@]} -gt 0 ]; then
        echo "Installed:"
        for item in "${INSTALL_LOG[@]}"; do
            echo "  ✓ $item"
        done
        echo ""
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "${YELLOW}This was a dry run. Run without --dry-run to install.${NC}"
        echo ""
    fi
}

# Main execution
main() {
    check_prerequisites
    create_directories
    download_scripts
    deploy_graphiti
    configure_launchd
    create_sample_memory
    print_config_snippet
    run_health_check
    print_summary
}

main "$@"
