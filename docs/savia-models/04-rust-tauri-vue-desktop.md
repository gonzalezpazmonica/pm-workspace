# Savia Model 04 — Rust + Tauri 2 + Vue 3 Desktop Application

> Stack: Rust (backend) + Tauri 2 (bridge) + Vue 3 + TypeScript (frontend)
> Architecture: Desktop (Core-Shell)
> Team Scale: Small (2-5) to Growth (6-20)
> Exemplar: savia-monitor

---

## 1. Philosophy and Culture

### Why Rust + Tauri over Electron

Electron ships an entire Chromium instance per application. A "Hello World"
Electron app weighs 150+ MB. The equivalent Tauri app weighs 3-8 MB because
it delegates rendering to the operating system's native WebView (WebView2 on
Windows, WebKitGTK on Linux, WKWebView on macOS).

The deeper argument is not size but **attack surface**. Electron bundles a
full browser engine that the team must patch independently. Tauri uses the
OS-maintained WebView, inheriting security updates from the platform. The
Rust backend runs in a memory-safe language where entire categories of
CVEs (buffer overflows, use-after-free, data races) are eliminated at
compile time.

### Honest trade-offs

**Slower iteration speed.** Rust compile times are measured in minutes,
not milliseconds. A cold build of a medium Tauri app takes 2-5 minutes.
Incremental builds improve this to 5-15 seconds but remain slower than
hot module replacement in a pure JS stack.

**WebView inconsistencies.** Unlike Electron's single Chromium, Tauri
renders on three different engines. CSS features, JavaScript APIs, and
rendering quirks differ across platforms. Budget 10-15% of frontend effort
for cross-platform visual QA.

**Smaller ecosystem.** The Tauri plugin ecosystem is growing but has fewer
options than Electron's mature npm landscape. Expect to write more native
Rust code where an Electron team would npm-install a package.

**Steeper learning curve.** Rust's ownership model, lifetimes, and trait
system demand upfront investment. A team that has never written Rust should
budget 2-4 weeks of ramp-up before productive output.

### When NOT to use this model

- Rapid prototypes where time-to-first-demo matters more than quality
- Applications requiring deep browser integration (extensions, DevTools)
- Teams with zero Rust experience and a deadline under 8 weeks

---

## 2. Architecture Principles

### Core-Shell Model

The application splits into two processes connected by IPC:

```
+---------------------------+          +----------------------------+
|       Rust Backend        |   IPC    |      Vue 3 Frontend        |
|       (Core)              | <------> |      (Shell)               |
|                           |          |                            |
|  - Business logic         | commands |  - UI rendering            |
|  - File system access     | -------> |  - User interaction        |
|  - Database (SQLite)      |          |  - Pinia state (derived)   |
|  - Network requests       | <------- |  - Composables             |
|  - Crypto / auth          |  events  |  - Router                  |
|  - OS integration         |          |  - i18n                    |
+---------------------------+          +----------------------------+
```

**The Rust backend is the source of truth.** The Vue frontend holds derived
state for rendering. If the frontend and backend disagree, the backend wins.

### Two IPC Primitives

Tauri 2 provides exactly two IPC mechanisms. Use the right one:

| Primitive | Direction | Semantics | Use for |
|-----------|-----------|-----------|---------|
| **Commands** | Frontend -> Backend | Request/Response (Promise) | Fetching data, triggering actions, CRUD |
| **Events** | Backend -> Frontend (or Frontend -> Backend) | Fire-and-forget, pub/sub | State changes, progress updates, notifications |

Commands are the primary mechanism. They map to `async fn` in Rust and
resolve as Promises in TypeScript. Events complement commands for
push-based notifications where the backend needs to inform the frontend
without being asked.

### State Management Split

| Layer | Tool | Responsibility |
|-------|------|----------------|
| Rust backend | `Mutex<T>` / `RwLock<T>` in Tauri managed state | Authoritative data, persistence, validation |
| Vue frontend | Pinia stores | UI-derived state, optimistic updates, view models |

