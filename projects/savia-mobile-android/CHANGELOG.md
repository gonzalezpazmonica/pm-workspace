# Changelog — Savia Mobile Android

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.3.46] — 2026-03-10

### Fixed — One-shot mode + command pre-fill from palette

Switch from interactive (bidirectional stream-json) to one-shot mode for Claude CLI, fixing chat unresponsive bug. Add command pre-fill navigation from Commands palette to Chat.

### Fixed

- **Chat unresponsive (CRITICAL)**: Claude CLI's `--input-format stream-json` interactive mode does not work as subprocess — stdin never receives messages. Switched to one-shot mode (`-p --output-format stream-json`) in `ChatRepositoryImpl` (`interactive = false`). Each message launches a fresh CLI process with `--resume` for session continuity
- **Commands don't pre-fill chat (MAJOR)**: Tapping a command in the Commands palette navigated to Chat but ignored the command text. Root cause: `onNavigateToChat` callback discarded the `command` parameter. Fixed by adding `?command={command}` query parameter to navigation route with `Uri.encode()`
- **Duplicate chat composable**: Two separate `composable()` blocks handled `chat` and `chat?conversationId=...` routes. Merged into single route `chat?conversationId={conversationId}&command={command}` with both optional `navArgument` params
- **Sessions hardcoded route**: Sessions screen used hardcoded `"chat?conversationId=..."` string instead of `Screen.Chat.route`. Fixed to use sealed class constant

### Added

- **Command pre-fill in ChatInput**: New `commandToPreFill` parameter on `ChatScreen`, passed as `initialText` to `ChatInput`. Uses `remember(initialText)` keyed state so it reinitializes when navigation delivers a new command
- **Permission request model**: `StreamDelta.PermissionRequest` data class with `requestId`, `toolName`, `toolInput`, `description` — enables future permission dialog UI for interactive mode
- **Bridge permission endpoint**: `sendPermissionResponse()` in `SaviaBridgeService` — POST `/chat/permission` with session/request ID and allow/deny behavior
- **Bridge SSE permission_request event**: `SaviaBridgeService` now parses `permission_request` SSE events and emits `StreamDelta.PermissionRequest`
- **Bridge InteractiveSession manager**: Full bidirectional stream-json protocol implementation in `savia-bridge.py` — `InteractiveSession` class with stdin write, permission wait/resolve, session lifecycle. Includes `/chat/permission` HTTP endpoint, session cleanup, and timeout handling

### Changed

- `SaviaBridgeService.sendMessageStream()` accepts `interactive: Boolean` parameter (default `false`)
- `BridgeRequest` serialization includes `interactive` field
- `BridgeStreamEvent` extended with `request_id`, `tool_name`, `tool_input`, `description` fields
- `SaviaNavigation`: Commands callback uses `popUpTo` + `launchSingleTop` for clean stack management
- Bridge `--permission-mode bypassPermissions` set on interactive code path (currently unused)

### Updated tech stack

| Component | Version |
|-----------|---------|
| Bridge | 1.6.0 |
| version.properties | CODE=49, PATCH=46 |
| Tests | 48 unit + integration |

---

## [0.3.44] — 2026-03-09

### Fixed — Chat screen crash + crash handler

- **Fixed runtime crash**: Removed `LocalLifecycleOwner`/`DisposableEffect` from ChatScreen that caused crash on navigation. Moved app foreground tracking to `SaviaNotificationManager` via `ProcessLifecycleOwner` (stable, no Compose dependency)
- **Global crash handler**: `SaviaApp.installCrashHandler()` logs uncaught exceptions to logcat and `last_crash.log` before delegating to default handler
- **Simplified ChatViewModel**: Removed `isAppInForeground` field — notification manager now checks foreground state internally

## [0.3.42] — 2026-03-09

### Added — File browser, notifications, output persistence

- **File browser**: `FileBrowserScreen` with dual mode — directory listing (file/folder icons, size, chevron) and file viewer (code with line numbers or markdown via Markwon). Breadcrumb navigation, back handler. New `Screen.Files` route and HomeScreen "Files" quick action button
- **Bridge file API**: `listFiles()` and `readFile()` in `SaviaBridgeService` with `FileEntry`, `FileListResponse`, `FileContentResponse` data classes
- **Notification permission**: `POST_NOTIFICATIONS` declared in manifest, runtime permission request for Android 13+ (API 33) on launch via `ActivityResultContracts.RequestPermission`
- **Background notifications**: `SaviaNotificationManager` singleton sends "response complete" notification when Claude finishes while app is backgrounded. Lifecycle tracking via `ProcessLifecycleOwner`
- **Output persistence**: `SavedOutputEntity` Room table (database v2 migration) for saving Claude outputs (code, reports, snippets). `SavedOutputDao` with getAll, getByType, getByConversation, getFavorites, toggleFavorite

