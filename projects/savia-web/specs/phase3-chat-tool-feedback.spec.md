---
id: "phase3-chat-tool-feedback"
title: "Chat Tool Feedback — Visual Progress While Savia Works"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Chat Tool Feedback

## Problema

When Savia uses tools (Read, Bash, Task, Grep...) to answer a question,
the user sees no feedback for 30-80 seconds. The assistant bubble shows
the initial text ("Voy a revisar...") then goes silent until the final
response arrives. The `tool_use` SSE events are received but displayed
only as a tiny "Using tool: X" indicator that's easy to miss.

## Solución

Show a visible, animated activity feed inside the assistant bubble while
Savia works. Each tool_use event adds a line showing what Savia is doing.

## Requisitos Funcionales

### RF-01: Tool Activity Feed in Bubble

When the assistant bubble is streaming and tool_use events arrive:
- Show an animated activity list below the initial text
- Each tool shows: icon + tool name + brief description
- Format: "📂 Reading proyecto-alpha/CLAUDE.md" or "🔍 Searching files..."
- Auto-scroll to keep latest activity visible
- Fade out when final text response arrives

### RF-02: Tool Name to Human Label

| Tool | Display |
|------|---------|
| Read | 📄 Reading {file} |
| Bash | ⚙️ Running command... |
| Grep | 🔍 Searching... |
| Glob | 📂 Finding files... |
| Task | 🤖 Delegating to agent... |
| Write | ✏️ Writing file... |
| Edit | ✏️ Editing file... |
| WebFetch | 🌐 Fetching web... |
| WebSearch | 🌐 Searching web... |
| Other | 🔧 Working... |

### RF-03: Animated Indicator

- Pulsing dot or spinner next to the latest tool activity
- Shows elapsed time: "Working... (12s)"
- Replaces the current `.tool-indicator` which is outside the bubble

### RF-04: Final Response Replaces Activity

- When the final text arrives (SSE text event after tool_use events):
  the activity feed collapses and the full response renders
- The tool activity is NOT preserved in message history (ephemeral)

## Criterios de Aceptacion

- [ ] Tool_use events show visible activity inside assistant bubble
- [ ] Each tool shows human-readable label
- [ ] Activity auto-scrolls as new tools are used
- [ ] Final response replaces activity feed
- [ ] User has clear indication Savia is working (not frozen)
- [ ] Works with 30+ consecutive tool_use events (proyecto-alpha case)
