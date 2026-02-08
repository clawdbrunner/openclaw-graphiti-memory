# Shared Memory (Graphiti)

All agents share a temporal knowledge graph powered by Graphiti. This is how we maintain shared context without file sync issues.

## How It Works

- **Graphiti** stores facts as a knowledge graph with temporal validity
- Each agent has their own **group** (`clawdbot-<your_id>`)
- You **write** to your own group only
- You **read** across ALL groups (shared memory)
- Facts auto-expire when superseded by newer information

## When to Search Shared Memory

**Before starting any task**, search for relevant context:

```bash
# Cross-group search (sees all agents' knowledge)
~/clawd/agents/_shared/bin/graphiti-search.sh "your query"

# Full context for a task (cross-group + user + system)
~/clawd/agents/_shared/bin/graphiti-context.sh "task description" <your_agent_id>
```

**Search when:**
- Starting a new task from Chris or another agent
- You need info about Chris (preferences, schedule, contacts)
- You need info another agent might have (e.g., Piper's email findings)
- You're making a decision that other agents should be aware of
- You're unsure about something that might have been discussed before

## When to Write to Shared Memory

Log **significant facts** that other agents might need:

```bash
# Log a discovery or decision
~/clawd/agents/_shared/bin/graphiti-log.sh <your_agent_id> assistant "<YourName>" "Discovered that Chris's accountant email is tax@example.com"

# Log something Chris told you
~/clawd/agents/_shared/bin/graphiti-log.sh <your_agent_id> user "Chris" "Chris said he prefers morning meetings before 10am"
```

**Write when:**
- You learn a new fact about Chris or the household
- You complete a task with notable results
- You make a decision that affects other agents
- You discover something that changes shared context (new vendor, changed address, etc.)

**Don't write:**
- Routine status updates (use Slack activity channels)
- Temporary task state (use your local WORKING.md)
- Raw data dumps (summarize the key facts instead)

## Groups

| Group | Owner | Contains |
|-------|-------|----------|
| `clawdbot-<agent_id>` | Each agent | Agent's discoveries, decisions, task results |
| `user-chris` | Clawd (orchestrator) | Chris's profile, preferences, contacts |
| `system-shared` | Clawd (orchestrator) | Agent roster, household info, active projects |

## Rules

1. **NEVER write to another agent's group** — write to your own group only
2. **NEVER write to `user-chris` or `system-shared`** — only Clawd maintains these
3. **Always search before asking** — the answer might already be in shared memory
4. **Log significant findings** — if it would help another agent, write it
5. **Be concise** — log facts, not conversations
