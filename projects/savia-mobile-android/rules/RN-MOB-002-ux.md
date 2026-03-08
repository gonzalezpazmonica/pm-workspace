# RN-MOB-002: UX Rules

## RN-MOB-002-01: Response Time
Chat responses MUST show typing indicator within 500ms.
First token MUST appear within 2 seconds of API response start.
Streaming display MUST use word-by-word rendering.

## RN-MOB-002-02: Offline Behavior
App MUST clearly indicate offline status with banner.
Cached data MUST be accessible without network.
Queued actions MUST show pending indicator.
On reconnect, queued actions auto-execute in FIFO order.

## RN-MOB-002-03: Error Handling
Network errors MUST show retry button, not crash.
API rate limits MUST show wait time and queue request.
SSH disconnects MUST auto-reconnect up to 3 times.
All errors MUST be human-readable (no stack traces to user).

## RN-MOB-002-04: Accessibility
All interactive elements MUST have contentDescription.
Minimum touch target 48dp x 48dp.
Color contrast ratio minimum 4.5:1 for text.
Support dynamic font scaling up to 200%.

## RN-MOB-002-05: Navigation
Bottom navigation with 3 tabs: Chat, Dashboard, Settings.
Back button MUST follow Android system conventions.
Deep links for: savia://chat, savia://dashboard, savia://health.

## RN-MOB-002-06: Input
Support voice input via Android speech recognition.
Support keyboard shortcuts on physical keyboards.
Auto-suggest common PM commands (sprint status, health check).

## RN-MOB-002-07: Theming
Support Material You dynamic color (Android 12+).
Fallback to Savia brand colors (primary: #2D5F2D, accent: #8BC34A).
Dark mode MUST follow system setting by default.
Override option in Settings.

## RN-MOB-002-08: Localization
All user-facing strings in res/values/strings.xml.
Spanish (default) and English at launch.
Date/time formatting per device locale.
No hardcoded strings in Kotlin code.
