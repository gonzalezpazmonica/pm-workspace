# Android Autonomous Debugger

**Trigger**: When the user asks to debug, test, or verify an Android app on a physical device, or when a build-and-test cycle is needed against a connected Android device.

**Keywords**: android debug, test on device, install apk, check crash, mobile testing, e2e test, verify on phone, run on device, screen capture device.

## Prerequisites

- Android device connected via USB with USB debugging enabled
- ADB available (auto-detected from Android SDK)
- APK built and ready (or source available to build)

## Core Capabilities

### 1. Device Discovery
```bash
source scripts/lib/adb-wrapper.sh
adb_auto_select          # Auto-select single device
adb_devices              # JSON list of all devices
adb_device_info          # JSON device properties
```

### 2. APK Lifecycle
```bash
adb_install ./path/to/app.apk   # Install (with -r -t flags)
adb_uninstall com.package.name   # Uninstall
adb_launch com.package.name      # Launch via monkey
adb_stop com.package.name        # Force stop
adb_clear_data com.package.name  # Clear app data
adb_is_installed com.package.name && echo "yes"
```

### 3. Visual Inspection
```bash
adb_screenshot /tmp/screen.png   # Capture current screen
adb_hierarchy /tmp/ui.xml        # Dump UI tree (UIAutomator)
adb_snapshot /tmp/prefix          # screenshot + hierarchy + logcat at once
```

### 4. UI Interaction
```bash
adb_tap 500 900                  # Tap at coordinates
adb_tap_id "login_button"       # Tap element by resource-id
adb_tap_text "Conectar"          # Tap element by visible text
adb_swipe 500 1200 500 400 300   # Swipe gesture
adb_scroll_down                  # Scroll screen down
adb_scroll_up                    # Scroll screen up
adb_type "hello world"           # Type text
adb_key back                     # Press BACK
adb_key home                     # Press HOME
adb_key enter                    # Press ENTER
adb_long_press 500 900 2000      # Long press 2 seconds
```

### 5. Debugging
```bash
adb_logcat_clear                 # Clear log buffer
adb_logcat_errors 30             # Errors from last 30 seconds
adb_logcat_errors 60 com.savia.mobile  # Package-filtered errors
adb_logcat_recent 10             # All logs last 10 seconds
adb_detect_crash 60              # Detect crash patterns
adb_meminfo com.savia.mobile     # Memory usage
```

### 6. Element Finding & Waiting
```bash
adb_find_by_id "btn_send"        # Returns "x1,y1,x2,y2" bounds
adb_find_by_text "Savia"         # Find by visible text
adb_wait_for_text "Welcome" 15   # Wait up to 15s for text
adb_wait_for_id "main_screen" 10 # Wait for element by ID
```

## Autonomous Debug Cycle

When asked to verify an app on device, follow this cycle:

### Phase 1: Setup
1. Source the wrapper: `source scripts/lib/adb-wrapper.sh`
2. Auto-select device: `adb_auto_select`
3. Get device info: `adb_device_info`
4. Clear logcat: `adb_logcat_clear`

### Phase 2: Install & Launch
5. Install APK: `adb_install <path>`
6. Verify installed: `adb_is_installed <package>`
7. Launch app: `adb_launch <package>`
8. Wait for main screen: `adb_wait_for_text "..." 15`
9. Take baseline screenshot: `adb_screenshot /tmp/baseline.png`

### Phase 3: Interact & Verify
10. For each screen/feature to test:
    - Navigate to it (tap, swipe, type)
    - Take screenshot
    - Check hierarchy for expected elements
    - Check logcat for errors after each action
11. If a crash is detected: `adb_detect_crash 30`
    - Capture full logcat
    - Report crash details with stack trace

### Phase 4: Report
12. Summarize: PASS/FAIL per screen tested
13. Include screenshots as evidence
14. Include crash logs if any
15. Suggest fixes based on stack traces

## Security Model

Operations are classified into three security levels:

| Level | Examples | Behavior |
|-------|----------|----------|
| **Safe** | screenshot, logcat, hierarchy, tap, type | Auto-approved |
| **Risky** | install, uninstall, force-stop, clear data | Logged, allowed |
| **Blocked** | rm -rf, format, su, dd | Always rejected |

The `android-adb-validate.sh` hook enforces this classification.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ADB_PATH` | auto-detect | Path to ADB binary |
| `ADB_DEVICE` | auto-select | Target device serial |
| `ADB_RETRIES` | 3 | Max retries per command |
| `ADB_TIMEOUT` | 30 | Command timeout (seconds) |

## Tips for Agents

- Always `adb_auto_select` before any other operation
- Take screenshots BEFORE and AFTER each interaction
- Check `adb_detect_crash` after navigating to a new screen
- Use `adb_wait_for_text` instead of `sleep` — it's faster and more reliable
- The `adb_snapshot` function captures everything at once (screen + UI tree + logs)
- When debugging crashes: `adb_logcat_errors 60 <package>` gives package-specific errors