**Rule:** The frontend may cache backend data in Pinia for reactivity, but
NEVER considers its cache authoritative. After any mutation, the frontend
re-fetches or listens for a backend event confirming the new state.

### Dependency Rule

Dependencies flow inward: Vue -> Tauri IPC -> Rust services -> Rust domain.
The domain layer has zero dependencies on Tauri, Vue, or any framework. This
enables testing domain logic with plain `cargo test` without launching any
application.

---

## 3. Project Structure

```
project-root/
├── src-tauri/
│   ├── Cargo.toml               # Rust dependencies + release profile
│   ├── tauri.conf.json          # Tauri configuration (window, CSP, updater)
│   ├── capabilities/
│   │   └── default.json         # Capability-permission declarations
│   ├── icons/                   # App icons (all sizes)
│   ├── build.rs                 # Tauri build script
│   └── src/
│       ├── main.rs              # Entry point (< 40 lines)
│       ├── lib.rs               # Module declarations, Tauri builder setup
│       ├── commands/
│       │   ├── mod.rs           # Re-exports all command modules
│       │   ├── files.rs         # File-related commands
│       │   └── settings.rs      # Settings commands
│       ├── services/
│       │   ├── mod.rs
│       │   ├── file_service.rs  # Business logic (no Tauri dependency)
│       │   └── db_service.rs
│       ├── models/
│       │   ├── mod.rs
│       │   ├── app_state.rs     # Tauri managed state definition
│       │   └── domain.rs        # Domain types (Serialize + TS derive)
│       ├── errors.rs            # Unified error type (thiserror + Serialize)
│       └── events.rs            # Event payload types
├── src/
│   ├── App.vue                  # Root Vue component
│   ├── main.ts                  # Vue app bootstrap
│   ├── router/
│   │   └── index.ts
│   ├── stores/
│   │   ├── settings.ts          # Pinia store (derived from backend)
│   │   └── files.ts
│   ├── composables/
│   │   ├── useTauriCommand.ts   # Generic invoke wrapper
│   │   └── useTauriEvent.ts     # Generic event listener wrapper
│   ├── components/
│   │   └── ...
│   ├── pages/
│   │   └── ...
│   ├── types/
│   │   └── bindings.ts          # Auto-generated from ts-rs (do not edit)
│   └── locales/
│       ├── es.json
│       └── en.json
├── package.json
├── vite.config.ts
├── tsconfig.json
├── vitest.config.ts
└── CLAUDE.md                    # Project-specific agent instructions
```

### Cargo.toml Release Profile

```toml
[profile.release]
codegen-units = 1    # Better LLVM optimization (single codegen unit)
lto = true           # Link-Time Optimization across all crates
opt-level = "s"      # Optimize for size (use "3" if perf > size)
panic = "abort"      # No unwinding — smaller binary, faster panics
strip = true         # Remove debug symbols from release binary
```

**Warning:** On Linux, `strip = true` can interfere with Tauri's bundler
patching of `__TAURI_BUNDLE_TYPE`. Test Linux builds with strip enabled.
If bundler fails, set `strip = "debuginfo"` instead.

### File Naming Conventions

| Layer | Convention | Example |
|-------|-----------|---------|
| Rust modules | snake_case | `file_service.rs` |
| Vue components | PascalCase | `FileExplorer.vue` |
| TypeScript files | camelCase | `useTauriCommand.ts` |
| Pinia stores | camelCase | `settings.ts` |
| Generated types | camelCase | `bindings.ts` |

---

## 4. Code Patterns

### 4.1 Error Type with thiserror + Serialize

Every Tauri command must return `Result<T, E>` where `E: Serialize`. The
standard pattern combines `thiserror` for ergonomic error definition with
a manual `Serialize` implementation that converts errors to structured
objects the frontend can parse.

