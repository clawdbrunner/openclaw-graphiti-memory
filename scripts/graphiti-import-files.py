#!/usr/bin/env python3
"""
Import file-based memory into Graphiti with temporal context.
Uses filenames (daily logs) or file mtime for timestamps.
"""

import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path
import urllib.request

GRAPHITI_URL = os.environ.get("GRAPHITI_URL", "http://localhost:8001")
MEMORY_DIR = Path.home() / "clawd/memory"
CLAWD_DIR = Path.home() / "clawd"

def send_to_graphiti(group_id, role_type, role, content, timestamp, source_desc=""):
    """Send content to Graphiti."""
    # Truncate long content
    if len(content) > 3000:
        content = content[:3000] + "\n[...truncated]"
    
    payload = {
        "group_id": group_id,
        "messages": [{
            "role_type": role_type,
            "role": role,
            "content": content,
            "timestamp": timestamp,
            "source_description": source_desc
        }]
    }
    
    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            f"{GRAPHITI_URL}/messages",
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status in (200, 202)
    except Exception as e:
        print(f"  Error: {e}", file=sys.stderr)
        return False

def parse_daily_log(filepath):
    """Parse a daily log file and extract sections."""
    content = filepath.read_text()
    
    # Get date from filename (YYYY-MM-DD.md)
    date_match = re.search(r'(\d{4}-\d{2}-\d{2})', filepath.name)
    if not date_match:
        return []
    
    log_date = date_match.group(1)
    timestamp = f"{log_date}T12:00:00Z"  # Noon on that day
    
    # Split by ## headers to get sections
    sections = re.split(r'\n##\s+', content)
    
    results = []
    for section in sections:
        if not section.strip():
            continue
        
        # Get section title and content
        lines = section.strip().split('\n')
        title = lines[0].strip('# ')
        body = '\n'.join(lines[1:]).strip()
        
        if body and len(body) > 20:
            # Try to extract time from section title (e.g., "Setup (10:30 AST)")
            time_match = re.search(r'\((\d{1,2}):(\d{2})', title)
            if time_match:
                hour, minute = time_match.groups()
                timestamp = f"{log_date}T{hour.zfill(2)}:{minute}:00Z"
            
            results.append({
                "title": title,
                "content": f"Daily log {log_date} - {title}:\n{body}",
                "timestamp": timestamp,
                "source": str(filepath)
            })
    
    return results

def parse_project_doc(filepath):
    """Parse a project doc, using file mtime for timestamp."""
    content = filepath.read_text()
    mtime = datetime.fromtimestamp(filepath.stat().st_mtime)
    timestamp = mtime.strftime("%Y-%m-%dT%H:%M:%SZ")
    
    # Get title from first # header or filename
    title_match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    title = title_match.group(1) if title_match else filepath.stem
    
    # Extract key points (look for bullet points, decisions, etc.)
    # For now, just send the first ~2000 chars as context
    summary = content[:2000]
    if len(content) > 2000:
        summary += "\n[...see full file]"
    
    return {
        "title": title,
        "content": f"Project doc '{title}' (last updated {mtime.strftime('%Y-%m-%d')}):\n{summary}",
        "timestamp": timestamp,
        "source": str(filepath)
    }

def import_daily_logs():
    """Import all daily logs."""
    logs_dir = MEMORY_DIR / "logs"
    if not logs_dir.exists():
        return 0
    
    count = 0
    for logfile in sorted(logs_dir.glob("*.md")):
        print(f"Processing {logfile.name}...")
        sections = parse_daily_log(logfile)
        
        for section in sections:
            if send_to_graphiti(
                "clawdbot-main",
                "system",
                "DailyLog",
                section["content"],
                section["timestamp"],
                f"daily-log:{logfile.name}"
            ):
                count += 1
                print(f"  ✓ {section['title']}")
            else:
                print(f"  ✗ {section['title']}")
            time.sleep(0.5)
    
    return count

def import_project_docs():
    """Import project documentation."""
    projects_dir = MEMORY_DIR / "projects"
    if not projects_dir.exists():
        return 0
    
    count = 0
    for docfile in sorted(projects_dir.glob("*.md")):
        print(f"Processing {docfile.name}...")
        doc = parse_project_doc(docfile)
        
        if send_to_graphiti(
            "clawdbot-main",
            "system",
            "ProjectDoc",
            doc["content"],
            doc["timestamp"],
            f"project-doc:{docfile.name}"
        ):
            count += 1
            print(f"  ✓ {doc['title']}")
        else:
            print(f"  ✗ {doc['title']}")
        time.sleep(0.5)
    
    return count

def import_identity_files():
    """Import core identity files."""
    files = [
        (CLAWD_DIR / "MEMORY.md", "LongTermMemory"),
        (CLAWD_DIR / "IDENTITY.md", "Identity"),
        (CLAWD_DIR / "USER.md", "UserProfile"),
    ]
    
    count = 0
    for filepath, role in files:
        if not filepath.exists():
            continue
        
        print(f"Processing {filepath.name}...")
        content = filepath.read_text()
        mtime = datetime.fromtimestamp(filepath.stat().st_mtime)
        timestamp = mtime.strftime("%Y-%m-%dT%H:%M:%SZ")
        
        if send_to_graphiti(
            "clawdbot-main",
            "system",
            role,
            f"Core file {filepath.name}:\n{content[:3000]}",
            timestamp,
            f"core:{filepath.name}"
        ):
            count += 1
            print(f"  ✓ {filepath.name}")
        else:
            print(f"  ✗ {filepath.name}")
        time.sleep(0.5)
    
    return count

def main():
    print("=== Graphiti File Import ===\n")
    
    # Check Graphiti availability
    try:
        req = urllib.request.Request(f"{GRAPHITI_URL}/healthcheck")
        urllib.request.urlopen(req, timeout=5)
    except:
        print("Error: Graphiti not available")
        sys.exit(1)
    
    total = 0
    
    print("\n--- Daily Logs ---")
    total += import_daily_logs()
    
    print("\n--- Project Docs ---")
    total += import_project_docs()
    
    print("\n--- Identity Files ---")
    total += import_identity_files()
    
    print(f"\n=== Done: {total} items imported ===")

if __name__ == "__main__":
    main()
