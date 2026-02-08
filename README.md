# OpenClaw Hybrid Memory: QMD + Graphiti + Shared Files

A complete three-layer memory system for [OpenClaw](https://openclaw.ai) multi-agent setups.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Agent Memory                       │
│                                                      │
│  Layer 1: Private Files (QMD)                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ piper/   │ │ paige/   │ │ dean/    │  ...       │
│  │ memory/  │ │ memory/  │ │ memory/  │            │
│  └──────────┘ └──────────┘ └──────────┘            │
│  Per-agent vector search via memory_search           │
│                                                      │
│  Layer 2: Shared Files (_shared/)                    │
│  ┌──────────────────────────────────┐               │
│  │ user-profile.md                  │               │
│  │ agent-roster.md                  │               │
│  │ infrastructure.md                │               │
│  │ graphiti-memory.md               │               │
│  └──────────────────────────────────┘               │
│  Symlinked into each agent workspace as shared/      │
│  Indexed by QMD alongside private files              │
│                                                      │
│  Layer 3: Shared Knowledge Graph (Graphiti)          │
│  ┌──────────────────────────────────┐               │
│  │ clawdbot-clawd  (write own)     │               │
│  │ clawdbot-piper  (write own)     │               │
│  │ user-main      (orchestrator)  │               │
│  │ system-shared   (orchestrator)  │               │
│  └──────────────────────────────────┘               │
│  Cross-group search for temporal facts               │
└─────────────────────────────────────────────────────┘
```

## Three Layers

| Layer | What | Best For | Mutability |
|-------|------|----------|------------|
| **Private Files** | Agent's own `memory/` dir | Private notes, task logs, local state | Agent writes freely |
| **Shared Files** | `_shared/` dir (symlinked) | Stable reference docs (profiles, roster) | Orchestrator maintains |
| **Shared Graph** | Graphiti knowledge graph | Temporal facts, cross-agent knowledge | Agents write to own group |

### When to use which

- **"What's the user's email?"** → Shared files (`user-profile.md`) or Graphiti
- **"What did I log yesterday?"** → Private files (`memory_search`)
- **"What did Piper find about that invoice?"** → Graphiti (cross-group search)
- **"Who handles security?"** → Shared files (`agent-roster.md`)
- **"When did we change the deployment config?"** → Graphiti (temporal)

---

## Setup

### Prerequisites

- [OpenClaw](https://openclaw.ai) installed and configured
- Docker (for Graphiti + Neo4j)
- An OpenAI API key (for Graphiti embeddings)

### 1. Install Graphiti Stack

```bash
git clone https://github.com/your-username/openclaw-graphiti-memory.git
cd openclaw-graphiti-memory

# Copy docker-compose to your services directory
cp docker-compose.yml ~/clawd/services/graphiti/

# Set your OpenAI key
export OPENAI_API_KEY="sk-..."

# Start the stack
cd ~/clawd/services/graphiti
docker compose up -d
```

### 2. Configure QMD in OpenClaw

Add to `~/.openclaw/openclaw.json` under `agents.defaults`:

```json
{
  "memorySearch": {
    "enabled": true,
    "sources": ["memory", "sessions"],
    "provider": "gemini",
    "model": "gemini-embedding-001",
    "sync": {
      "onSessionStart": true,
      "watch": true
    }
  }
}
```

### 3. Set Up Shared Directory

```bash
# Create the shared directory
mkdir -p ~/clawd/agents/_shared/bin

# Copy shared scripts
cp scripts/graphiti-search.sh ~/clawd/agents/_shared/bin/
cp scripts/graphiti-log.sh ~/clawd/agents/_shared/bin/
cp scripts/graphiti-context.sh ~/clawd/agents/_shared/bin/
chmod +x ~/clawd/agents/_shared/bin/*.sh

# Copy shared reference files
cp shared-files/*.md ~/clawd/agents/_shared/

# Symlink into each agent's workspace
for agent_dir in ~/clawd/agents/*/; do
  agent=$(basename "$agent_dir")
  [[ "$agent" == "_shared" || "$agent" == "_template" ]] && continue
  ln -sf ~/clawd/agents/_shared "$agent_dir/shared"
done
```

### 4. Add Memory Instructions to Agent AGENTS.md

Add the shared memory section to each agent's AGENTS.md. See `templates/shared-memory-snippet.md` for a copy-paste template, or use the patch script:

```bash
python3 scripts/patch-shared-memory.py
```

### 5. Seed Shared Context

```bash
# Seed user profile
scripts/graphiti-log.sh user-main system "System" "User lives in Example City, EST timezone."

# Seed agent roster
scripts/graphiti-log.sh system-shared system "System" "Agent team: Clawd (orchestrator), Piper (email), Paige (finance)..."
```

---

## Scripts

### For Agents (`_shared/bin/`)

| Script | Purpose |
|--------|---------|
| `graphiti-search.sh "query" [group_id] [max]` | Search knowledge graph |
| `graphiti-log.sh <agent_id> <role> <name> "content"` | Log facts to own group |
| `graphiti-context.sh "task" [agent_id]` | Get full context for a task |

### For Setup (`scripts/`)

| Script | Purpose |
|--------|---------|
| `memory-hybrid-search.sh "query"` | Search QMD + Graphiti together |
| `graphiti-import-files.py` | Bulk import files into Graphiti |
| `graphiti-sync-sessions.py` | Sync session transcripts to Graphiti |
| `graphiti-watch-files.py` | Watch files and auto-sync to Graphiti |
| `patch-shared-memory.py` | Patch all agent AGENTS.md files |

---

## Graphiti Groups

| Group | Owner | Purpose |
|-------|-------|---------|
| `clawdbot-<agent_id>` | Each agent | Agent's own discoveries and decisions |
| `user-main` | Orchestrator | User profile, preferences, contacts |
| `system-shared` | Orchestrator | Agent roster, infrastructure, active projects |

### Rules

1. Agents write to their **own group only**
2. Agents read **cross-group** (omit `group_id` for global search)
3. Only the orchestrator writes to `user-main` and `system-shared`
4. Shared files in `_shared/` are **read-only** for agents — report updates to orchestrator

---

## Docker Compose

The included `docker-compose.yml` runs:

- **Graphiti API** (port 8001) — REST API for the knowledge graph
- **Neo4j** (ports 7474/7687) — Graph database backend

Environment variables:
- `OPENAI_API_KEY` — Required for embeddings
- `MODEL_NAME` — LLM for entity extraction (default: `gpt-4.1-mini`, recommend `gpt-4.1`)

---

## Cost

- **QMD:** Free (local, uses Gemini embeddings which are free tier)
- **Graphiti:** OpenAI API costs for entity extraction during ingestion only
  - `gpt-4.1`: ~$2/M input, $8/M output tokens
  - Searches are free (local Neo4j queries)
  - Typical cost: < $1/month for a 20-agent setup

---

## License

MIT
