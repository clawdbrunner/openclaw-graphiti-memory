# Infrastructure

## Hardware

- **Mac Mini** (Apple Silicon) — user's home
  - Runs all agents via OpenClaw
  - Local IP: 192.168.1.100
  - Tailscale IP: 100.x.x.x

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| **Graphiti API** | http://localhost:8001 | Shared knowledge graph |
| **Neo4j Browser** | http://localhost:7474 | Graph database UI |
| **Agent Dashboard** | http://192.168.1.100:3080 | Mission Control |
| **OpenClaw Gateway** | http://localhost:3456 | Agent runtime |

## Media Stack (ElfHosted)

| Service | URL |
|---------|-----|
| **Plex** | https://bingewarp-plex.elfhosted.com |
| **Overseerr** | https://bingewarp.com |
| **Radarr** | https://bingewarp-radarr.elfhosted.com |
| **Sonarr** | https://bingewarp-sonarr.elfhosted.com |

## Communication Channels

- **Signal:** Primary User ↔ Agent channel
- **Slack:** Inter-agent coordination + User visibility
- **Twitter/X:** @exampleuser (User), @exampleagent (Agent)

## Docker (via Colima)

- Graphiti + Neo4j stack
- Agent Dashboard
- Cleanup: launchd job every hour
