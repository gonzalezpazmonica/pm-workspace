# RN-MOB-004: Data & Privacy Rules

## RN-MOB-004-01: Data Minimization
Only collect data strictly necessary for app functionality.
No analytics tracking without explicit user consent.
No user profiling or behavioral tracking.

## RN-MOB-004-02: Conversation Privacy
Conversations stored locally by default.
Cloud sync only with explicit opt-in.
User can delete all local data at any time.
Export conversations as markdown.

## RN-MOB-004-03: API Communication
Only send to Anthropic API: user message + system prompt + conversation context.
Never send: device ID, location, contacts, or other personal data.
API calls MUST use minimum required scope.

## RN-MOB-004-04: GDPR Compliance
Privacy policy accessible from app and Play Store listing.
Data deletion request mechanism.
Data export in machine-readable format.
Consent management for optional features.

## RN-MOB-004-05: Cache Management
Auto-purge cached data older than 30 days.
User configurable cache retention period.
Clear cache option in Settings.
Maximum cache size: 100MB.

## RN-MOB-004-06: SSH Session Data
SSH session logs MUST NOT be persisted.
Connection metadata (host, port) stored encrypted.
SSH key NEVER leaves device (no cloud backup of keys).