```rust
// src-tauri/src/errors.rs
use serde::Serialize;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("File not found: {0}")]
    NotFound(String),

    #[error("Permission denied: {0}")]
    PermissionDenied(String),

    #[error("Database error: {0}")]
    Database(String),

    #[error("Unexpected error: {0}")]
    Internal(String),
}

// Serialize as a discriminated union for TypeScript consumption
impl Serialize for AppError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        use serde::ser::SerializeStruct;
        let (kind, message) = match self {
            AppError::NotFound(m) => ("NotFound", m.as_str()),
            AppError::PermissionDenied(m) => ("PermissionDenied", m.as_str()),
            AppError::Database(m) => ("Database", m.as_str()),
            AppError::Internal(m) => ("Internal", m.as_str()),
        };
        let mut s = serializer.serialize_struct("AppError", 2)?;
        s.serialize_field("kind", kind)?;
        s.serialize_field("message", message)?;
        s.end()
    }
}

// Convenience conversion from common error types
impl From<std::io::Error> for AppError {
    fn from(err: std::io::Error) -> Self {
        match err.kind() {
            std::io::ErrorKind::NotFound => AppError::NotFound(err.to_string()),
            std::io::ErrorKind::PermissionDenied => {
                AppError::PermissionDenied(err.to_string())
            }
            _ => AppError::Internal(err.to_string()),
        }
    }
}

pub type AppResult<T> = Result<T, AppError>;
```

### 4.2 Tauri Command Handlers

Commands are thin wrappers that extract state, call services, and return
results. They contain zero business logic.

```rust
// src-tauri/src/commands/files.rs
use crate::errors::AppResult;
use crate::models::app_state::AppState;
use crate::services::file_service;
use tauri::State;

#[tauri::command]
pub async fn list_files(
    state: State<'_, AppState>,
    directory: String,
) -> AppResult<Vec<FileEntry>> {
    let config = state.config.read().await;
    file_service::list_directory(&directory, &config).await
}

#[tauri::command]
pub async fn read_file(path: String) -> AppResult<String> {
    file_service::read_contents(&path).await
}

#[tauri::command]
pub async fn write_file(path: String, content: String) -> AppResult<()> {
    file_service::write_contents(&path, &content).await
}
```

### 4.3 Application State with Managed Mutex

```rust
// src-tauri/src/models/app_state.rs
use tokio::sync::RwLock;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AppConfig {
    pub root_directory: String,
    pub theme: String,
    pub language: String,
}

pub struct AppState {
    pub config: RwLock<AppConfig>,
    pub db: RwLock<Option<rusqlite::Connection>>,
}

impl AppState {
    pub fn new(config: AppConfig) -> Self {
        Self {
            config: RwLock::new(config),
            db: RwLock::new(None),
        }
    }
}
```

### 4.4 Domain Types with ts-rs for Type Sharing

```rust
// src-tauri/src/models/domain.rs
use serde::{Deserialize, Serialize};
use ts_rs::TS;

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../src/types/bindings.ts")]
pub struct FileEntry {
    pub name: String,
    pub path: String,
    pub is_directory: bool,
    pub size_bytes: u64,
    pub modified_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../src/types/bindings.ts")]
pub struct AppSettings {
    pub theme: String,
    pub language: String,
    pub auto_update: bool,
}
```

Run `cargo test` to generate the TypeScript bindings file. The `ts-rs`
crate exports types during test execution, producing `src/types/bindings.ts`
automatically.

### 4.5 Minimal main.rs (Under 40 Lines)

```rust
// src-tauri/src/main.rs
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    app_lib::run();
}
```

```rust
// src-tauri/src/lib.rs
mod commands;
mod errors;
mod events;
mod models;
mod services;

use models::app_state::{AppConfig, AppState};

pub fn run() {
    let config = AppConfig {
        root_directory: String::new(),
        theme: "system".to_string(),
        language: "es".to_string(),
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_updater::init())
        .manage(AppState::new(config))
        .invoke_handler(tauri::generate_handler![
            commands::files::list_files,
            commands::files::read_file,
            commands::files::write_file,
            commands::settings::get_settings,
            commands::settings::update_settings,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### 4.6 Event Emission from Backend

```rust
// src-tauri/src/events.rs
use serde::{Deserialize, Serialize};
use ts_rs::TS;

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../src/types/bindings.ts")]
pub struct ProgressEvent {
    pub task_id: String,
    pub percent: u8,
    pub message: String,
}

