# Android Debug Agent

The Android Debug Agent provides autonomous debugging and testing of Android apps against physical devices connected via USB. It wraps ADB with security classification, retry logic, and structured output designed for AI agent consumption.

## Architecture

```
┌──────────────────────────────────────────────────┐
│           Claude Code / AI Agent                 │
│  (reads skill, calls wrapper functions)          │
└────────────────────┬─────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────┐
│     android-adb-validate.sh (PreToolUse hook)    │
│  classifies commands: safe → risky → blocked     │
└────────────────────┬─────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────┐
│          adb-wrapper.sh (library)                │
│  • Device discovery    • UI interaction          │
│  • Screenshot/hierarchy • Logcat & crash detect  │
│  • APK lifecycle       • Wait-for-element        │
└────────────────────┬─────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────┐
│              ADB (Android SDK)                   │
│         Physical device via USB                  │
└──────────────────────────────────────────────────┘
```

## Components

| File | Purpose |
|------|---------|
| `scripts/lib/adb-wrapper.sh` | ADB abstraction layer with 40+ functions |
| `.opencode/hooks/android-adb-validate.sh` | Security hook for PreToolUse |
| `.opencode/skills/android-autonomous-debugger/SKILL.md` | Agent skill with workflow |
| `scripts/tests/test-adb-wrapper.sh` | Integration test suite (44 tests) |

## Quick Start

### 1. Verify setup

```bash
source scripts/lib/adb-wrapper.sh
adb_selftest
```

Expected output:
```
=== ADB Wrapper Self-Test ===
1. ADB binary: OK (/home/monica/Android/Sdk/platform-tools/adb)
2. Device connected: OK (OUKITELC3690497)
3. Device info: OK
4. Screenshot: OK (90745 bytes)
5. Hierarchy dump: OK (234 lines)
6. Logcat: OK (42 lines)
7. Security classification: OK (safe/risky/blocked)
=== Self-Test Complete ===
```

### 2. Basic usage

```bash
source scripts/lib/adb-wrapper.sh
adb_auto_select

# Install and launch
adb_install ./app/build/outputs/apk/debug/app-debug.apk
adb_launch com.savia.mobile

# Wait and verify
sleep 3
adb_screenshot /tmp/screen.png
adb_detect_crash 10
```

### 3. Full debug cycle

```bash
source scripts/lib/adb-wrapper.sh
adb_auto_select
adb_logcat_clear

# Install
adb_install path/to/app.apk
adb_launch com.savia.mobile

# Wait for app
adb_wait_for_text "Savia" 15

# Take baseline
adb_snapshot /tmp/baseline

# Interact
adb_tap_text "Chat"
sleep 2
adb_screenshot /tmp/after-chat.png
adb_detect_crash 10

# Navigate
adb_tap_text "Conectar"
adb_type "192.168.1.100"
adb_key enter

# Check results
adb_logcat_errors 30 com.savia.mobile
```

## Use Cases

### For PM / QA: Smoke test after build

```bash
source scripts/lib/adb-wrapper.sh
adb_auto_select

# Fresh install
adb_stop com.savia.mobile
adb_clear_data com.savia.mobile
adb_install ./scripts/dist/app-debug.apk

# Launch and verify no crash
adb_logcat_clear
adb_launch com.savia.mobile
sleep 5

CRASH=$(adb_detect_crash 10)
if [[ "$CRASH" == "NO_CRASH" ]]; then
    echo "SMOKE TEST: PASS"
else
    echo "SMOKE TEST: FAIL"
    adb_logcat_errors 30 com.savia.mobile
fi
```

### For developers: Debug a specific screen

```bash
source scripts/lib/adb-wrapper.sh
adb_auto_select

# Navigate to the screen
adb_launch com.savia.mobile
sleep 3
adb_tap_text "Chat"
sleep 2

# Capture state
adb_snapshot /tmp/chat-debug

# Check for issues
adb_detect_crash 15
adb_logcat_errors 15 com.savia.mobile
adb_meminfo com.savia.mobile
```

### For CI: Automated verification

```bash
source scripts/lib/adb-wrapper.sh
adb_auto_select

# Build + install
cd projects/savia-mobile-android
JAVA_HOME=/snap/android-studio/209/jbr ./gradlew buildAndPublish
adb_install app/build/outputs/apk/debug/app-debug.apk

# Run tests
adb_logcat_clear
adb_launch com.savia.mobile
sleep 5

# Verify each screen
SCREENS=("Home" "Chat" "Sessions" "Settings")
for screen in "${SCREENS[@]}"; do
    adb_tap_text "$screen" 2>/dev/null || true
    sleep 2
    adb_screenshot "/tmp/verify-${screen}.png"
    CRASH=$(adb_detect_crash 5)
    if [[ "$CRASH" != "NO_CRASH" ]]; then
        echo "CRASH on screen: $screen"
        adb_logcat_errors 15 com.savia.mobile
        exit 1
    fi
    adb_key back
    sleep 1
done

echo "All screens verified: PASS"
```

