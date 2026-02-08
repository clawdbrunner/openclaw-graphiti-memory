#!/usr/bin/env python3
"""Patch all agent AGENTS.md files with shared memory section."""
import os, re

AGENTS_DIR = os.path.expanduser("~/clawd/agents")

AGENTS = {
    "hazel": ("Hazel", "Household changes, service provider updates, maintenance findings."),
    "vincent": ("Vincent", "Password rotations, credential changes, security findings."),
    "vivian": ("Vivian", "Restaurant/venue discoveries, lifestyle preferences, booking details."),
    "chloe": ("Chloe", "Personal insights, wellness patterns, life events worth remembering."),
    "warren": ("Warren", "Financial decisions, market insights, investment changes."),
    "blake": ("Blake", "Portfolio allocations, asset performance, rebalancing decisions."),
    "sawyer": ("Sawyer", "Investment opportunities, market research findings."),
    "simon": ("Simon", "Risk alerts, portfolio exposure changes, compliance findings."),
    "maxwell": ("Maxwell", "Technology decisions, architecture changes, vendor evaluations."),
    "sloane": ("Sloane", "Product roadmap changes, feature decisions, user research insights."),
    "jordan": ("Jordan", "Project milestones, timeline changes, dependency issues."),
    "owen": ("Owen", "Infrastructure changes, deployment issues, system configurations."),
    "knox": ("Knox", "Security vulnerabilities, access changes, audit findings."),
    "rex": ("Rex", "Code architecture decisions, implementation patterns, technical debt."),
    "fiona": ("Fiona", "QA findings, test results, bug patterns."),
    "quinn": ("Quinn", "App feature changes, design decisions, user feedback."),
    "sage": ("Sage", "Research findings, competitive intelligence, industry trends."),
}

def make_snippet(agent_id, name, hint):
    return f"""
## 🧠 Shared Memory (Graphiti)

You have access to a **shared knowledge graph** that all agents contribute to. Use it for context.

**Before starting any task**, search for relevant context:
```bash
~/clawd/agents/_shared/bin/graphiti-search.sh "your query"
~/clawd/agents/_shared/bin/graphiti-context.sh "task description" {agent_id}
```

**Log significant discoveries** (to your own group only):
```bash
~/clawd/agents/_shared/bin/graphiti-log.sh {agent_id} assistant "{name}" "Important fact here"
```

**What to log:** {hint}
**What NOT to log:** Routine status, temporary task state, raw data dumps.
**Rules:** Never write to another agent's group or to user-chris/system-shared. Report updates to Clawd.
Full docs: ~/clawd/agents/_shared/graphiti-memory.md

---

"""

for agent_id, (name, hint) in AGENTS.items():
    path = os.path.join(AGENTS_DIR, agent_id, "AGENTS.md")
    if not os.path.exists(path):
        print(f"⚠️  {agent_id}: AGENTS.md not found")
        continue
    
    content = open(path).read()
    if "Shared Memory" in content:
        print(f"✅ {agent_id}: already patched")
        continue
    
    snippet = make_snippet(agent_id, name, hint)
    
    # Find insertion point
    for pattern in [r'^## Mission', r'^## Memory', r'^## Every Session']:
        m = re.search(pattern, content, re.MULTILINE)
        if m:
            pos = m.start()
            content = content[:pos] + snippet + content[pos:]
            break
    else:
        # Fallback: insert after first ---
        idx = content.find('---')
        if idx > 0:
            idx = content.find('\n', idx) + 1
            content = content[:idx] + snippet + content[idx:]
        else:
            content = snippet + content
    
    with open(path, 'w') as f:
        f.write(content)
    print(f"✅ {agent_id}: patched")

print("\nDone.")