// Usage inside a service or command:
// app_handle.emit("import-progress", ProgressEvent { ... })?;
```

### 4.7 useTauriCommand Composable (TypeScript)

```typescript
// src/composables/useTauriCommand.ts
import { ref, type Ref } from 'vue'
import { invoke } from '@tauri-apps/api/core'

interface AppError {
  kind: string
  message: string
}

interface UseTauriCommandReturn<T> {
  data: Ref<T | null>
  error: Ref<AppError | null>
  loading: Ref<boolean>
  execute: (...args: unknown[]) => Promise<T | null>
}

export function useTauriCommand<T>(
  command: string,
): UseTauriCommandReturn<T> {
  const data = ref<T | null>(null) as Ref<T | null>
  const error = ref<AppError | null>(null)
  const loading = ref(false)

  const execute = async (...args: unknown[]): Promise<T | null> => {
    loading.value = true
    error.value = null
    try {
      const result = await invoke<T>(command, args[0] as Record<string, unknown>)
      data.value = result
      return result
    } catch (e) {
      error.value = e as AppError
      return null
    } finally {
      loading.value = false
    }
  }

  return { data, error, loading, execute }
}
```

### 4.8 useTauriEvent Composable (TypeScript)

```typescript
// src/composables/useTauriEvent.ts
import { onMounted, onUnmounted, ref, type Ref } from 'vue'
import { listen, type UnlistenFn } from '@tauri-apps/api/event'

export function useTauriEvent<T>(eventName: string): Ref<T | null> {
  const payload = ref<T | null>(null) as Ref<T | null>
  let unlisten: UnlistenFn | null = null

  onMounted(async () => {
    unlisten = await listen<T>(eventName, (event) => {
      payload.value = event.payload
    })
  })

  onUnmounted(() => {
    unlisten?.()
  })

  return payload
}
```

### 4.9 Pinia Store Consuming Backend State

```typescript
// src/stores/settings.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { useTauriCommand } from '@/composables/useTauriCommand'
import type { AppSettings } from '@/types/bindings'

export const useSettingsStore = defineStore('settings', () => {
  const settings = ref<AppSettings | null>(null)

  const { execute: fetchSettings } = useTauriCommand<AppSettings>('get_settings')
  const { execute: saveSettings } = useTauriCommand<void>('update_settings')

  async function load() {
    settings.value = await fetchSettings()
  }

  async function update(patch: Partial<AppSettings>) {
    if (!settings.value) return
    const merged = { ...settings.value, ...patch }
    await saveSettings({ settings: merged })
    // Re-fetch to confirm backend accepted the change
    await load()
  }

  return { settings, load, update }
})
```

---

## 5. Testing and Quality

### Test Pyramid

| Layer | Share | Tool | What it tests |
|-------|-------|------|---------------|
| Rust service unit tests | 40% | `cargo test` + `tokio::test` | Business logic, file parsing, validation |
| Vue component tests | 30% | Vitest + Vue Test Utils | Component rendering, interaction, props |
| IPC integration tests | 15% | Vitest with mocked `invoke` | Command invocation, error handling, type contracts |
| Rust unit tests (domain) | 10% | `cargo test` | Pure domain types, serialization, conversions |
| E2E tests | 5% | Playwright or WebDriver | Full application flows, cross-platform |

### Rust Tests with tokio

```rust
// src-tauri/src/services/file_service.rs
#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_list_directory_returns_entries() {
        let dir = tempdir().unwrap();
        std::fs::write(dir.path().join("test.txt"), "hello").unwrap();

        let config = AppConfig {
            root_directory: dir.path().to_string_lossy().to_string(),
            ..Default::default()
        };
        let entries = list_directory(
            &dir.path().to_string_lossy(),
            &config,
        ).await.unwrap();

        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].name, "test.txt");
        assert!(!entries[0].is_directory);
    }

    #[tokio::test]
    async fn test_list_nonexistent_returns_not_found() {
        let config = AppConfig::default();
        let result = list_directory("/nonexistent/path", &config).await;
        assert!(matches!(result, Err(AppError::NotFound(_))));
    }
}
```

### Vue Component Tests with Mocked invoke

```typescript
// src/__tests__/components/FileExplorer.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import FileExplorer from '@/components/FileExplorer.vue'

