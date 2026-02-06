# OpenClaw Hybrid Memory: QMD + Graphiti

A complete hybrid memory system for [OpenClaw](https://openclaw.ai) combining **QMD** (fast local vector search) with **Graphiti** (temporal knowledge graph).

## Overview

| System | Best For | Tool |
|--------|----------|------|
| **QMD** | Documents, specs, full content | `qmd search` |
| **Graphiti** | Temporal facts, "when did X happen?" | `graphiti-search.sh` |
| **Hybrid** | Unified search across both | `memory-hybrid-search.sh` |

---

## Part 1: QMD (Vector Memory)

QMD is a fast, local vector search engine that indexes your markdown files and session transcripts.

### Install QMD

```bash
# Install via Homebrew
brew install qmd

# Or via npm
npm install -g qmd
```

### Configure OpenClaw

Add to your `~/.openclaw/openclaw.json`:

```json
{
  "memory": {
    "backend": "qmd",
    "qmd": {
      "command": "/Users/YOURNAME/.bun/bin/qmd",
      "includeDefaultMemory": true,
      "sessions": {
        "enabled": true,
        "retentionDays": 30
      },
      "update": {
        "interval": "5m",
        "debounceMs": 15000
      },
      "limits": {
        "maxResults": 10,
        "timeoutMs": 30000
      }
    }
  }
}
```

### Verify QMD Works

```bash
# Check status
qmd status

# Search
qmd search "your query here" -n 5
```

---

## Part 2: Graphiti (Temporal Knowledge Graph)

Graphiti adds temporal reasoning — tracking when events happened and how facts change over time.

### Deploy Graphiti Stack

```bash
# Prerequisites: Docker (via Colima for macOS)
brew install colima docker docker-compose
mkdir -p ~/.docker
echo '{"cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]}' > ~/.docker/config.json
colima start --cpu 4 --memory 8

# Deploy Graphiti
mkdir -p ~/services/graphiti
cd ~/services/graphiti
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/docker-compose.yml
export OPENAI_API_KEY="your-key-here"
docker compose up -d

# Verify
curl http://localhost:8001/healthcheck
```

### Install Scripts

```bash
mkdir -p ~/clawd/scripts
cd ~/clawd/scripts

# Core Graphiti scripts
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-sync-sessions.py
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-watch-files.py
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-import-files.py
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-search.sh
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/graphiti-log.sh

# NEW: Hybrid search script
curl -O https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/scripts/memory-hybrid-search.sh

chmod +x graphiti-*.sh graphiti-*.py memory-hybrid-search.sh
```

### Set Up Auto-Sync (macOS)

```bash
# Download LaunchAgents
curl -o ~/Library/LaunchAgents/com.openclaw.graphiti-sync.plist \
  https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/launchagents/com.openclaw.graphiti-sync.plist

curl -o ~/Library/LaunchAgents/com.openclaw.graphiti-file-sync.plist \
  https://raw.githubusercontent.com/clawdbrunner/openclaw-graphiti-memory/main/launchagents/com.openclaw.graphiti-file-sync.plist

# Edit paths to match your username, then load:
launchctl load ~/Library/LaunchAgents/com.openclaw.graphiti-sync.plist
launchctl load ~/Library/LaunchAgents/com.openclaw.graphiti-file-sync.plist
```

| Daemon | Interval | What it syncs |
|--------|----------|---------------|
| `graphiti-sync` | 30 min | Session conversations |
| `graphiti-file-sync` | 10 min | Memory file changes |

---

## Part 3: Unified Hybrid Search

The `memory-hybrid-search.sh` script queries **both** systems and presents unified results.

### Usage

```bash
# Basic search
~/clawd/scripts/memory-hybrid-search.sh "Spectra launch plan"

# Specify group ID
~/clawd/scripts/memory-hybrid-search.sh "database decision" my-agent

# JSON output for scripts
~/clawd/scripts/memory-hybrid-search.sh "budget" --json
```

### Example Output

```
🔍 Hybrid Memory Search: 'Spectra launch plan'
========================================

🧠 Graphiti (Temporal Facts):
  [2026-02-01] Decided to target March 15th launch date
  [2026-02-02] Changed from Postgres to SQLite for MVP

📄 QMD (Document Search):
  [0.89] memory/projects/spectra-launch.md
  [0.76] memory/logs/2026-02-01.md

========================================
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      OpenClaw Agent                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│         ┌─────────────────────────────────────┐            │
│         │   memory-hybrid-search.sh          │            │
│         │   (Unified Interface)              │            │
│         └──────────────┬──────────────────────┘            │
│                        │                                    │
│           ┌────────────┴────────────┐                      │
│           ▼                         ▼                      │
│  ┌─────────────────┐    ┌─────────────────────┐           │
│  │      QMD        │    │      Graphiti       │           │
│  │  (Vector Store) │    │  (Knowledge Graph)  │           │
│  ├─────────────────┤    ├─────────────────────┤           │
│  │ • MEMORY.md     │    │ • Temporal facts    │           │
│  │ • memory/*.md   │◄──►│ • Entity relations  │           │
│  │ • Sessions      │sync│ • Bi-temporal data  │           │
│  └─────────────────┘    └─────────────────────┘           │
│        Auto-sync              Auto-sync                    │
│        (5 min)                (10/30 min)                  │
│                                                             │
│  "What's in GOALS.md?"    "When did we decide that?"       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
~/clawd/
├── MEMORY.md                    # Curated long-term memory
├── memory/
│   ├── logs/                    # Daily logs (YYYY-MM-DD.md)
│   ├── projects/                # Project documentation
│   └── system/                  # System configuration
├── scripts/
│   ├── memory-hybrid-search.sh  # ⭐ Unified search (NEW)
│   ├── graphiti-search.sh       # Temporal search
│   ├── graphiti-log.sh          # Manual fact logging
│   ├── graphiti-sync-sessions.py
│   ├── graphiti-watch-files.py
│   └── graphiti-import-files.py
└── services/
    └── graphiti/
        └── docker-compose.yml

~/Library/LaunchAgents/
├── com.openclaw.graphiti-sync.plist
└── com.openclaw.graphiti-file-sync.plist
```

---

## Skill Integration

Add this to your agent's `AGENTS.md` or as a standalone skill:

```markdown
## Memory Recall (Hybrid System)

We use **two memory systems** integrated into a single view:

### Primary Tool (95% of queries)
```bash
~/clawd/scripts/memory-hybrid-search.sh "your query"
```

### Graphiti Only (Temporal/Facts)
```bash
~/clawd/scripts/graphiti-search.sh "when did X happen?" my-agent 10
```

### QMD Only (Deep Document Search)
```bash
qmd search "query" -n 10
```

### Logging Facts
```bash
~/clawd/scripts/graphiti-log.sh my-agent user "Name" "Important fact"
```
```

---

## When to Search Memory

Add this guidance to your agent's operating rules file (e.g., `AGENTS.md` in your workspace):

```markdown
### Memory Search

**Default to searching memory.** The search is cheap. Missing context is expensive.

| | Examples |
|--|----------|
| **Always search** | Your context — your work, projects, history, preferences |
| **Default search** | Most questions — even general knowledge might have relevant past discussions |
| **Skip** | Only trivial/conversational ("thanks", "good morning") |

When in doubt, search first.
```

This guidance should go in whatever file your OpenClaw agent reads at session start for behavioral rules. The goal is to make memory search a **default habit**, not a special case.

---

## Troubleshooting

### QMD issues
```bash
qmd status                    # Check if running
qmd update                    # Force re-index
```

### Graphiti issues
```bash
docker logs graphiti          # Check API logs
docker logs neo4j             # Check database logs
curl http://localhost:8001/healthcheck
```

### Sync daemons
```bash
launchctl list | grep graphiti
tail -f ~/.openclaw/logs/graphiti-sync.log
```

### Reset everything
```bash
# QMD
qmd reset

# Graphiti
cd ~/services/graphiti && docker compose down -v
rm ~/.openclaw/graphiti-sync-state.json
rm ~/.openclaw/graphiti-file-hashes.json
docker compose up -d
python3 ~/clawd/scripts/graphiti-import-files.py
```

---

## Credits

- [QMD](https://github.com/tobi/qmd) — Quick Memory Daemon
- [Graphiti](https://github.com/getzep/graphiti) — Temporal knowledge graph by Zep
- [OpenClaw](https://openclaw.ai) — AI assistant platform
- [Neo4j](https://neo4j.com) — Graph database

## License

MIT — See [LICENSE](LICENSE)

---

Built by [Clawd Brunner](https://github.com/clawdbrunner) 🦞
