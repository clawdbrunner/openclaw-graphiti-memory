#!/usr/bin/env python3
"""
Watch memory files for changes and sync to Graphiti with contextual summaries.
Runs as a daemon, triggered by launchd when files change.
"""

import json
import os
import sys
import hashlib
import difflib
import re
from datetime import datetime
from pathlib import Path
import urllib.request

GRAPHITI_URL = os.environ.get("GRAPHITI_URL", "http://localhost:8001")
MEMORY_DIR = Path.home() / "clawd/memory"
CLAWD_DIR = Path.home() / "clawd"
STATE_DIR = Path.home() / ".clawdbot"
STATE_FILE = STATE_DIR / "graphiti-file-hashes.json"
CONTENT_CACHE_DIR = STATE_DIR / "file-cache"

WATCHED_FILES = [
    CLAWD_DIR / "MEMORY.md",
    CLAWD_DIR / "IDENTITY.md", 
    CLAWD_DIR / "USER.md",
]

# Files to skip for content caching (too large or sensitive)
SKIP_CONTENT_CACHE = []

def load_state():
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except:
            pass
    return {"file_hashes": {}, "last_summaries": {}}

def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

def file_hash(filepath):
    if not filepath.exists():
        return None
    return hashlib.md5(filepath.read_bytes()).hexdigest()

def get_cached_content(filepath):
    """Get previous version of file from cache."""
    cache_file = CONTENT_CACHE_DIR / f"{filepath.name}.cache"
    if cache_file.exists():
        return cache_file.read_text()
    return ""

def save_cached_content(filepath, content):
    """Save current version to cache."""
    CONTENT_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_file = CONTENT_CACHE_DIR / f"{filepath.name}.cache"
    cache_file.write_text(content)

def extract_headings(text):
    """Extract markdown headings from text."""
    headings = re.findall(r'^#{1,6}\s+(.+)$', text, re.MULTILINE)
    return headings

def generate_diff_summary(old_content, new_content, filename):
    """Generate a human-readable summary of what changed."""
    old_lines = old_content.splitlines() if old_content else []
    new_lines = new_content.splitlines()
    
    # Get unified diff
    diff = list(difflib.unified_diff(old_lines, new_lines, lineterm='', n=2))
    
    if not diff:
        return None
    
    # Analyze the diff
    added_lines = [line[1:] for line in diff if line.startswith('+') and not line.startswith('+++')]
    removed_lines = [line[1:] for line in diff if line.startswith('-') and not line.startswith('---')]
    
    # Get headings context
    new_headings = extract_headings(new_content)
    old_headings = extract_headings(old_content)
    
    added_sections = [h for h in new_headings if h not in old_headings]
    removed_sections = [h for h in old_headings if h not in new_headings]
    
    # Build summary
    summary_parts = []
    
    if added_sections:
        sections_str = ', '.join(f'"{s}"' for s in added_sections[:3])
        if len(added_sections) > 3:
            sections_str += f" and {len(added_sections) - 3} more"
        summary_parts.append(f"Added sections: {sections_str}")
    
    if removed_sections:
        sections_str = ', '.join(f'"{s}"' for s in removed_sections[:2])
        summary_parts.append(f"Removed sections: {sections_str}")
    
    # Check for key facts in additions
    key_patterns = [
        (r'\b(decided|decision)\b', 'decisions'),
        (r'\b(created|added|implemented|built)\b', 'new items'),
        (r'\b(updated|changed|modified)\b', 'updates'),
        (r'\b(fixed|resolved|solved)\b', 'fixes'),
        (r'\b(configured|setup|installed)\b', 'configuration'),
        (r'\b(completed|finished|done)\b', 'completions'),
    ]
    
    changes_found = []
    for pattern, label in key_patterns:
        matches = [line for line in added_lines if re.search(pattern, line, re.IGNORECASE) and len(line) > 10]
        if matches:
            changes_found.append((label, matches[:2]))
    
    if changes_found:
        for label, matches in changes_found[:2]:
            for match in matches[:1]:
                # Clean up the match
                clean = match.strip().rstrip('.')
                if len(clean) > 80:
                    clean = clean[:77] + "..."
                summary_parts.append(f"{label}: {clean}")
    
    # Fallback: just note lines changed
    if not summary_parts:
        if len(added_lines) > 0:
            summary_parts.append(f"Added {len(added_lines)} lines")
        if len(removed_lines) > 0:
            summary_parts.append(f"Removed {len(removed_lines)} lines")
    
    # Get the first meaningful added line as context
    context = ""
    for line in added_lines:
        stripped = line.strip()
        if stripped and not stripped.startswith('#') and len(stripped) > 15:
            context = stripped[:120]
            if len(stripped) > 120:
                context += "..."
            break
    
    summary = f"File updated: {filename}"
    if summary_parts:
        summary += " — " + "; ".join(summary_parts[:3])
    if context:
        summary += f"\nContext: {context}"
    
    return summary