## Security Model

Commands are classified into three levels:

### Safe (auto-approved, no prompt)

Screenshots, logcat, UI hierarchy, device info, input events (tap/swipe/type), file pull, process listing.

### Risky (approved with log entry)

APK install/uninstall, app data clearing, file push, force-stop, reboot.

### Blocked (always rejected)

`rm -rf`, `format`, `dd`, `su`, `root`. These are never executed regardless of context.

The classification is enforced by `android-adb-validate.sh` which runs as a PreToolUse hook. All operations are logged to `~/.claude/logs/android-adb.log`.

## API Reference

### Device Management
| Function | Arguments | Returns |
|----------|-----------|---------|
| `adb_find_binary` | — | ADB path string |
| `adb_devices` | — | JSON array of devices |
| `adb_auto_select` | — | Sets `ADB_DEVICE` |
| `adb_device_info` | — | JSON device properties |

### APK Operations
| Function | Arguments | Returns |
|----------|-----------|---------|
| `adb_install` | `apk_path` | stdout from adb |
| `adb_uninstall` | `package` | stdout from adb |
| `adb_is_installed` | `package` | exit code 0/1 |
| `adb_launch` | `package` `[activity]` | — |
| `adb_stop` | `package` | — |
| `adb_clear_data` | `package` | — |

### Visual Inspection
| Function | Arguments | Returns |
|----------|-----------|---------|
| `adb_screenshot` | `[output_path]` | File path |
| `adb_hierarchy` | `[output_path]` | File path (XML) |
| `adb_snapshot` | `[prefix]` | JSON with 3 paths |

### UI Interaction
| Function | Arguments | Returns |
|----------|-----------|---------|
| `adb_tap` | `x` `y` | — |
| `adb_tap_id` | `resource_id` | — |
| `adb_tap_text` | `text` | — |
| `adb_long_press` | `x` `y` `[duration_ms]` | — |
| `adb_swipe` | `x1` `y1` `x2` `y2` `[duration_ms]` | — |
| `adb_scroll_down` | — | — |
| `adb_scroll_up` | — | — |
| `adb_type` | `text` | — |
| `adb_key` | `key_name_or_code` | — |

### Element Finding
| Function | Arguments | Returns |
|----------|-----------|---------|
| `adb_find_by_id` | `resource_id` | `x1,y1,x2,y2` bounds |
| `adb_find_by_text` | `text` | `x1,y1,x2,y2` bounds |
| `adb_wait_for_text` | `text` `[timeout]` `[interval]` | exit code 0/1 |
| `adb_wait_for_id` | `resource_id` `[timeout]` `[interval]` | exit code 0/1 |

### Debugging
| Function | Arguments | Returns |
|----------|-----------|---------|
| `adb_logcat_clear` | — | — |
| `adb_logcat_errors` | `[seconds]` `[package]` | Log text |
| `adb_logcat_recent` | `[seconds]` | Log text |
| `adb_detect_crash` | `[seconds]` | `CRASH_DETECTED` or `NO_CRASH` |
| `adb_meminfo` | `package` | Memory info text |

### Utilities
| Function | Arguments | Returns |
|----------|-----------|---------|
| `adb_classify` | `command_string` | `safe`, `risky`, or `blocked` |
| `adb_selftest` | — | Test report |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ADB_PATH` | auto-detect | Override ADB binary location |
| `ADB_DEVICE` | auto-select | Target device serial number |
| `ADB_RETRIES` | 3 | Max retries for failed commands |
| `ADB_TIMEOUT` | 30 | Command timeout in seconds |

## Running Tests

```bash
./scripts/tests/test-adb-wrapper.sh
```

Requires a connected Android device. Tests cover: core functions (2), security classification (16), device management (4), screenshots (4), logcat (3), snapshots (3), Savia Mobile integration (7), hook validation (3). Total: 44 tests.

## Future Roadmap

- **Maestro integration**: YAML-based E2E test flows
- **Visual regression**: Perceptual hash comparison of screenshots
- **iOS support**: via `libimobiledevice` (screenshots + logs on Linux)
- **Device farm**: Appium grid for parallel testing
- **SDD pipeline**: Integrate as a step in spec-driven-development
