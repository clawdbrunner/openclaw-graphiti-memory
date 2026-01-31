# OpenClaw Hybrid Memory: Complete Setup Guide

A complete guide to setting up **hybrid memory** for [OpenClaw](https://openclaw.ai) — combining built-in vector memory search with [Graphiti](https://github.com/getzep/graphiti), Zep's open-source temporal knowledge graph.

## Why Hybrid Memory?

OpenClaw's built-in memory search is great for document retrieval:
- "What's in GOALS.md?"
- "Find notes about the project architecture"
- Semantic search across all your markdown files

But it struggles with **temporal questions**:
- "When did we discuss X?"
- "What changed since last week?"
- "What was true on Tuesday vs today?"

**The solution:** Use both systems together.

| System | Best For | Tool |
|--------|----------|------|
| OpenClaw Memory | Documents, logs, curated notes | `memory_search` |
| Graphiti | Temporal facts, "when did X happen?", entity tracking | `graphiti-search.sh` |

---

## Part 1: OpenClaw Memory Search (Built-in)

OpenClaw has built-in vector memory search that indexes your markdown files. By default it's enabled but needs an embedding provider configured.

### Quick Check

```bash
openclaw status
```

Look for memory search status. If it says "no embedding provider configured," follow the steps below.

### Option A: Gemini Embeddings (Recommended — Free Tier Available)

1. **Get a Gemini API key** from [Google AI Studio](https://aistudio.google.com/apikey)

2. **Add to your OpenClaw config** (`~/.openclaw/openclaw.json`):

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "enabled": true,
        "provider": "gemini",
        "model": "text-embedding-004",
        "remote": {
          "apiKey": "YOUR_GEMINI_API_KEY"
        }
      }
    }
  }
}
```

Or via environment variable:
```bash
export GEMINI_API_KEY="your-key-here"
```

3. **Restart the gateway:**
```bash
openclaw gateway restart
```

### Option B: OpenAI Embeddings

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "enabled": true,
        "provider": "openai",
        "model": "text-embedding-3-small"
      }
    }
  }
}
```

OpenClaw will use your existing OpenAI API key if configured.

### Option C: Local Embeddings (No API Key)

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "enabled": true,
        "provider": "local"
      }
    }
  }
}
```

Note: Local mode requires `pnpm approve-builds` for node-llama-cpp. The default model (~0.6GB) auto-downloads on first use.

### Verify Memory Search Works

```bash
openclaw memory status
```

You should see your memory files indexed. Test it:

```bash
openclaw memory search "your query here"
```

### Memory File Structure

OpenClaw indexes these paths by default:
- `MEMORY.md` — Curated long-term memory
- `memory/**/*.md` — Daily logs and notes

Recommended structure:
```
~/.openclaw/workspace/
├── MEMORY.md              # Curated long-term memory
└── memory/
    ├── logs/
    │   ├── 2026-01-30.md  # Daily logs
    │   └── 2026-01-31.md
    └── projects/
        └── goals.md       # Project docs
```

### Add Extra Paths (Optional)

To index markdown files outside the default locations:

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "extraPaths": ["../team-docs", "/srv/shared-notes"]
      }
    }
  }
}
```

---

## Part 2: Graphiti (Temporal Knowledge Graph)

Now that basic memory search works, let's add Graphiti for temporal reasoning.

### What Graphiti Adds

- **Bi-temporal knowledge graph** — tracks both when events happened and when you learned about them
- **Automatic entity extraction** — identifies people, projects, decisions
- **Knowledge versioning** — facts can be superseded over time
- **Sub-second retrieval** — fast queries even with large graphs

### Install Docker (via Colima for macOS)

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

### Deploy Graphiti Stack

```bash
# Create directory
mkdir -p ~/services/graphiti
cd ~/services/graphiti

# Download docker-compose.yml
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/docker-compose.yml

# Set your OpenAI API key (required for Graphiti's entity extraction)
export OPENAI_API_KEY="your-key-here"

# Start the stack
docker compose up -d
```

Verify it's running:
```bash
curl http://localhost:8001/healthcheck
# Should return: {"status": "ok"}
```

### Install Scripts

```bash
# Download scripts to your workspace
mkdir -p ~/clawd/scripts
cd ~/clawd/scripts

curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-sync-sessions.py
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-watch-files.py
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-import-files.py
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-search.sh
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-log.sh

chmod +x graphiti-*.sh graphiti-*.py
```

### Install the OpenClaw Skill (Optional)

```bash
clawdhub install graphiti
```

This adds Graphiti-specific instructions to your agent's skill set.

### Set Up Auto-Sync (macOS)

These LaunchAgents keep Graphiti in sync automatically:

```bash
# Download LaunchAgent templates
curl -o ~/Library/LaunchAgents/com.openclaw.graphiti-sync.plist \
  https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/launchagents/com.openclaw.graphiti-sync.plist

curl -o ~/Library/LaunchAgents/com.openclaw.graphiti-file-sync.plist \
  https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/launchagents/com.openclaw.graphiti-file-sync.plist
```

**Important:** Edit the plists to match your username and paths, then load them:

```bash
launchctl load ~/Library/LaunchAgents/com.openclaw.graphiti-sync.plist
launchctl load ~/Library/LaunchAgents/com.openclaw.graphiti-file-sync.plist
```