## [0.3.40] — 2026-03-09

### Changed — Non-blocking chat UX

- **Message queue**: users can type and send messages while Savia is responding. Messages queue (FIFO) and process sequentially. Input field stays enabled during streaming
- **Spinner on bubble**: loading indicator moved from send button to streaming message bubble (inline `CircularProgressIndicator`)
- **Pending badge**: red badge on send button shows count of queued messages waiting to be processed
- **ChatViewModel**: refactored `sendMessage()` to queue via `Channel<String>`, new `processMessage()` suspend function handles API/Bridge calls
- **ChatUiState**: added `canSendWhileStreaming` (true) and `pendingMessageCount` fields

### Fixed

- SQLCipher dependency: changed from `implementation` to `api` in data module — resolves `SupportOpenHelperFactory` import in app's DatabaseModule

## [0.3.35] — 2026-03-09

### Security — Full hardening from security audit

Remediation of all security findings affecting Savia Mobile and Bridge.

### Security

- SQLCipher enabled for Room Database with Tink AES-256-GCM passphrase (C2)
- HTTP logging restricted to `BuildConfig.DEBUG` — no Bearer tokens in production logcat (C6)
- Passphrase encoding fixed: `Base64.decode()` instead of `toByteArray(UTF_8)` (A11)
- Cleartext traffic documentation in `network_security_config.xml` (M4)

### Bridge (v1.6.0)

- Input validation regex on PUT /git-config (C3)
- PAT encrypted with Fernet instead of Base64 (C4)
- Auth required on all sensitive endpoints (C5)
- Path traversal prevention on APK download (A1)
- SSE connection limit: MAX_CONCURRENT_STREAMS=10 (A2)
- Rate limiting: 5 failed attempts / 60s per IP (A3)
- Security headers: X-Content-Type-Options, X-Frame-Options, HSTS (A4)
- CORS restricted to local network origins (A5)
- Body size limit 1MB on POST (A6)
- Log sanitization: Bearer tokens masked (A7)
- Systemd hardening: PrivateTmp, ProtectSystem, NoNewPrivileges (A10)
- YAML frontmatter injection prevention (M1)
- Session ID validation UUID/alphanumeric (M2)
- Minimum TLS cipher suite v1.2 (M3)

### Updated tech stack

| Component | Version |
|-----------|---------|
| Bridge | 1.6.0 |
| version.properties | CODE=38, PATCH=35 |
| Tests | 48 unit + integration |

---

## [0.3.34] — 2026-03-09

### Second release — Full Dashboard + Bridge REST (Sprint 2026-04)

Full release with functional dashboard, chat fixes, robust auto-update, and integrated test pipeline.

### Added

**Dashboard (Home)**
- Project selector with filtered search (bordered card + dropdown)
- Sprint selector with filtered search
- Sprint progress bar with story points (completed/total)
- Metrics: blocked items + daily hours
- My Tasks (first 3 assigned tasks)
- Recent Activity feed
- Quick Actions: "See Board" and "Approvals"
- FAB for quick capture
- Project selection persists across reloads (local storage)

**Secondary screens (REST)**
- Kanban board via `GET /kanban?project=X`
- Time log via `GET /timelog` + `POST /timelog`
- Approvals via `GET /approvals?project=X`
- Capture via `POST /capture`
- Git Config (read/write)
- Team Management (CRUD members)
- Company Profile (read/write)

**Chat**
- Fixed duplicate messages bug (Room as single source of truth)
- Fixed CLAUDECODE error in nested sessions (Bridge strips env var)
- Slash command autocomplete (8 commands)

**Profile and updates**
- APK download progress bar (LinearProgressIndicator + %)
- "Check updates" button after finding available version
- Download progress also in Settings (SettingsViewModel now tracks progress)
- State reset on update check (both screens)

**Build & CI**
- Version auto-increment at Gradle configuration phase (fixes version lag)
- Unit tests as mandatory gate before publishing APK to Bridge
- `assembleDebug` runs `testDebugUnitTest` automatically
- `publishToBridge` + `publishToDist` only if tests pass

**Tests**
- HomeViewModelTest: 5 tests (dashboard load, project selection, persistence, errors)
- Total: 48 unit tests passing
- Spec coverage: Chat, Home, Settings, Profile, Navigation

**Documentation**
- CLAUDE.md created for savia-mobile-android (project constants, sprint, metrics)
- Project visible in pm-workspace dashboard

### Fixed

