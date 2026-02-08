---
name: hybrid-memory
description: Hybrid memory strategy combining OpenClaw's built-in QMD vector memory with Graphiti temporal knowledge graph. Use for all memory recall requests.
---

# Hybrid Memory System

We use two memory systems integrated into a single view:

1. **QMD (Vector Store):** For retrieving documents, specs, and full content.
2. **Graphiti (Knowledge Graph):** For retrieving facts, timelines, and relationships.

## Primary Tool

For 95% of memory queries, use the hybrid search script. It queries both systems in parallel.

```bash
~/clawd/scripts/memory-hybrid-search.sh "your query"
```

Optional flags:
- `[group_id]` — Specify agent group (default: `clawdbot-main`)
- `--json` — Output JSON for programmatic use

## Specific Tools (Advanced)

Only use these if the hybrid script fails or you need granular control.

### Graphiti Only (Temporal/Facts)

Search for specific temporal facts:

```bash
~/clawd/scripts/graphiti-search.sh "your question" clawdbot-main 10
```

Log new facts (IMPORTANT):

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

## When to Use Which

| Question Type | Use |
|---------------|-----|
| "What's in GOALS.md?" | Hybrid search → `read` file |
| "When did we discuss X?" | Hybrid search (Graphiti results) |
| "What did I say last Tuesday?" | Graphiti direct |
| "Find notes about architecture" | Hybrid search (QMD results) |