// Mock the Tauri invoke API
vi.mock('@tauri-apps/api/core', () => ({
  invoke: vi.fn(),
}))

import { invoke } from '@tauri-apps/api/core'
const mockInvoke = vi.mocked(invoke)

describe('FileExplorer', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('renders file list from backend', async () => {
    mockInvoke.mockResolvedValueOnce([
      { name: 'readme.md', path: '/readme.md', is_directory: false, size_bytes: 1024, modified_at: null },
    ])

    const wrapper = mount(FileExplorer)
    await wrapper.vm.$nextTick()

    // Wait for async command resolution
    await vi.waitFor(() => {
      expect(wrapper.text()).toContain('readme.md')
    })
  })

  it('displays error state on backend failure', async () => {
    mockInvoke.mockRejectedValueOnce({
      kind: 'NotFound',
      message: 'Directory not found',
    })

    const wrapper = mount(FileExplorer, {
      props: { directory: '/nonexistent' },
    })
    await vi.waitFor(() => {
      expect(wrapper.text()).toContain('not found')
    })
  })
})
```

### Coverage Targets

| Metric | Target | Rationale |
|--------|--------|-----------|
| Rust service coverage | >= 80% | Core business logic must be well-tested |
| Vue component coverage | >= 70% | UI tests are brittle; focus on behavior |
| IPC contract coverage | 100% | Every command must have at least one test |
| E2E coverage | Critical paths only | Login, main workflow, data persistence |

---

## 6. Security and Data Sovereignty

### Tauri 2 Capability-Permission System

Tauri 2 replaced the v1 allowlist with a granular capability-permission
system. Capabilities declare which IPC commands and plugin APIs each
window may access.

```json
// src-tauri/capabilities/default.json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "main-window",
  "description": "Capabilities for the main application window",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "shell:allow-open",
    "updater:default",
    {
      "identifier": "fs:allow-read",
      "allow": [
        { "path": "$APPDATA/**" },
        { "path": "$HOME/Documents/**" }
      ]
    }
  ]
}
```

**Principle of least privilege.** Each window gets only the capabilities
it needs. If a secondary settings window exists, give it a separate
capabilities file with fewer permissions than the main window.

### Content Security Policy

Configure CSP in `tauri.conf.json` to restrict what the WebView can load:

```json
{
  "app": {
    "security": {
      "csp": "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' asset: https://asset.localhost; connect-src ipc: http://ipc.localhost"
    }
  }
}
```

**NEVER** add `unsafe-eval` to the CSP. Tauri appends nonces and hashes
to CSP attributes automatically at compile time for bundled code. If a
library requires `eval()`, replace it.

### IPC Input Validation

Every Tauri command validates its inputs before processing. The Rust type
system provides a first barrier (deserialization fails for wrong types),
but semantic validation is the developer's responsibility.

```rust
#[tauri::command]
pub async fn write_file(path: String, content: String) -> AppResult<()> {
    // Validate: path must not escape the allowed directory
    let canonical = std::fs::canonicalize(&path)
        .map_err(|e| AppError::NotFound(e.to_string()))?;
    if !canonical.starts_with("/allowed/directory") {
        return Err(AppError::PermissionDenied(
            "Path outside allowed directory".to_string(),
        ));
    }
    file_service::write_contents(&path, &content).await
}
```

### Auto-Update Signing

Tauri's updater plugin requires signing update bundles. Generate a key pair
and store the private key as a CI secret:

```bash
npx @tauri-apps/cli signer generate -w ~/.tauri/myapp.key
```

The public key goes in `tauri.conf.json`. The private key stays in CI
secrets (`TAURI_SIGNING_PRIVATE_KEY`). NEVER commit the private key.

### Savia Shield Classification

| Data type | Classification | Where it lives |
|-----------|---------------|----------------|
| Application source code | N1 (public) | Git repository |
| User preferences, window state | N2 (local, not sensitive) | `$APPDATA/` via Tauri path API |
| User documents processed by the app | N3 (user-personal) | User's filesystem, never transmitted |
| Telemetry, crash reports | N2 if anonymized, N3 if identifiable | Only with explicit consent |

The Savia Shield `data-sovereignty-gate.sh` hook applies to the Tauri
project repository. Domain terms from `GLOSSARY.md` are scanned in
outbound code to prevent N3+ data from leaking into N1 artifacts.

---

## 7. DevOps and Operations

### GitHub Actions Matrix Build

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - platform: ubuntu-22.04
            args: ''
          - platform: windows-latest
            args: ''
          - platform: macos-latest
            args: '--target aarch64-apple-darwin'
          - platform: macos-latest
            args: '--target x86_64-apple-darwin'

    runs-on: ${{ matrix.platform }}
    steps:
      - uses: actions/checkout@v4

      - name: Install Rust stable
        uses: dtolnay/rust-toolchain@stable
        with:
          targets: ${{ matrix.platform == 'macos-latest' && 'aarch64-apple-darwin,x86_64-apple-darwin' || '' }}

      - name: Install Linux deps
        if: matrix.platform == 'ubuntu-22.04'
        run: |
          sudo apt-get update
          sudo apt-get install -y libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - run: npm ci

      - uses: tauri-apps/tauri-action@v0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TAURI_SIGNING_PRIVATE_KEY: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY }}
          TAURI_SIGNING_PRIVATE_KEY_PASSWORD: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY_PASSWORD }}
        with:
          tagName: v__VERSION__
          releaseName: 'v__VERSION__'
          releaseBody: 'See CHANGELOG.md for details.'
          releaseDraft: true
          prerelease: false
          args: ${{ matrix.args }}
```

