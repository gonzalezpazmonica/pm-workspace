# Session Recording Domain

## Overview
The session recording domain handles capture, storage, replay, and export of agent session activities.

## Core Concepts

### Session
A bounded period of agent activity with a unique session ID. Contains all recorded events during that period.

### Event
An atomic action within a session (command execution, file operation, API call, decision, note).

### Recording
The complete JSONL file containing all events for a session, stored in `data/recordings/{session-id}.jsonl`.

### Timeline
The chronological view of all events in a session during replay.

## Data Model

```jsonl
{"type": "command", "timestamp": "2026-03-07T10:30:15Z", "actor": "claude-agent", "content": {"command": "git status", "output": "..."}}
{"type": "file-modification", "timestamp": "2026-03-07T10:30:20Z", "actor": "claude-agent", "content": {"action": "create", "path": "file.md"}}
{"type": "decision", "timestamp": "2026-03-07T10:30:25Z", "actor": "claude-agent", "content": {"reasoning": "...", "choice": "..."}}
```

## Storage
- Location: `data/recordings/`
- Format: JSONL (one event per line)
- Naming: `{session-id}.jsonl`
- Lifecycle: Created on `/record-start`, appended on each action, finalized on `/record-stop`
