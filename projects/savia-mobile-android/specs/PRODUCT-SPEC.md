# Savia Mobile — Product Specification

## 1. Product Overview

**Name**: Savia Mobile
**Platform**: Android (Google Play Store)
**Target Users**: Project managers, team leads, product owners, engineering managers
**Pricing**: Free tier (5 queries/day) + Pro ($9.99/mo, unlimited, own API key)

## 2. User Personas

### P1: Mónica (Primary)
- **Role**: Senior PM / Technical Lead
- **Need**: Manage Agile projects from anywhere
- **Pain**: Current SSH+Termux setup is fragile, non-portable
- **Goal**: Quick sprint checks, PBI reviews, risk alerts from her phone

### P2: Carlos (Secondary)
- **Role**: Engineering Manager
- **Need**: Team health overview, blocker resolution
- **Pain**: Can only check project status from laptop
- **Goal**: Morning standup prep, capacity alerts

### P3: Elena (Tertiary)
- **Role**: Executive / CTO
- **Need**: Portfolio health, audit reports
- **Pain**: Waiting for manual reports
- **Goal**: One-tap executive dashboard

## 3. Core Features (MVP)

### F1: Chat Interface
- Conversational UI with Savia personality
- Markdown rendering for responses
- Code block syntax highlighting
- Voice input support (Android speech-to-text)
- Conversation history (local + cloud sync)

### F2: Quick Actions Dashboard
- **Sprint Status**: Current sprint progress, burndown trend
- **Health Check**: Workspace health (6 dimensions)
- **Risk Alert**: Top 3 risks with scoring
- **PBI Queue**: Upcoming items with priority
- **Audit Report**: Executive audit summary

### F3: Connection Manager
- **API Mode**: Enter Anthropic API key, direct Claude API calls
- **SSH Mode**: Configure host/port/key for tunnel to pm-workspace
- **Auto-detect**: Try API first, fallback to SSH
- **Status indicator**: Connection health in status bar

### F4: Offline Mode
- Cache last 50 conversations
- Cache last workspace health snapshot
- Cache last sprint status
- Queue commands for when online

### F5: Notifications
- Sprint deadline approaching (configurable)
- Health score dropped below threshold
- New risk detected
- Build/CI failure alert

## 4. Non-Functional Requirements

### NFR1: Performance
- App cold start < 3 seconds
- API response display < 2 seconds (network permitting)
- Smooth 60fps scrolling on mid-range devices

### NFR2: Security
- API keys stored in Android Keystore (hardware-backed)
- SSH keys stored encrypted
- No plaintext credentials in SharedPreferences
- Certificate pinning for Anthropic API
- Biometric lock option

### NFR3: Accessibility
- WCAG 2.1 AA compliance
- TalkBack support
- Minimum touch target 48dp
- High contrast mode
- Font size: system setting respected

### NFR4: Localization
- Spanish (primary)
- English (secondary)
- RTL-ready architecture for future languages

### NFR5: Compatibility
- Android 10+ (API 29+)
- Phone and tablet layouts
- Landscape + portrait
- Foldable device support (WindowManager)

## 5. Technical Architecture

```
┌─────────────────────────────────────────┐
│              Savia Mobile               │
│                                         │
│  ┌──────────┐  ┌──────────┐  ┌───────┐ │
│  │   Chat   │  │Dashboard │  │Settings│ │
│  │   Screen │  │  Screen  │  │ Screen │ │
│  └────┬─────┘  └────┬─────┘  └───┬───┘ │
│       │              │            │     │
│  ┌────┴──────────────┴────────────┴───┐ │
│  │          ViewModel Layer           │ │
│  └────────────────┬───────────────────┘ │
│                   │                     │
│  ┌────────────────┴───────────────────┐ │
│  │         Repository Layer           │ │
│  │  ┌──────────┐  ┌────────────────┐  │ │
│  │  │ API Repo │  │  SSH Repo      │  │ │
│  │  │ (Claude) │  │ (pm-workspace) │  │ │
│  │  └──────────┘  └────────────────┘  │ │
│  └────────────────┬───────────────────┘ │
│                   │                     │
│  ┌────────────────┴───────────────────┐ │
│  │        Local Storage (Room)        │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
           │                    │
           ▼                    ▼
   ┌──────────────┐   ┌─────────────────┐
   │ Anthropic API│   │  User's PC      │
   │ (claude.ai)  │   │  (pm-workspace) │
   └──────────────┘   └─────────────────┘
```

## 6. Data Model

### Conversation
- id: UUID
- title: String
- messages: List<Message>
- createdAt: Timestamp
- updatedAt: Timestamp

### Message
- id: UUID
- conversationId: UUID
- role: "user" | "assistant"
- content: String (markdown)
- timestamp: Timestamp

### WorkspaceSnapshot
- id: UUID
- healthScore: Int
- trustScore: Int
- dimensions: JSON
- capturedAt: Timestamp

### ConnectionConfig
- type: "api" | "ssh" | "hybrid"
- apiKey: EncryptedString
- sshHost: String
- sshPort: Int
- sshKey: EncryptedString

## 7. Release Plan

| Version | Milestone | Scope |
|---------|-----------|-------|
| 0.1.0 | Alpha | Chat UI + API mode |
| 0.2.0 | Alpha | Quick actions + offline cache |
| 0.3.0 | Beta | SSH tunnel + connection manager |
| 0.5.0 | Beta | Notifications + widgets |
| 1.0.0 | Release | Play Store launch |
| 1.1.0 | Post-launch | Wear OS companion |
