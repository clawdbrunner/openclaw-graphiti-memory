# OpenClaw + Graphiti: Hybrid Memory System

A complete guide to adding **temporal knowledge graph memory** to OpenClaw (formerly Moltbot/Clawdbot) using [Graphiti](https://github.com/getzep/graphiti) — the open-source temporal knowledge graph from Zep.

## Why This Matters

OpenClaw's built-in memory is great for document retrieval, but it struggles with temporal questions like:
- "When did we discuss X?"
- "What changed since last week?"
- "What was true on Tuesday vs today?"

**Graphiti adds:**
- Bi-temporal knowledge graph (event time + ingestion time)
- Automatic entity/relationship extraction
- Knowledge versioning (facts can be superseded)
- Sub-second retrieval

**This hybrid approach gives you:**
- File-based memory → Document retrieval, human-readable logs
- Graphiti → Temporal facts, "when did X happen?", entity tracking

## Quick Start

### 1. Install Docker (via Colima for macOS)

```bash
# Install Colima + Docker CLI (lightweight, no Docker Desktop needed)
brew install colima docker docker-compose

# Configure docker-compose plugin
mkdir -p ~/.docker
echo '{"cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]}' > ~/.docker/config.json

# Start Colima (4 CPU, 8GB RAM recommended)
colima start --cpu 4 --memory 8

# Enable auto-start on boot
brew services start colima
```

### 2. Deploy Graphiti Stack

```bash
# Create directory
mkdir -p ~/services/graphiti
cd ~/services/graphiti

# Download docker-compose.yml
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/docker-compose.yml

# Set your OpenAI API key (required for embeddings)
export OPENAI_API_KEY="your-key-here"

# Start the stack
docker compose up -d
```

Verify it's running:
```bash
curl http://localhost:8001/healthcheck
# Should return: {"status": "ok"}
```

### 3. Install the OpenClaw Skill

```bash
clawdhub install graphiti
```

Or manually copy the skill from this repo to your skills directory.

### 4. Set Up Auto-Sync

Copy the sync scripts to your workspace:

```bash
# Download scripts
mkdir -p ~/clawd/scripts
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-sync-sessions.py
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-watch-files.py
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-search.sh
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-log.sh
chmod +x ~/clawd/scripts/graphiti-*.sh ~/clawd/scripts/graphiti-*.py
```

Install the LaunchAgents for automatic sync:

```bash
# Download and load LaunchAgents
curl -o ~/Library/LaunchAgents/com.openclaw.graphiti-sync.plist \
  https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/launchagents/com.openclaw.graphiti-sync.plist

curl -o ~/Library/LaunchAgents/com.openclaw.graphiti-file-sync.plist \
  https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/launchagents/com.openclaw.graphiti-file-sync.plist

# Edit the plists to match your username/paths, then load them
launchctl load ~/Library/LaunchAgents/com.openclaw.graphiti-sync.plist
launchctl load ~/Library/LaunchAgents/com.openclaw.graphiti-file-sync.plist
```

### 5. Import Existing Memory Files

```bash
python3 ~/clawd/scripts/graphiti-import-files.py
```

## Usage

### Search for Temporal Facts

```bash
# Quick search
~/clawd/scripts/graphiti-search.sh "When was the project started?" my-group 10

# Via curl
curl -s -X POST "http://localhost:8001/search" \
  -H 'Content-Type: application/json' \
  -d '{"group_id": "my-group", "query": "your question", "max_facts": 10}'
```

### Log Important Facts

```bash
# Manual logging
~/clawd/scripts/graphiti-log.sh my-group user "Chris" "Important decision made today"

# Via curl
curl -s -X POST "http://localhost:8001/messages" \
  -H 'Content-Type: application/json' \
  -d '{
    "group_id": "my-group",
    "messages": [{
      "role_type": "user",
      "role": "Chris",
      "content": "Your message here",
      "timestamp": "2026-01-31T12:00:00Z"
    }]
  }'
```

### Access Neo4j Browser

Open http://localhost:7474 and log in with:
- Username: `neo4j`
- Password: `graphiti_memory_2026`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        OpenClaw                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐         ┌─────────────────┐           │
│  │  File Memory    │         │    Graphiti     │           │
│  │  (memory/*.md)  │         │  (Knowledge     │           │
│  │                 │         │   Graph)        │           │
│  │  • Documents    │         │                 │           │
│  │  • Daily logs   │◄───────►│  • Temporal     │           │
│  │  • Curated notes│  sync   │    facts        │           │
│  │                 │         │  • Entities     │           │
│  │  memory_search  │         │  • Relations    │           │
│  └─────────────────┘         └─────────────────┘           │
│           │                           │                     │
│           ▼                           ▼                     │
│  "What's in GOALS.md?"    "When did we discuss X?"         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Auto-Sync Daemons

| Daemon | Interval | What it syncs |
|--------|----------|---------------|
| `graphiti-sync` | 30 min | Session conversations |
| `graphiti-file-sync` | 10 min | Memory files (MEMORY.md, daily logs, etc.) |

## File Structure

```
~/clawd/
├── memory/
│   ├── logs/           # Daily logs (YYYY-MM-DD.md)
│   ├── projects/       # Project documentation
│   └── system/         # System files
├── scripts/
│   ├── graphiti-sync-sessions.py   # Session auto-sync
│   ├── graphiti-watch-files.py     # File change sync
│   ├── graphiti-import-files.py    # One-time import
│   ├── graphiti-search.sh          # Quick search
│   └── graphiti-log.sh             # Manual logging
└── services/
    └── graphiti/
        └── docker-compose.yml
```

## Customization

### Group IDs

Use different `group_id` values to separate contexts:
- `main-agent` — Primary conversational agent
- `email-agent` — Email-specific context
- `user-personal` — User's personal facts

### Adjusting Sync Intervals

Edit the LaunchAgent plists and change `StartInterval`:
- 600 = 10 minutes
- 1800 = 30 minutes
- 3600 = 1 hour

## Troubleshooting

### Graphiti not starting

```bash
# Check container logs
docker logs graphiti

# Verify Neo4j is healthy
docker logs neo4j
```

### Sync not working

```bash
# Check daemon status
launchctl list | grep graphiti

# Check logs
tail -f ~/.clawdbot/logs/graphiti-sync.log
```

### Reset everything

```bash
# Stop and remove containers
cd ~/services/graphiti && docker compose down -v

# Clear sync state
rm ~/.clawdbot/graphiti-sync-state.json
rm ~/.clawdbot/graphiti-file-hashes.json

# Restart
docker compose up -d
```

## Credits

- [Graphiti](https://github.com/getzep/graphiti) by Zep — The temporal knowledge graph engine
- [OpenClaw](https://openclaw.ai) — The AI assistant platform
- [Neo4j](https://neo4j.com) — Graph database

## License

MIT — See [LICENSE](LICENSE)

---

Built by [Clawd Brunner](https://github.com/clawdbrunner) 🦞
