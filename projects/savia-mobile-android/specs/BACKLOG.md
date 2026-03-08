# Savia Mobile — Product Backlog

## Epic 1: Foundation (v0.1.0)

### US-001: Project Setup
**As a** developer **I want** the Android project initialized with the correct architecture **so that** I can start building features on a solid foundation.

**Acceptance Criteria:**
- Kotlin + Jetpack Compose project created
- Clean Architecture modules: app, domain, data, presentation
- Hilt dependency injection configured
- Room database initialized with migrations
- Build variants: debug, staging, release
- CI/CD with GitHub Actions (lint, test, build)
- Minimum SDK 29 (Android 10)

### US-002: Anthropic API Client
**As a** user **I want** the app to connect to Claude API **so that** I can chat with Savia.

**Acceptance Criteria:**
- Ktor HTTP client configured for api.anthropic.com
- Streaming support for Messages API
- API key stored in EncryptedSharedPreferences
- Error handling: rate limits, network errors, auth errors
- Automatic retry with exponential backoff

### US-003: Chat Screen
**As a** user **I want** a chat interface **so that** I can have conversations with Savia.

**Acceptance Criteria:**
- Message bubbles with user/assistant distinction
- Markdown rendering (headers, bold, code blocks, lists)
- Typing indicator during API calls
- Streaming word-by-word display
- Scroll to bottom on new message
- Copy message to clipboard (long press)
- Voice input button (Android STT)

### US-004: Savia System Prompt
**As a** user **I want** Savia to have her personality and PM expertise **so that** responses are contextual and professional.

**Acceptance Criteria:**
- System prompt loaded from bundled savia-identity.md
- PM-specific instructions for sprint, risk, PBI topics
- Bilingual capability (respond in user's language)
- Workspace context when connected via SSH

## Epic 2: Dashboard (v0.2.0)

### US-005: Health Dashboard
**As a** PM **I want** to see workspace health at a glance **so that** I can spot issues quickly.

**Acceptance Criteria:**
- 6-dimension radar chart (Compose Canvas)
- Overall score with grade badge
- Trend arrows (up/down/stable vs last snapshot)
- Pull-to-refresh
- Works offline with cached data

### US-006: Quick Actions
**As a** PM **I want** one-tap actions for common queries **so that** I save time.

**Acceptance Criteria:**
- Grid of action cards: Sprint Status, Risk Score, PBI Queue, Health, Audit
- Each opens chat with pre-filled query
- Customizable: reorder, show/hide actions
- Action badges with latest metric value

### US-007: Offline Cache
**As a** user **I want** to access recent data offline **so that** I'm not blocked without internet.

**Acceptance Criteria:**
- Last 50 conversations cached in Room
- Last workspace health snapshot cached
- Visual indicator for cached vs live data
- Auto-refresh when connection restored

## Epic 3: Connection Manager (v0.3.0)

### US-008: SSH Tunnel
**As a** power user **I want** to connect to my pc's pm-workspace **so that** I can run full commands.

**Acceptance Criteria:**
- SSH key pair generation (Ed25519)
- Manual host/port configuration
- Key-based authentication (no password)
- Connection status indicator
- Auto-reconnect on disconnect (3 retries)
- Execute commands and stream output

### US-009: Connection Profiles
**As a** user **I want** to save multiple connection profiles **so that** I can switch between workspaces.

**Acceptance Criteria:**
- Add/edit/delete connection profiles
- Default profile auto-connects on launch
- Profile types: API-only, SSH-only, Hybrid
- Connection test button

### US-010: Hybrid Mode
**As a** user **I want** the app to automatically choose the best connection **so that** it just works.

**Acceptance Criteria:**
- Try SSH first if configured and host reachable
- Fallback to API mode if SSH fails
- Indicator showing current mode
- Seamless switch without losing conversation

## Epic 4: Notifications & Widgets (v0.5.0)

### US-011: Push Notifications
**As a** PM **I want** to receive alerts **so that** I'm aware of important changes.

**Acceptance Criteria:**
- Configurable notification channels
- Sprint deadline alerts (24h, 4h before)
- Health score degradation alert
- CI/CD failure notification
- Notification grouping and quiet hours

### US-012: Home Screen Widget
**As a** PM **I want** a widget showing key metrics **so that** I don't even need to open the app.

**Acceptance Criteria:**
- Glance widget: health score + sprint progress
- Tap to open relevant screen
- Auto-refresh every 30 minutes
- Responsive sizing (2x2, 4x2, 4x4)

## Epic 5: Polish & Launch (v1.0.0)

### US-013: Onboarding Flow
**As a** new user **I want** a guided setup **so that** I can start using the app quickly.

**Acceptance Criteria:**
- 3-screen onboarding (welcome, connection setup, first query)
- Skip option
- Help tooltips on key UI elements
- Link to documentation

### US-014: Settings Screen
**As a** user **I want** to configure the app **so that** it works the way I prefer.

**Acceptance Criteria:**
- Theme: light/dark/system
- Language: ES/EN
- Notifications: toggle per type
- Connection: manage profiles
- Data: clear cache, export conversations
- About: version, licenses, privacy policy

### US-015: Play Store Release
**As a** PM **I want** the app available on Play Store **so that** anyone can download it.

**Acceptance Criteria:**
- All store listing assets prepared
- Privacy policy and TOS published
- Closed beta with 100 users completed
- Crash rate < 1%, ANR < 0.5%
- Staged rollout plan executed
