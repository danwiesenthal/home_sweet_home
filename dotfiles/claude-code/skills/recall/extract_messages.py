#!/usr/bin/env python3
"""Extract genuine human messages from Claude Code conversation JSONL files.

Reads session JSONL files, filters out system-generated noise, and outputs
only what the human user actually typed/dictated. Designed to be run by a
subagent so the orchestrator can understand what the user has been saying
without the user having to repeat themselves.
"""

import json
import os
import sys
import re
import argparse
from pathlib import Path
from datetime import datetime


# Prefixes/patterns that indicate system-generated "user" messages, not real human input
NOISE_PREFIXES = [
    '<local-command-caveat>',
    '<local-command-stdout>',
    '<bash-input>',
    '<bash-stdout>',
    '<bash-stderr>',
    '<command-name>',
    '<task-notification>',
]

# Patterns anywhere in the message that indicate it's not genuine human input
NOISE_PATTERNS = [
    r'^This session is being continued from a previous conversation',
]


def get_project_dir(cwd=None):
    """Find the Claude project directory for the given working directory."""
    cwd = cwd or os.getcwd()
    projects_dir = Path.home() / '.claude' / 'projects'
    if not projects_dir.exists():
        return None

    # Claude Code sanitizes paths: / and _ become -, leading / kept as leading -
    # Try multiple sanitization strategies since the exact algorithm may vary
    candidates = set()
    # Strategy 1: replace / with -
    candidates.add(cwd.replace('/', '-'))
    # Strategy 2: replace / and _ with -
    candidates.add(re.sub(r'[/_]', '-', cwd))
    # Strategy 3: also try without leading dash
    for c in list(candidates):
        if c.startswith('-'):
            candidates.add(c[1:])

    for candidate in candidates:
        path = projects_dir / candidate
        if path.exists():
            return path

    # Fallback: scan project dirs for a partial match on the last path component
    basename = Path(cwd).name
    for d in projects_dir.iterdir():
        if d.is_dir() and basename.replace('_', '-') in d.name:
            return d

    return None


def is_genuine_human_message(content):
    """Return True only if this is actual human input, not system noise."""
    if not isinstance(content, str):
        return False

    stripped = content.strip()
    if len(stripped) < 15:
        return False

    # Check noise prefixes
    for prefix in NOISE_PREFIXES:
        if stripped.startswith(prefix):
            return False

    # Check noise patterns
    for pattern in NOISE_PATTERNS:
        if re.match(pattern, stripped):
            return False

    return True


def clean_message(content):
    """Strip system-reminder tags and other injected metadata from genuine messages."""
    # Remove <system-reminder>...</system-reminder> blocks
    cleaned = re.sub(r'<system-reminder>.*?</system-reminder>', '', content, flags=re.DOTALL)
    # Remove leading/trailing whitespace left behind
    return cleaned.strip()


def extract_from_session(jsonl_path):
    """Extract genuine human messages from a single session JSONL file."""
    messages = []
    try:
        with open(jsonl_path) as f:
            for line in f:
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                if obj.get('type') != 'user':
                    continue

                msg = obj.get('message', {})
                content = msg.get('content', '')
                timestamp = obj.get('timestamp', '')

                if is_genuine_human_message(content):
                    cleaned = clean_message(content)
                    if len(cleaned) >= 15:
                        messages.append({
                            'timestamp': timestamp,
                            'content': cleaned,
                        })
    except Exception as e:
        print(f"Error reading {jsonl_path}: {e}", file=sys.stderr)

    return messages


def main():
    parser = argparse.ArgumentParser(description='Extract human messages from Claude Code sessions')
    parser.add_argument('--sessions', type=int, default=3,
                        help='Number of recent sessions to read (default: 3)')
    parser.add_argument('--skip-session', type=str, default=None,
                        help='Session ID to skip (typically the current session)')
    parser.add_argument('--project-dir', type=str, default=None,
                        help='Override project directory path')
    parser.add_argument('--max-chars', type=int, default=0,
                        help='Max chars per message before truncation (0 = no limit)')
    parser.add_argument('--truncate', type=int, default=0,
                        help='Alias for --max-chars')
    args = parser.parse_args()

    if args.project_dir:
        project_dir = Path(args.project_dir)
    else:
        project_dir = get_project_dir()

    if not project_dir or not project_dir.exists():
        print(json.dumps({"error": f"Project directory not found. CWD: {os.getcwd()}"}))
        sys.exit(1)

    # Find top-level session JSONL files (not subagent files)
    jsonl_files = sorted(
        [f for f in project_dir.glob('*.jsonl')],
        key=lambda f: f.stat().st_mtime,
        reverse=True  # most recent first
    )

    sessions_processed = 0
    for jsonl_file in jsonl_files:
        if sessions_processed >= args.sessions:
            break

        session_id = jsonl_file.stem
        if args.skip_session and session_id == args.skip_session:
            continue

        messages = extract_from_session(jsonl_file)
        if not messages:
            continue

        sessions_processed += 1
        modified = datetime.fromtimestamp(jsonl_file.stat().st_mtime).strftime('%Y-%m-%d %H:%M')

        print(f"\n{'=' * 60}")
        print(f"SESSION: {session_id}")
        print(f"Last modified: {modified}")
        print(f"Human messages: {len(messages)}")
        print(f"{'=' * 60}")

        for msg in messages:
            ts = msg['timestamp'][:19] if msg['timestamp'] else 'unknown'
            content = msg['content']
            max_chars = args.max_chars or args.truncate
            if max_chars > 0 and len(content) > max_chars:
                content = content[:max_chars] + f"\n[... truncated, {len(content)} chars total]"
            print(f"\n[{ts}]")
            print(content)


if __name__ == '__main__':
    main()