All three matrix jobs upload to the same draft release. The first job
creates the release; subsequent jobs add their platform artifacts.

### Auto-Update Infrastructure

Configure the updater endpoint in `tauri.conf.json`:

```json
{
  "plugins": {
    "updater": {
      "active": true,
      "dialog": true,
      "endpoints": [
        "https://github.com/YOUR_ORG/YOUR_REPO/releases/latest/download/latest.json"
      ],
      "pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6..."
    }
  }
}
```

The `tauri-action` generates the `latest.json` manifest automatically when
the updater is configured. Users receive update notifications through a
native dialog.

### Crash Reporting with tracing

Use the `tracing` crate for structured logging. Configure file-based log
output for crash diagnosis:

```rust
// In lib.rs setup
use tracing_subscriber::{fmt, EnvFilter};
use tracing_appender::rolling;

let file_appender = rolling::daily("$APPDATA/logs", "app.log");
let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

tracing_subscriber::fmt()
    .with_env_filter(EnvFilter::from_default_env())
    .with_writer(non_blocking)
    .init();
```

### Bundler Configuration

| Platform | Bundle format | Config key |
|----------|--------------|------------|
| Windows | NSIS (.exe installer) | `bundle.windows.nsis` |
| macOS | DMG + .app | `bundle.macOS.dmg` |
| Linux | AppImage + .deb | `bundle.linux.appimage`, `bundle.linux.deb` |

---

## 8. Anti-Patterns and Guardrails

### 15 DOs

