# RN-MOB-003: Architecture Rules

## RN-MOB-003-01: Project Structure
Follow Clean Architecture with 3 layers: presentation (UI), domain (business logic), data (repositories).
Each layer in its own Gradle module for build isolation.

## RN-MOB-003-02: Dependency Injection
Use Hilt (Dagger) for all dependency injection.
No manual instantiation of ViewModels, Repositories, or UseCases.

## RN-MOB-003-03: State Management
Use Kotlin StateFlow for UI state.
Single source of truth per screen via ViewModel.
No mutable state exposed from ViewModel.

## RN-MOB-003-04: Networking
Use Ktor for HTTP client (Claude API).
Use JSch for SSH connections.
All network calls MUST be on IO dispatcher.
Implement exponential backoff for retries.

## RN-MOB-003-05: Persistence
Use Room for structured data (conversations, snapshots).
Use DataStore for preferences.
Use EncryptedSharedPreferences for secrets.
All DB operations MUST be on IO dispatcher.

## RN-MOB-003-06: Testing
Unit tests for all UseCases (minimum 80% coverage).
UI tests with Compose Testing for all screens.
Integration tests for API and SSH connections.
Use MockK for mocking, Turbine for Flow testing.

## RN-MOB-003-07: Build Configuration
Debug and Release build types.
Staging flavor for beta testing.
ProGuard/R8 enabled for release.
Baseline profiles for performance.

## RN-MOB-003-08: API Integration
Claude API via Messages endpoint (/v1/messages).
System prompt includes Savia identity from savia-identity.md.
Streaming enabled for real-time token display.
Context window management: auto-summarize at 80% capacity.

## RN-MOB-003-09: Error Boundaries
Wrap all Compose screens in error boundary composables.
Unhandled exceptions caught by global handler.
Crash reports via Firebase Crashlytics (opt-in).
