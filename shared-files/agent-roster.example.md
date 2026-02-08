# Agent Roster

## How to Reach Another Agent

```bash
# Send a message to another agent
sessions_send sessionKey="agent:<name>:main" message="your message"

# Mirror to Slack for visibility
~/clawd/agents/_shared/bin/agent-msg.sh <your_id> <target_id> "your message"
```

Full protocol: `~/clawd/agents/_shared/agent-comms.md`

## Active Agents

| Agent | ID | Role | Department | Model |
|-------|-----|------|-----------|-------|
| **Clawd** | `clawd` | Orchestrator | Core | Opus 4.6 |
| **Piper** | `piper` | Email Handler | Core | GLM 4.7 |
| **Dean** | `dean` | Agent Architect | Core | Default (NVIDIA Kimi) |
| **Sage** | `sage` | Research | Core | Gemini Flash |
| **Paige** | `paige` | Finance/Ledger | Operations | Default (NVIDIA Kimi) |
| **Hazel** | `hazel` | Household | Operations | Default (NVIDIA Kimi) |
| **Vincent** | `vincent` | Vault/Passwords | Operations | Default (NVIDIA Kimi) |
| **Vivian** | `vivian` | Concierge | Lifestyle | Default (NVIDIA Kimi) |
| **Chloe** | `chloe` | Chronicle | Lifestyle | Default (NVIDIA Kimi) |
| **Warren** | `warren` | CFO | Investment | Default (NVIDIA Kimi) |
| **Blake** | `blake` | Allocator | Investment | Default (NVIDIA Kimi) |
| **Sawyer** | `sawyer` | Scout | Investment | Default (NVIDIA Kimi) |
| **Simon** | `simon` | Sentinel | Investment | Default (NVIDIA Kimi) |
| **Maxwell** | `maxwell` | CTO | Technology | Default (NVIDIA Kimi) |
| **Sloane** | `sloane` | Product Manager | Technology | Default (NVIDIA Kimi) |
| **Jordan** | `jordan` | Project Manager | Technology | Default (NVIDIA Kimi) |
| **Owen** | `owen` | DevOps | Technology | Default (NVIDIA Kimi) |
| **Knox** | `knox` | Security | Technology | Default (NVIDIA Kimi) |
| **Rex** | `rex` | Software Engineer | Technology | Default (NVIDIA Kimi) |
| **Fiona** | `fiona` | QA | Technology | Default (NVIDIA Kimi) |
| **Quinn** | `quinn` | Mobile Dev | Technology | Default (NVIDIA Kimi) |

## Department Leads

- **Core:** Clawd (orchestrator for all)
- **Operations:** Reports to Clawd
- **Lifestyle:** Reports to Clawd
- **Investment:** Warren (CFO)
- **Technology:** Maxwell (CTO)

## Escalation Path

Agent → Department Lead → Clawd → Chris
