---
name: hybrid-memory
description: "Recalls past conversations, retrieves stored facts, and searches documents using OpenClaw QMD vector memory and Graphiti temporal knowledge graph. Use when the user asks to remember something, recall a previous discussion, look up what was said before, find prior context, check conversation history, or retrieve a stored fact or document."
---

# Hybrid Memory System

Combines two memory backends into a single recall layer:

1. **QMD (Vector Store):** Retrieves documents, specs, and full-text content by semantic similarity.
2. **Graphiti (Knowledge Graph):** Retrieves temporal facts, entity relationships, and cross-agent knowledge.

## Primary Tool

For most memory queries, use the hybrid search script. It queries both systems in parallel and merges results.

```bash
~/clawd/scripts/memory-hybrid-search.sh "your query"
```

Optional flags:
- `[group_id]` — Specify agent group (default: `clawdbot-main`)
- `--json` — Output JSON for programmatic use

## Specific Tools (Advanced)

Use these when the hybrid script returns no results, or when you need granular control over a single backend.

### Graphiti Only (Temporal/Facts)

Search for specific temporal facts:

```bash
~/clawd/scripts/graphiti-search.sh "your question" clawdbot-main 10
```

Log new facts (IMPORTANT — do this after key conversations or decisions):

```bash
~/clawd/scripts/graphiti-log.sh clawdbot-main user "Name" "Fact to remember"
```

### QMD Only (Deep Document Search)

If you need more results or specific file filtering:

```bash
qmd search "query" -n 10
```

## Recall Pattern

1. **User asks question** ("What was the plan for the project?")
2. **Run Hybrid Search** (`~/clawd/scripts/memory-hybrid-search.sh "plan for the project"`)
3. **Synthesize Answer** from both the temporal facts and document snippets found.
4. **If needed:** Use `read` to get the full content of a file found in the QMD results.
5. **If no results:** Retry with broader terms, try Graphiti direct (`graphiti-search.sh`), or widen QMD search (`qmd search "query" -n 20`).

## Proactive Logging

Keep the knowledge graph current by logging important facts after they occur:

- After the user shares a preference, decision, or key fact
- After completing a task with outcomes worth remembering
- After learning new entity relationships (people, projects, systems)

```bash
~/clawd/scripts/graphiti-log.sh clawdbot-main user "UserName" "User decided to use PostgreSQL for the new service"
```

## When to Use Which

| Question Type | Use |
|---------------|-----|
| "What's in GOALS.md?" | Hybrid search → `read` file |
| "When did we discuss X?" | Hybrid search (Graphiti results) |
| "What did I say last Tuesday?" | Graphiti direct |
| "Find notes about architecture" | Hybrid search (QMD results) |
| "Remember that I prefer dark mode" | `graphiti-log.sh` to store the fact |