| # | DO | Rationale |
|---|---|-----------|
| 1 | Keep `main.rs` under 40 lines | Delegates to `lib.rs`; enables `cargo test` without binary target |
| 2 | Use `tokio::sync::RwLock` for shared state | Allows concurrent reads; only blocks on writes |
| 3 | Derive `ts_rs::TS` on all IPC types | Auto-generates TypeScript bindings; single source of truth |
| 4 | Validate all command inputs in Rust | The frontend is untrusted; the backend gates access |
| 5 | Return structured errors with `kind` + `message` | Enables frontend to branch on error type, not string matching |
| 6 | Use capability files per window | Principle of least privilege for each WebView |
| 7 | Place business logic in `services/`, not in commands | Commands are thin; services are testable without Tauri |
| 8 | Use `#[cfg(test)]` modules co-located with source | Tests stay close to the code they verify |
| 9 | Run `cargo clippy --all-targets` in CI | Catches common Rust mistakes before review |
| 10 | Mock `invoke()` in Vue tests, never call real backend | Component tests must be fast and deterministic |
| 11 | Use Tauri's path API (`$APPDATA`, `$HOME`) for file access | Platform-agnostic paths; no hardcoded OS paths |
| 12 | Sign all release builds with `tauri signer` | Unsigned updates are rejected by the updater |
| 13 | Set `codegen-units = 1` + `lto = true` in release profile | Reduces binary size by 30-50% |
| 14 | Test on all three platforms in CI | WebView differences cause silent regressions |
| 15 | Use `tracing` crate for structured logging | Enables filtering, file output, and crash diagnosis |

### 15 DONTs

| # | DONT | Consequence |
|---|------|-------------|
| 1 | NEVER add `unsafe-eval` to CSP | Opens XSS attack vector; Tauri's nonce system handles safe JS |
| 2 | NEVER let the frontend hold authoritative state | State divergence between frontend and backend causes data loss |
| 3 | NEVER block the async runtime with `.unwrap()` on locks | Causes deadlocks; use `try_lock()` or `tokio::spawn_blocking` |
| 4 | NEVER use `std::sync::Mutex` in async context | Use `tokio::sync::Mutex` or `tokio::sync::RwLock` instead |
| 5 | NEVER commit the Tauri signing private key | Store in CI secrets; the public key goes in `tauri.conf.json` |
| 6 | NEVER use `#[allow(unused)]` to hide warnings | Fix the root cause; unused code is dead weight |
| 7 | NEVER skip the capability declaration for new commands | Unregistered commands are inaccessible; failing silently confuses devs |
| 8 | NEVER use `String` where an enum would be more precise | Stringly-typed IPC leads to silent mismatches between Rust and TS |
| 9 | NEVER write platform-specific code without `cfg` guards | Breaks compilation on other platforms |
| 10 | NEVER embed large assets in the Rust binary | Use Tauri's asset protocol; binary bloat degrades startup |
| 11 | NEVER use `panic!()` in command handlers | Panics crash the backend; return `Err(AppError::Internal(...))` |
| 12 | NEVER access the filesystem without path validation | Path traversal attacks let the frontend escape sandboxed directories |
| 13 | NEVER skip error handling in TypeScript `invoke` calls | Unhandled rejections silently swallow backend errors |
| 14 | NEVER use synchronous Tauri commands for I/O | Blocks the main thread; all I/O commands must be `async` |
| 15 | NEVER hardcode version numbers in multiple places | Use `Cargo.toml` as the single source; `tauri.conf.json` reads from it |

---

## 9. Agentic Integration

### Layer Assignment Matrix

| Layer | Files | Agent | Model |
|-------|-------|-------|-------|
| Domain models | `src-tauri/src/models/` | `rust-developer` | Sonnet 4.6 |
| Service logic | `src-tauri/src/services/` | `rust-developer` | Sonnet 4.6 |
| Tauri commands | `src-tauri/src/commands/` | `rust-developer` | Sonnet 4.6 |
| Error types | `src-tauri/src/errors.rs` | `rust-developer` | Sonnet 4.6 |
| Vue components | `src/components/` | `frontend-developer` | Sonnet 4.6 |
| Pinia stores | `src/stores/` | `frontend-developer` | Sonnet 4.6 |
| Composables | `src/composables/` | `frontend-developer` | Sonnet 4.6 |
| Vue pages | `src/pages/` | `frontend-developer` | Sonnet 4.6 |
| TypeScript types | `src/types/` | `frontend-developer` | Sonnet 4.6 |
| Tauri config | `src-tauri/tauri.conf.json` | `architect` | Opus 4.6 |
| Capabilities | `src-tauri/capabilities/` | `security-guardian` | Opus 4.6 |
| CI/CD | `.github/workflows/` | `terraform-developer` | Sonnet 4.6 |
| Architecture | `docs/`, `specs/` | `architect` | Opus 4.6 |

