#!/usr/bin/env python3
"""
Watch memory files for changes and sync to Graphiti.
Runs as a daemon, triggered by launchd when files change.
"""

import json
import os
import sys
import hashlib
from datetime import datetime
from pathlib import Path
import urllib.request

GRAPHITI_URL = os.environ.get("GRAPHITI_URL", "http://localhost:8001")
MEMORY_DIR = Path.home() / "clawd/memory"
CLAWD_DIR = Path.home() / "clawd"
STATE_FILE = Path.home() / ".clawdbot/graphiti-file-hashes.json"

WATCHED_FILES = [
    CLAWD_DIR / "MEMORY.md",
    CLAWD_DIR / "IDENTITY.md", 
    CLAWD_DIR / "USER.md",
]

def load_state():
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except:
            pass
    return {"file_hashes": {}}

def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

def file_hash(filepath):
    if not filepath.exists():
        return None
    return hashlib.md5(filepath.read_bytes()).hexdigest()

def send_to_graphiti(content, timestamp, source):
    if len(content) > 3000:
        content = content[:3000] + "\n[...truncated]"
    
    payload = {
        "group_id": "clawdbot-main",
        "messages": [{
            "role_type": "system",
            "role": "FileUpdate",
            "content": content,
            "timestamp": timestamp,
            "source_description": source
        }]
    }
    
    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            f"{GRAPHITI_URL}/messages",
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status in (200, 202)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return False

def sync_file(filepath, state):
    """Sync a file if it has changed."""
    current_hash = file_hash(filepath)
    stored_hash = state["file_hashes"].get(str(filepath))
    
    if current_hash == stored_hash:
        return False  # No change
    
    if not filepath.exists():
        return False
    
    content = filepath.read_text()
    mtime = datetime.fromtimestamp(filepath.stat().st_mtime)
    timestamp = mtime.strftime("%Y-%m-%dT%H:%M:%SZ")
    
    message = f"File updated: {filepath.name}\n\n{content}"
    
    if send_to_graphiti(message, timestamp, f"file-update:{filepath.name}"):
        state["file_hashes"][str(filepath)] = current_hash
        print(f"✓ Synced {filepath.name}")
        return True
    else:
        print(f"✗ Failed to sync {filepath.name}")
        return False

def sync_daily_logs(state):
    """Sync any new or modified daily logs."""
    logs_dir = MEMORY_DIR / "logs"
    if not logs_dir.exists():
        return 0
    
    count = 0
    for logfile in logs_dir.glob("*.md"):
        if sync_file(logfile, state):
            count += 1
    return count

def main():
    # Check Graphiti
    try:
        req = urllib.request.Request(f"{GRAPHITI_URL}/healthcheck")
        urllib.request.urlopen(req, timeout=5)
    except:
        print("Graphiti not available")
        sys.exit(1)
    
    state = load_state()
    synced = 0
    
    # Sync watched files
    for filepath in WATCHED_FILES:
        if sync_file(filepath, state):
            synced += 1
    
    # Sync daily logs
    synced += sync_daily_logs(state)
    
    # Sync project files
    projects_dir = MEMORY_DIR / "projects"
    if projects_dir.exists():
        for filepath in projects_dir.glob("*.md"):
            if sync_file(filepath, state):
                synced += 1
    
    save_state(state)
    
    if synced > 0:
        print(f"Graphiti file sync: {synced} files updated")
    
    return synced

if __name__ == "__main__":
    main()
