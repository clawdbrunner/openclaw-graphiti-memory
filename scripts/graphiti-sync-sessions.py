#!/usr/bin/env python3
"""
Sync Clawdbot session messages to Graphiti knowledge graph.
Runs periodically to keep Graphiti updated with conversation history.
"""

import json
import os
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
import urllib.request
import urllib.error

GRAPHITI_URL = os.environ.get("GRAPHITI_URL", "http://localhost:8001")
SESSIONS_DIR = Path.home() / ".clawdbot/agents/main/sessions"
SYNC_STATE_FILE = Path.home() / ".clawdbot/graphiti-sync-state.json"
MAX_MESSAGES_PER_RUN = 50

def load_sync_state():
    """Load the sync state tracking which messages have been synced."""
    if SYNC_STATE_FILE.exists():
        try:
            return json.loads(SYNC_STATE_FILE.read_text())
        except:
            pass
    return {"synced_messages": {}, "last_sync": None}

def save_sync_state(state):
    """Save the sync state."""
    SYNC_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    SYNC_STATE_FILE.write_text(json.dumps(state, indent=2))

def check_graphiti():
    """Check if Graphiti is available."""
    try:
        req = urllib.request.Request(f"{GRAPHITI_URL}/healthcheck")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except:
        return False

def send_to_graphiti(group_id, role_type, role, content, timestamp):
    """Send a message to Graphiti."""
    payload = {
        "group_id": group_id,
        "messages": [{
            "role_type": role_type,
            "role": role,
            "content": content[:2000],  # Truncate long messages
            "timestamp": timestamp
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
            return resp.status == 200
    except Exception as e:
        print(f"Error sending to Graphiti: {e}", file=sys.stderr)
        return False

def extract_text_content(content):
    """Extract text from message content."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for item in content:
            if isinstance(item, dict) and item.get('type') == 'text':
                texts.append(item.get('text', ''))
            elif isinstance(item, str):
                texts.append(item)
        return ' '.join(texts)
    return ''

def should_sync_message(content):
    """Determine if a message should be synced."""
    if not content or len(content) < 10:
        return False
    
    # Skip system/internal messages
    skip_patterns = [
        '[Signal', '[Slack', 'HEARTBEAT', 'NO_REPLY', 
        '✅ New session', 'System:', '[message_id:'
    ]
    for pattern in skip_patterns:
        if pattern in content:
            return False
    
    return True

def sync_sessions():
    """Main sync function."""
    if not check_graphiti():
        print("Graphiti not available")
        return 0
    
    state = load_sync_state()
    synced_count = 0
    
    # Find session files modified in last 24 hours
    cutoff = datetime.now() - timedelta(hours=24)
    session_files = []
    
    if SESSIONS_DIR.exists():
        for f in SESSIONS_DIR.glob("*.jsonl"):
            if datetime.fromtimestamp(f.stat().st_mtime) > cutoff:
                session_files.append(f)
    
    for session_file in sorted(session_files, key=lambda x: x.stat().st_mtime):
        if synced_count >= MAX_MESSAGES_PER_RUN:
            break
            
        try:
            with open(session_file, 'r') as f:
                for line in f:
                    if synced_count >= MAX_MESSAGES_PER_RUN:
                        break
                    
                    try:
                        entry = json.loads(line.strip())
                    except json.JSONDecodeError:
                        continue
                    
                    # Only process message entries
                    if entry.get('type') != 'message':
                        continue
                    
                    msg_id = entry.get('id')
                    if not msg_id or msg_id in state['synced_messages']:
                        continue
                    
                    message = entry.get('message', {})
                    role = message.get('role', '')
                    timestamp = entry.get('timestamp', datetime.now().isoformat())
                    
                    # Only sync user and assistant messages
                    if role not in ('user', 'assistant'):
                        continue
                    
                    content = extract_text_content(message.get('content', ''))
                    
                    if not should_sync_message(content):
                        continue
                    
                    # Determine role_type and speaker
                    role_type = 'user' if role == 'user' else 'assistant'
                    speaker = 'User' if role == 'user' else 'Agent'
                    
                    # Send to Graphiti
                    if send_to_graphiti('clawdbot-main', role_type, speaker, content, timestamp):
                        state['synced_messages'][msg_id] = datetime.now().isoformat()
                        synced_count += 1
                        time.sleep(0.3)  # Rate limit
                    
        except Exception as e:
            print(f"Error processing {session_file}: {e}", file=sys.stderr)
            continue
    
    state['last_sync'] = datetime.now().isoformat()
    save_sync_state(state)
    
    print(f"Graphiti sync: {synced_count} messages synced")
    return synced_count

if __name__ == "__main__":
    sync_sessions()