| Daemon | Interval | What it syncs |
|--------|----------|---------------|
| `graphiti-sync` | 30 min | Session conversations → Graphiti |
| `graphiti-file-sync` | 10 min | Memory files → Graphiti |

### Import Existing Memory Files

One-time import of your existing memory files:

```bash
python3 ~/clawd/scripts/graphiti-import-files.py
```

---

## Part 3: Using Hybrid Memory

Now you have both systems running. Here's when to use each:

### Document Retrieval → memory_search

The agent uses this automatically via the `memory_search` tool:
- "What's in our goals document?"
- "Find notes about the architecture"
- "What did I write about X?"

### Temporal Questions → Graphiti

Use the search script for "when" questions:

```bash
# Quick search
~/clawd/scripts/graphiti-search.sh "When did we set up the Slack integration?" my-agent 10

# Via curl
curl -s -X POST "http://localhost:8001/search" \
  -H 'Content-Type: application/json' \
  -d '{"group_id": "my-agent", "query": "When did we set up Slack?", "max_facts": 10}'
```

### Log Important Facts Manually

```bash
# Log a decision or important fact
~/clawd/scripts/graphiti-log.sh my-agent user "Chris" "Decided to use Postgres instead of SQLite for the main database"
```

### Update Your AGENTS.md

Add instructions for your agent to use both systems:

```markdown
## Memory Recall (Hybrid System)

We use **two memory systems** — use both!

**For temporal questions** ("when did X happen?", "what did we discuss last Tuesday?"):
```bash
~/clawd/scripts/graphiti-search.sh "your query" my-agent 10
```

**For document retrieval** ("what's in GOALS.md?", "find project docs about X"):
```
memory_search query="your query"
```

**When answering questions about past context:**
1. Check Graphiti for temporal facts first
2. Use `memory_search` for document content
3. If low confidence after both, say you checked
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         OpenClaw                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐         ┌─────────────────┐           │
│  │  Vector Memory  │         │    Graphiti     │           │
│  │  (Built-in)     │         │  (Knowledge     │           │
│  │                 │         │   Graph)        │           │
│  │  • MEMORY.md    │         │                 │           │
│  │  • memory/*.md  │◄───────►│  • Temporal     │           │
│  │  • Semantic     │  sync   │    facts        │           │
│  │    search       │         │  • Entities     │           │
│  │                 │         │  • Relations    │           │
│  │  memory_search  │         │  graphiti-      │           │
│  │  memory_get     │         │  search.sh      │           │
│  └─────────────────┘         └─────────────────┘           │
│           │                           │                     │
│           ▼                           ▼                     │
│  "What's in GOALS.md?"    "When did we discuss X?"         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
~/clawd/
├── MEMORY.md               # Curated long-term memory
├── memory/
│   ├── logs/               # Daily logs (YYYY-MM-DD.md)
│   ├── projects/           # Project documentation
│   └── system/             # System files
├── scripts/
│   ├── graphiti-sync-sessions.py   # Session auto-sync
│   ├── graphiti-watch-files.py     # File change sync
│   ├── graphiti-import-files.py    # One-time import
│   ├── graphiti-search.sh          # Quick temporal search
│   └── graphiti-log.sh             # Manual fact logging
└── services/
    └── graphiti/
        └── docker-compose.yml

~/Library/LaunchAgents/
├── com.openclaw.graphiti-sync.plist
└── com.openclaw.graphiti-file-sync.plist
```

---

## Customization

### Group IDs

Use different `group_id` values to separate contexts:
- `main-agent` — Primary conversational agent
- `email-agent` — Email processing agent
- `user-personal` — User's personal facts

### Adjusting Sync Intervals

Edit the LaunchAgent plists and change `StartInterval`:
- 600 = 10 minutes
- 1800 = 30 minutes
- 3600 = 1 hour

### Neo4j Browser

Access the graph directly at http://localhost:7474
- Username: `neo4j`
- Password: `graphiti_memory_2026`

---

## Troubleshooting

### Memory search not working

```bash
# Check status
openclaw memory status

# Verify embedding provider
openclaw status --all | grep -A5 memory
```

Common issues:
- No API key configured for embeddings
- Workspace path doesn't exist
- No markdown files to index

### Graphiti not starting

```bash
# Check container logs
docker logs graphiti
docker logs neo4j

# Verify health
curl http://localhost:8001/healthcheck
```

### Sync daemons not running

```bash
# Check daemon status
launchctl list | grep graphiti

# Check logs
tail -f ~/.openclaw/logs/graphiti-sync.log
```

### Reset Graphiti (start fresh)

```bash
# Stop and remove containers + volumes
cd ~/services/graphiti && docker compose down -v

# Clear sync state
rm ~/.openclaw/graphiti-sync-state.json
rm ~/.openclaw/graphiti-file-hashes.json

# Restart
docker compose up -d

# Re-import files
python3 ~/clawd/scripts/graphiti-import-files.py
```

---

## Credits

- [Graphiti](https://github.com/getzep/graphiti) by Zep — The temporal knowledge graph engine
- [OpenClaw](https://openclaw.ai) — The AI assistant platform
- [Neo4j](https://neo4j.com) — Graph database

## License

MIT — See [LICENSE](LICENSE)

---

Built by [Clawd Brunner](https://github.com/clawdbrunner) 🦞