def send_summary_to_graphiti(summary, timestamp, source, filepath):
    """Send a contextual summary to Graphiti instead of full content."""
    # Also include a snippet of the actual content for context
    content = filepath.read_text()
    
    # Build payload with summary as primary content
    payload = {
        "group_id": "clawdbot-main",
        "messages": [{
            "role_type": "system",
            "role": "FileUpdate",
            "content": summary,
            "timestamp": timestamp,
            "source_description": source,
            "metadata": {
                "file": filepath.name,
                "type": "file-change-summary",
                "lines": len(content.splitlines())
            }
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
        print(f"Error sending to Graphiti: {e}", file=sys.stderr)
        return False

def sync_file_with_summary(filepath, state):
    """Sync a file with contextual summary if it has changed."""
    current_hash = file_hash(filepath)
    stored_hash = state["file_hashes"].get(str(filepath))
    
    if current_hash == stored_hash:
        return False  # No change
    
    if not filepath.exists():
        return False
    
    new_content = filepath.read_text()
    old_content = get_cached_content(filepath)
    
    mtime = datetime.fromtimestamp(filepath.stat().st_mtime)
    timestamp = mtime.strftime("%Y-%m-%dT%H:%M:%SZ")
    
    # Generate contextual summary
    summary = generate_diff_summary(old_content, new_content, filepath.name)
    
    if not summary:
        summary = f"File updated: {filepath.name} (minor changes)"
    
    source = f"file-update:{filepath.name}"
    
    if send_summary_to_graphiti(summary, timestamp, source, filepath):
        state["file_hashes"][str(filepath)] = current_hash
        state["last_summaries"][str(filepath)] = summary[:200]
        save_cached_content(filepath, new_content)
        print(f"✓ Synced {filepath.name}: {summary[:80]}...")
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
        if sync_file_with_summary(logfile, state):
            count += 1
    return count

def main():
    # Check Graphiti
    try:
        req = urllib.request.Request(f"{GRAPHITI_URL}/healthcheck")
        urllib.request.urlopen(req, timeout=5)
    except Exception as e:
        print(f"Graphiti not available: {e}")
        sys.exit(1)
    
    state = load_state()
    synced = 0
    
    # Sync watched files
    for filepath in WATCHED_FILES:
        if filepath.exists() and sync_file_with_summary(filepath, state):
            synced += 1
    
    # Sync daily logs
    synced += sync_daily_logs(state)
    
    # Sync project files
    projects_dir = MEMORY_DIR / "projects"
    if projects_dir.exists():
        for filepath in projects_dir.glob("*.md"):
            if sync_file_with_summary(filepath, state):
                synced += 1
    
    save_state(state)
    
    if synced > 0:
        print(f"Graphiti file sync: {synced} files updated with contextual summaries")
    
    return synced

if __name__ == "__main__":
    main()
