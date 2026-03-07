# Session Recording Skill

## Name
session-recording

## Description
Record and replay agent sessions for auditing and documentation. Captures all actions performed during a session and enables comprehensive replay and export capabilities.

## What Gets Recorded
- **Commands executed**: CLI commands with arguments and outputs
- **Files modified**: Create, read, update, delete operations
- **API calls made**: External service interactions and responses
- **Decisions taken**: Agent reasoning and choices
- **Agent notes generated**: Observations and insights
- **Timestamps**: Precise timing for all events

## Storage Format
Storage location: `data/recordings/{session-id}.jsonl`

Each recording is a JSONL (JSON Lines) file with one event per line. Each event contains:
- `type`: event category (command, file-modification, api-call, decision, note, etc.)
- `timestamp`: ISO 8601 format
- `actor`: agent or system component
- `content`: event details and metadata

## Replay
The replay function reads a recording file and displays a chronological timeline of all actions, showing:
- Event timestamps
- Action descriptions
- Actor information
- Relevant content details

## Export
Recordings can be exported as markdown reports from the JSONL format, creating human-readable documentation suitable for distribution and review.

## Use Cases

### 1. Compliance Audit
Record sensitive operations for compliance verification and regulatory requirements. Create audit trails with full action history.

### 2. Onboarding Training
Record exemplary agent sessions to use as training material. New team members can replay sessions to understand workflows and decision patterns.

### 3. Postmortem Analysis
When issues occur, replay the recording to understand exactly what happened, identify failure points, and improve processes.

### 4. Documentation of Complex Operations
Automatically generate documentation by recording and exporting sessions of complex multi-step operations.