### SDD Spec Template for Tauri Commands

When writing a spec for a new Tauri command, include:

```markdown
## Command: {command_name}

### Rust Signature
- Parameters: {name}: {type} for each
- Return: AppResult<{type}>
- State dependencies: {which managed state it reads/writes}

### IPC Contract
- Frontend invoke: `invoke('{command_name}', { param1, param2 })`
- Success response type: {TypeScript type from bindings.ts}
- Error response type: AppError with expected `kind` values

### Validation Rules
- {rule 1}: {description}
- {rule 2}: {description}

### Capability Requirements
- Permission: {which permission must be declared}
- Scope: {allowed paths or resources}

### Test Requirements
- Rust unit test: {service function, happy path + error path}
- IPC integration test: {invoke mock, verify type contract}
- Vue test: {component that calls this command}
```

### Quality Gate Configuration

```yaml
# In project CLAUDE.md or agent-policies.yaml
quality_gates:
  pre_commit:
    - cargo clippy --all-targets -- -D warnings
    - cargo test
    - npm run type-check
    - npm run lint
    - npm run test:unit
  pre_merge:
    - cargo test --release
    - npm run test:unit -- --coverage
    - npm run test:e2e  # if E2E suite exists
  coverage:
    rust_minimum: 80
    vue_minimum: 70
    ipc_minimum: 100
```

### Dev Session Slice Strategy

For Tauri features, slices follow the dependency chain:

1. **Slice 1 — Domain model**: Rust structs with `Serialize` + `TS` derives
2. **Slice 2 — Service logic**: Rust functions with unit tests
3. **Slice 3 — Tauri command**: Thin handler + error mapping + capability
4. **Slice 4 — TypeScript types**: Generate bindings via `cargo test`
5. **Slice 5 — Vue composable/store**: Frontend integration with mocked invoke
6. **Slice 6 — Vue component**: UI rendering consuming the store

Each slice is independently testable. The `dev-orchestrator` assigns slices
1-3 to `rust-developer` and slices 4-6 to `frontend-developer`, running
them sequentially within each track but parallelizing the two tracks where
types (slice 4) are the synchronization point.

---

## References

- [Tauri 2 Inter-Process Communication](https://v2.tauri.app/concept/inter-process-communication/)
- [Tauri 2 Security Overview](https://v2.tauri.app/security/)
- [Tauri 2 Permissions](https://v2.tauri.app/security/permissions/)
- [Tauri 2 Capabilities](https://v2.tauri.app/security/capabilities/)
- [Tauri 2 CSP Configuration](https://v2.tauri.app/security/csp/)
- [Tauri 2 Calling Rust from Frontend](https://v2.tauri.app/develop/calling-rust/)
- [Tauri Error Handling Patterns](https://tauritutorials.com/blog/handling-errors-in-tauri)
- [Tauri Error Handling Recipes](https://tbt.qkation.com/posts/tauri-error-handling/)
- [ts-rs Crate Documentation](https://docs.rs/ts-rs/latest/ts_rs/)
- [Tauri 2 Project Structure](https://v2.tauri.app/start/project-structure/)
- [Tauri 2 App Size Optimization](https://v2.tauri.app/concept/size/)
- [Tauri GitHub Actions Pipeline](https://v2.tauri.app/distribute/pipelines/github/)
- [tauri-apps/tauri-action](https://github.com/tauri-apps/tauri-action)
- [Tauri 2.0 Stable Release Blog](https://v2.tauri.app/blog/tauri-20/)
