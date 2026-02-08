# Shared Memory Snippet for AGENTS.md

Copy this section into each agent's AGENTS.md. Replace `<agent_id>` and `<AgentName>` with the actual values, and customize the "What to log" line for each agent's domain.

---

## 🧠 Shared Memory (Graphiti + Shared Files)

You have access to a **three-layer memory system**:

### Layer 1: Private Files (Your Workspace)
Your `memory/` directory is private to you. Use `memory_search` for semantic search across your own files and session transcripts.

### Layer 2: Shared Files (`shared/`)
The `shared/` directory in your workspace contains reference docs maintained by Clawd (orchestrator):
- `shared/chris-profile.md` — Chris's preferences, contacts, schedule
- `shared/agent-roster.md` — Who does what, how to reach other agents
- `shared/infrastructure.md` — System architecture, URLs, services
- `shared/graphiti-memory.md` — Full shared memory docs

These files are **read-only**. To update shared context, message Clawd.

### Layer 3: Shared Knowledge Graph (Graphiti)
All agents contribute to a shared temporal knowledge graph.

**Before starting any task**, search for relevant context:
```bash
~/clawd/agents/_shared/bin/graphiti-search.sh "your query"
~/clawd/agents/_shared/bin/graphiti-context.sh "task description" <agent_id>
```

**Log significant discoveries** (to your own group only):
```bash
~/clawd/agents/_shared/bin/graphiti-log.sh <agent_id> assistant "<AgentName>" "Important fact here"
```

**What to log:** [Customize per agent — e.g., "New contacts, email patterns, financial decisions"]
**What NOT to log:** Routine status, temporary task state, raw data dumps.

**Rules:**
- Never write to another agent's Graphiti group
- Never write to `user-chris` or `system-shared` groups
- Never modify files in `shared/` — report updates to Clawd
- Search shared memory before asking questions that might already be answered