- Settings > Profile did not navigate (conditional onClick → always navigates)
- Chat duplicated messages (ViewModel + Room both emitting → Room as SSoT)
- Chat unresponsive due to CLAUDECODE env var inherited in subprocess
- APK version always one behind (increment at execution → configuration)
- Project selector did not persist selection (used Bridge default → local selection)
- Bridge endpoints 404 due to stale process (required restart)

### Bridge (v1.5.0)

- `POST /timelog` endpoint for time logging
- Fix: CLAUDECODE env var removed from Claude CLI subprocess
- Endpoints verified: `/kanban`, `/timelog`, `/approvals`, `/capture`, `/profile`, `/dashboard`

### Updated tech stack

| Component | Version |
|-----------|---------|
| Bridge | 1.5.0 |
| version.properties | CODE=37, PATCH=34 |
| Tests | 48 unit + integration |

---

## [0.1.0] — 2026-03-08

### First release — MVP Foundation (Phase 0)

Initial release of Savia Mobile: native Android app connecting to pm-workspace
via Savia Bridge, an HTTPS/SSE server wrapping Claude Code CLI.

### Added

**Android App**
- Conversational chat with real-time SSE streaming
- Clean Architecture with 3 modules: `:app`, `:domain`, `:data`
- Jetpack Compose + Material 3 with custom violet theme (#6B4C9A)
- Bottom navigation: Chat, Sessions, Settings
- Conversation persistence with Room Database
- AES-256-GCM encryption with Google Tink + Android Keystore
- Dual-backend: Savia Bridge (primary) + Anthropic API (fallback)
- Auto-titling of conversations (first 50 characters of message)
- Restore last active session on app launch
- Dashboard with quick actions and workspace status
- Settings screen with Bridge connection status
- Google authentication via Credential Manager
- Bilingual support (Spanish and English)
- Dependency injection with Hilt 2.56.2
- Splash screen with Savia logo
- Adaptive icons (mdpi to xxxhdpi)

**Savia Bridge (Python)**
- HTTPS server on port 8922 with self-signed TLS
- SSE streaming (Server-Sent Events) from Claude Code CLI
- Session management with `--session-id` and `--resume`
- Bearer token authentication (auto-generated)
- Health check: `GET /health`
- Session listing: `GET /sessions`
- HTTP install server on port 8080
- APK download page with logo, version, and instructions
- systemd service (`savia-bridge.service`)
- File logging (`bridge.log`, `chat.log`)
- Version 1.2.0

**Documentation**
- Full KDoc on all 39 Kotlin source files
- Python docstrings on all bridge classes/functions
- 8 specs rewritten (PRODUCT-SPEC, TECHNICAL-DESIGN, BACKLOG, IMPLEMENTATION-PLAN, ARCHITECTURE-DECISIONS, STACK-ANALYSIS, CI-CD-PIPELINES, MARKET-ANALYSIS)
- 3 new guides: ARCHITECTURE.md, SETUP.md, BRIDGE-GUIDE.md
- API Reference with all bridge endpoints
- Complete README with stack, setup, CI/CD, and troubleshooting

**Infrastructure**
- CI/CD with GitHub Actions (`android-ci.yml`)
- Updated installers (`install.sh`, `install.ps1`) with Bridge setup
- ProGuard/R8 for release builds
- Gradle with Version Catalog (`libs.versions.toml`)

### Tech stack

| Component | Version |
|-----------|---------|
| Kotlin | 2.1.0 |
| AGP | 8.13.2 |
| Compose BOM | 2024.12.01 |
| Material 3 | 1.3.1 |
| Hilt | 2.56.2 |
| Room | 2.7.0 |
| OkHttp | 4.12.0 |
| Retrofit | 2.11.0 |
| Tink | 1.10.0 |
| KSP | 2.1.0-1.0.29 |
| Coroutines | 1.9.0 |
| Python | 3.x (stdlib) |

### Stats

- **88 files** in the commit
- **12,954 lines** added
- **39 Kotlin files** documented with KDoc
- **8 specs** rewritten
- **3 architecture guides** created
- **157 tests** passing
- **Target**: Android 15 (API 35), **Min**: Android 8.0 (API 26)

---

## Roadmap

- **v0.4.0** — Widgets, smart notifications
- **v1.0.0** — Public beta on Google Play

---

[0.3.46]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.44-savia-mobile...v0.3.46-savia-mobile
[0.3.44]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.35-savia-mobile...v0.3.44-savia-mobile
[0.3.35]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.34-savia-mobile...v0.3.35-savia-mobile
[0.3.34]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0-savia-mobile...v0.3.34-savia-mobile
[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v0.1.0-savia-mobile
