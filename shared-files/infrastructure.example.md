# Infrastructure

## Hardware

- **Mac Mini** (Apple Silicon) — Puerto Rico, Chris's home
  - Runs all agents via OpenClaw
  - Local IP: 192.168.50.178
  - Tailscale IP: 100.102.70.120

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| **Graphiti API** | http://localhost:8001 | Shared knowledge graph |
| **Neo4j Browser** | http://localhost:7474 | Graph database UI |
| **Agent Dashboard** | http://192.168.50.178:3080 | Mission Control |
| **OpenClaw Gateway** | http://localhost:3456 | Agent runtime |

## Media Stack (ElfHosted)

| Service | URL |
|---------|-----|
| **Plex** | https://bingewarp-plex.elfhosted.com |
| **Overseerr** | https://bingewarp.com |
| **Radarr** | https://bingewarp-radarr.elfhosted.com |
| **Sonarr** | https://bingewarp-sonarr.elfhosted.com |

## Communication Channels

- **Signal:** Primary Chris ↔ Clawd channel
- **Slack:** Inter-agent coordination + Chris visibility
- **Twitter/X:** @chrisbrunner (Chris), @clawdbrunner (Clawd)

## Docker (via Colima)

- Graphiti + Neo4j stack
- Agent Dashboard
- Cleanup: launchd job every hour
