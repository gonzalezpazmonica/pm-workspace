#!/usr/bin/env bash
# ============================================================================
# adb-wrapper.sh — ADB abstraction layer for Savia Android Debug Agent
# ============================================================================
#
# Wraps Android Debug Bridge commands with:
#   - Auto-detection of ADB binary path
#   - Device discovery and selection
#   - Retry logic with exponential backoff
#   - Security classification (safe/risky/blocked)
#   - Structured JSON output for agent consumption
#   - Screenshot + hierarchy capture utilities
#
# Usage:
#   source scripts/lib/adb-wrapper.sh
#   adb_devices              # List connected devices
#   adb_screenshot /tmp/s.png  # Capture screenshot
#   adb_install ./app.apk    # Install APK
#   adb_tap 500 900           # Tap at coordinates
#   adb_logcat_errors 10      # Last 10 seconds of errors
#
# Environment:
#   ADB_PATH     — Override ADB binary location
#   ADB_DEVICE   — Target device serial (auto-detected if one device)
#   ADB_RETRIES  — Max retries for transient failures (default: 3)
#   ADB_TIMEOUT  — Command timeout in seconds (default: 30)
#
# Author: Savia PM-Workspace
# ============================================================================

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────

ADB_PATH="${ADB_PATH:-}"
ADB_DEVICE="${ADB_DEVICE:-}"
ADB_RETRIES="${ADB_RETRIES:-3}"
ADB_TIMEOUT="${ADB_TIMEOUT:-30}"

# Search paths for ADB binary
_ADB_SEARCH_PATHS=(
    "$HOME/Android/Sdk/platform-tools/adb"
    "/usr/local/bin/adb"
    "/usr/bin/adb"
    "/snap/android-studio/current/bin/adb"
)

# ─── Security Classification ───────────────────────────────────────────────

# Commands auto-approved without prompts
_SAFE_OPERATIONS=(
    "devices"
    "shell screencap"
    "shell uiautomator dump"
    "logcat"
    "shell ps"
    "shell getprop"
    "shell dumpsys"
    "shell wm size"
    "shell wm density"
    "shell settings get"
    "shell am current-focus"
    "shell cat /proc"
    "get-serialno"
    "get-state"
    "shell input"
    "pull"
    "shell content query"
    "bugreport"
    "version"
)

# Commands that require logging but are allowed
_RISKY_OPERATIONS=(
    "install"
    "uninstall"
    "shell pm clear"
    "push"
    "shell am start"
    "shell am force-stop"
    "shell monkey"
    "reboot"
)

# Commands that should NEVER be auto-approved
_BLOCKED_OPERATIONS=(
    "shell rm -rf"
    "shell rm -r /"
    "shell format"
    "shell dd if="
    "shell su"
    "root"
)

# ─── Core Functions ─────────────────────────────────────────────────────────

# Find ADB binary. Returns path or exits with error.
adb_find_binary() {
    if [[ -n "$ADB_PATH" && -x "$ADB_PATH" ]]; then
        echo "$ADB_PATH"
        return 0
    fi

    for path in "${_ADB_SEARCH_PATHS[@]}"; do
        if [[ -x "$path" ]]; then
            ADB_PATH="$path"
            echo "$path"
            return 0
        fi
    done

    # Try PATH
    if command -v adb &>/dev/null; then
        ADB_PATH="$(command -v adb)"
        echo "$ADB_PATH"
        return 0
    fi

    echo "ERROR: ADB not found. Set ADB_PATH or install Android SDK." >&2
    return 1
}

# Execute raw ADB command with retry logic.
# Usage: _adb_exec [args...]
_adb_exec() {
    local adb
    adb="$(adb_find_binary)"

    local device_flag=""
    if [[ -n "$ADB_DEVICE" ]]; then
        device_flag="-s $ADB_DEVICE"
    fi

    local attempt=0
    local max_attempts=$ADB_RETRIES
    local delay=1

    while (( attempt < max_attempts )); do
        # shellcheck disable=SC2086
        if timeout "$ADB_TIMEOUT" $adb $device_flag "$@" 2>&1; then
            return 0
        fi

        local exit_code=$?
        attempt=$((attempt + 1))

        if (( attempt < max_attempts )); then
            echo "WARN: ADB command failed (attempt $attempt/$max_attempts), retrying in ${delay}s..." >&2
            sleep "$delay"
            delay=$((delay * 2))
        fi
    done

    echo "ERROR: ADB command failed after $max_attempts attempts: $*" >&2
    return 1
}

# Classify a command's security level.
# Returns: "safe", "risky", or "blocked"
adb_classify() {
    local cmd="$*"

    for blocked in "${_BLOCKED_OPERATIONS[@]}"; do
        if [[ "$cmd" == *"$blocked"* ]]; then
            echo "blocked"
            return 0
        fi
    done

    for risky in "${_RISKY_OPERATIONS[@]}"; do
        if [[ "$cmd" == *"$risky"* ]]; then
            echo "risky"
            return 0
        fi
    done

    echo "safe"
}

# ─── Device Management ──────────────────────────────────────────────────────

# List connected devices as JSON array.
adb_devices() {
    local adb
    adb="$(adb_find_binary)"
    local raw
    raw="$($adb devices -l 2>&1)"

    echo "["
    local first=true
    while IFS= read -r line; do
        # Skip header and empty lines
        [[ "$line" == "List of devices"* ]] && continue
        [[ -z "$line" ]] && continue

        local serial model device transport state
        serial="$(echo "$line" | awk '{print $1}')"
        state="$(echo "$line" | awk '{print $2}')"

        # Extract model and device from the line
        model="$(echo "$line" | grep -oP 'model:\K\S+' || echo "unknown")"
        device="$(echo "$line" | grep -oP 'device:\K\S+' || echo "unknown")"
        transport="$(echo "$line" | grep -oP 'transport_id:\K\S+' || echo "0")"

        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        printf '  {"serial":"%s","state":"%s","model":"%s","device":"%s","transport_id":"%s"}' \
            "$serial" "$state" "$model" "$device" "$transport"
    done <<< "$raw"
    echo ""
    echo "]"
}

# Auto-select device if only one connected. Sets ADB_DEVICE.
adb_auto_select() {
    if [[ -n "$ADB_DEVICE" ]]; then
        return 0
    fi

    local adb
    adb="$(adb_find_binary)"
    local count
    count="$($adb devices | grep -c 'device$' || true)"

    if (( count == 0 )); then
        echo "ERROR: No Android devices connected." >&2
        return 1
    elif (( count == 1 )); then
        ADB_DEVICE="$($adb devices | grep 'device$' | awk '{print $1}')"
        echo "Auto-selected device: $ADB_DEVICE" >&2
        return 0
    else
        echo "ERROR: Multiple devices connected. Set ADB_DEVICE." >&2
        $adb devices -l >&2
        return 1
    fi
}

# Get device properties as JSON.
adb_device_info() {
    adb_auto_select || return 1

    local android_ver sdk_ver model manufacturer screen_size density
    android_ver="$(_adb_exec shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
    sdk_ver="$(_adb_exec shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')"
    model="$(_adb_exec shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    manufacturer="$(_adb_exec shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r')"
    screen_size="$(_adb_exec shell wm size 2>/dev/null | grep -oP '\d+x\d+' | tail -1 || echo "unknown")"
    density="$(_adb_exec shell wm density 2>/dev/null | grep -oP '\d+' | tail -1 || echo "unknown")"

    printf '{"serial":"%s","android":"%s","sdk":"%s","model":"%s","manufacturer":"%s","screen":"%s","density":"%s"}' \
        "$ADB_DEVICE" "$android_ver" "$sdk_ver" "$model" "$manufacturer" "$screen_size" "$density"
}

# ─── APK Operations ─────────────────────────────────────────────────────────

# Install APK on device.
adb_install() {
    local apk_path="$1"

    if [[ ! -f "$apk_path" ]]; then
        echo "ERROR: APK not found: $apk_path" >&2
        return 1
    fi

    echo "Installing APK: $apk_path" >&2
    _adb_exec install -r -t "$apk_path"
}

# Uninstall package.
adb_uninstall() {
    local package="$1"
    echo "Uninstalling: $package" >&2
    _adb_exec uninstall "$package" 2>/dev/null || true
}

# Check if package is installed.
adb_is_installed() {
    local package="$1"
    _adb_exec shell pm list packages 2>/dev/null | grep -q "package:$package"
}

# Launch app by package/activity.
adb_launch() {
    local package="$1"
    local activity="${2:-}"

    if [[ -n "$activity" ]]; then
        _adb_exec shell am start -n "$package/$activity"
    else
        # Use am start with LAUNCHER intent (faster and cleaner than monkey)
        local launcher
        launcher="$(_adb_exec shell cmd package resolve-activity --brief "$package" 2>/dev/null | tail -1 | tr -d '\r')"
        if [[ -n "$launcher" && "$launcher" == *"/"* ]]; then
            _adb_exec shell am start -n "$launcher" 2>/dev/null
        else
            # Fallback: use monkey (slower but works when resolve-activity fails)
            _adb_exec shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
        fi
    fi
}

# Force-stop app.
adb_stop() {
    local package="$1"
    _adb_exec shell am force-stop "$package"
}

# Clear app data.
adb_clear_data() {
    local package="$1"
    _adb_exec shell pm clear "$package"
}

# ─── Screenshot & Recording ────────────────────────────────────────────────

# Capture screenshot and pull to local path.
adb_screenshot() {
    local output="${1:-/tmp/android-screenshot-$(date +%s).png}"
    local device_path="/sdcard/savia-screenshot.png"

    _adb_exec shell screencap -p "$device_path" && \
    _adb_exec pull "$device_path" "$output" >/dev/null 2>&1 && \
    _adb_exec shell rm "$device_path" 2>/dev/null

    if [[ -f "$output" ]]; then
        echo "$output"
    else
        echo "ERROR: Screenshot failed" >&2
        return 1
    fi
}

# Start screen recording (max 180 seconds).
adb_record_start() {
    local output="${1:-/sdcard/savia-recording.mp4}"
    local duration="${2:-30}"

    _adb_exec shell screenrecord --time-limit "$duration" "$output" &
    echo $!
}

# Pull recording from device.
adb_record_pull() {
    local device_path="${1:-/sdcard/savia-recording.mp4}"
    local local_path="${2:-/tmp/android-recording-$(date +%s).mp4}"

    _adb_exec pull "$device_path" "$local_path" >/dev/null 2>&1
    echo "$local_path"
}

# ─── UI Interaction ─────────────────────────────────────────────────────────

# Tap at coordinates.
adb_tap() {
    local x="$1" y="$2"
    _adb_exec shell input tap "$x" "$y" >/dev/null
}

# Long press at coordinates (duration in ms).
adb_long_press() {
    local x="$1" y="$2" duration="${3:-1000}"
    _adb_exec shell input swipe "$x" "$y" "$x" "$y" "$duration" >/dev/null
}

# Swipe from (x1,y1) to (x2,y2) over duration ms.
adb_swipe() {
    local x1="$1" y1="$2" x2="$3" y2="$4" duration="${5:-300}"
    _adb_exec shell input swipe "$x1" "$y1" "$x2" "$y2" "$duration" >/dev/null
}

# Scroll down (swipe up gesture).
adb_scroll_down() {
    local screen_info
    screen_info="$(_adb_exec shell wm size 2>/dev/null | grep -oP '\d+x\d+' | tail -1)"
    local w h
    w="${screen_info%x*}"
    h="${screen_info#*x}"

    local cx=$((w / 2))
    local y_start=$((h * 70 / 100))
    local y_end=$((h * 30 / 100))

    adb_swipe "$cx" "$y_start" "$cx" "$y_end" 300
}

# Scroll up (swipe down gesture).
adb_scroll_up() {
    local screen_info
    screen_info="$(_adb_exec shell wm size 2>/dev/null | grep -oP '\d+x\d+' | tail -1)"
    local w h
    w="${screen_info%x*}"
    h="${screen_info#*x}"

    local cx=$((w / 2))
    local y_start=$((h * 30 / 100))
    local y_end=$((h * 70 / 100))

    adb_swipe "$cx" "$y_start" "$cx" "$y_end" 300
}

# Type text on device.
adb_type() {
    local text="$1"
    # ADB input text needs spaces escaped
    local escaped="${text// /%s}"
    _adb_exec shell input text "$escaped" >/dev/null
}

# Press key by keycode name or number.
# Common: BACK=4, HOME=3, ENTER=66, TAB=61, DEL=67
adb_key() {
    local key="$1"
    case "$key" in
        back|BACK)    _adb_exec shell input keyevent 4 >/dev/null ;;
        home|HOME)    _adb_exec shell input keyevent 3 >/dev/null ;;
        enter|ENTER)  _adb_exec shell input keyevent 66 >/dev/null ;;
        tab|TAB)      _adb_exec shell input keyevent 61 >/dev/null ;;
        delete|DEL)   _adb_exec shell input keyevent 67 >/dev/null ;;
        recent|RECENT) _adb_exec shell input keyevent 187 >/dev/null ;;
        menu|MENU)    _adb_exec shell input keyevent 82 >/dev/null ;;
        *)            _adb_exec shell input keyevent "$key" >/dev/null ;;
    esac
}

# ─── UI Hierarchy ───────────────────────────────────────────────────────────

# Dump UI hierarchy to local file. Returns path.
adb_hierarchy() {
    local output="${1:-/tmp/android-hierarchy-$(date +%s).xml}"
    local device_path="/sdcard/savia-hierarchy.xml"

    _adb_exec shell uiautomator dump "$device_path" >/dev/null 2>&1
    _adb_exec pull "$device_path" "$output" >/dev/null 2>&1
    _adb_exec shell rm "$device_path" 2>/dev/null

    if [[ -f "$output" ]]; then
        echo "$output"
    else
        echo "ERROR: Hierarchy dump failed" >&2
        return 1
    fi
}

# Find element bounds by resource-id. Returns "x1,y1,x2,y2" or empty.
adb_find_by_id() {
    local resource_id="$1"
    local hierarchy_file
    hierarchy_file="$(adb_hierarchy /tmp/_hierarchy_tmp.xml)"

    if [[ ! -f "$hierarchy_file" ]]; then
        return 1
    fi

    # Extract bounds attribute for matching resource-id
    local bounds
    bounds="$(grep -oP "resource-id=\"[^\"]*${resource_id}[^\"]*\"[^>]*bounds=\"\[\K[0-9,]+\]\[[0-9,]+\]" "$hierarchy_file" | head -1 || true)"

    if [[ -z "$bounds" ]]; then
        rm -f "$hierarchy_file"
        return 1
    fi

    # Parse [x1,y1][x2,y2] format
    local x1 y1 x2 y2
    x1="$(echo "$bounds" | grep -oP '^\d+')"
    y1="$(echo "$bounds" | grep -oP '(?<=,)\d+(?=\])'  | head -1)"
    x2="$(echo "$bounds" | grep -oP '(?<=\[)\d+' | tail -1)"
    y2="$(echo "$bounds" | grep -oP '\d+(?=\]$)')"

    rm -f "$hierarchy_file"
    echo "$x1,$y1,$x2,$y2"
}

# Find element bounds by text content. Returns "x1,y1,x2,y2" or empty.
adb_find_by_text() {
    local text="$1"
    local hierarchy_file
    hierarchy_file="$(adb_hierarchy /tmp/_hierarchy_tmp.xml)"

    if [[ ! -f "$hierarchy_file" ]]; then
        return 1
    fi

    local bounds
    bounds="$(grep -oP "text=\"${text}\"[^>]*bounds=\"\[\K[0-9,]+\]\[[0-9,]+\]" "$hierarchy_file" | head -1 || true)"

    if [[ -z "$bounds" ]]; then
        rm -f "$hierarchy_file"
        return 1
    fi

    local x1 y1 x2 y2
    x1="$(echo "$bounds" | grep -oP '^\d+')"
    y1="$(echo "$bounds" | grep -oP '(?<=,)\d+(?=\])'  | head -1)"
    x2="$(echo "$bounds" | grep -oP '(?<=\[)\d+' | tail -1)"
    y2="$(echo "$bounds" | grep -oP '\d+(?=\]$)')"

    rm -f "$hierarchy_file"
    echo "$x1,$y1,$x2,$y2"
}

# Tap on element by resource-id (finds center of bounds).
adb_tap_id() {
    local resource_id="$1"
    local bounds
    bounds="$(adb_find_by_id "$resource_id")"

    if [[ -z "$bounds" ]]; then
        echo "ERROR: Element not found: $resource_id" >&2
        return 1
    fi

    IFS=',' read -r x1 y1 x2 y2 <<< "$bounds"
    local cx=$(( (x1 + x2) / 2 ))
    local cy=$(( (y1 + y2) / 2 ))

    adb_tap "$cx" "$cy"
}

# Tap on element by text content.
adb_tap_text() {
    local text="$1"
    local bounds
    bounds="$(adb_find_by_text "$text")"

    if [[ -z "$bounds" ]]; then
        echo "ERROR: Element not found with text: $text" >&2
        return 1
    fi

    IFS=',' read -r x1 y1 x2 y2 <<< "$bounds"
    local cx=$(( (x1 + x2) / 2 ))
    local cy=$(( (y1 + y2) / 2 ))

    adb_tap "$cx" "$cy"
}

# ─── Logcat & Debugging ────────────────────────────────────────────────────

# Clear logcat buffer.
adb_logcat_clear() {
    _adb_exec logcat -c 2>/dev/null
}

# Get error-level logs for last N seconds. Returns log text.
adb_logcat_errors() {
    local seconds="${1:-30}"
    local package="${2:-}"

    local filter=""
    if [[ -n "$package" ]]; then
        filter="--pid=$(_adb_exec shell pidof "$package" 2>/dev/null | tr -d '\r' || echo "0")"
    fi

    # shellcheck disable=SC2086
    _adb_exec logcat -d -t "${seconds}.0" $filter "*:E" 2>/dev/null || true
}

# Get all logs for last N seconds.
adb_logcat_recent() {
    local seconds="${1:-10}"
    _adb_exec logcat -d -t "${seconds}.0" 2>/dev/null || true
}

# Search logcat for crash patterns. Returns structured output.
adb_detect_crash() {
    local seconds="${1:-60}"
    local logs
    logs="$(adb_logcat_errors "$seconds")"

    local has_crash=false
    local crash_lines=""

    # Look for common crash indicators
    if echo "$logs" | grep -qiE "FATAL EXCEPTION|AndroidRuntime|Process.*has died|ANR in"; then
        has_crash=true
        crash_lines="$(echo "$logs" | grep -iE "FATAL EXCEPTION|AndroidRuntime|Process.*has died|ANR in|Caused by|at com\." | head -30)"
    fi

    if $has_crash; then
        echo "CRASH_DETECTED"
        echo "---"
        echo "$crash_lines"
    else
        echo "NO_CRASH"
    fi
}

# Get memory info for a package.
adb_meminfo() {
    local package="$1"
    _adb_exec shell dumpsys meminfo "$package" 2>/dev/null | head -30
}

# ─── Convenience Orchestration ──────────────────────────────────────────────

# Full debug snapshot: screenshot + hierarchy + recent logs.
# Returns paths to all captured files.
adb_snapshot() {
    local prefix="${1:-/tmp/android-snapshot-$(date +%s)}"

    adb_auto_select || return 1

    local screenshot_path="${prefix}-screen.png"
    local hierarchy_path="${prefix}-hierarchy.xml"
    local logcat_path="${prefix}-logcat.txt"

    adb_screenshot "$screenshot_path" >/dev/null 2>&1
    adb_hierarchy "$hierarchy_path" >/dev/null 2>&1
    adb_logcat_recent 30 > "$logcat_path" 2>/dev/null

    printf '{"screenshot":"%s","hierarchy":"%s","logcat":"%s"}' \
        "$screenshot_path" "$hierarchy_path" "$logcat_path"
}

# Wait for element to appear (polling). Returns 0 if found, 1 if timeout.
adb_wait_for_text() {
    local text="$1"
    local timeout="${2:-10}"
    local interval="${3:-1}"
    local elapsed=0

    while (( elapsed < timeout )); do
        if adb_find_by_text "$text" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    echo "TIMEOUT: Element with text '$text' not found after ${timeout}s" >&2
    return 1
}

# Wait for element by resource-id. Returns 0 if found, 1 if timeout.
adb_wait_for_id() {
    local resource_id="$1"
    local timeout="${2:-10}"
    local interval="${3:-1}"
    local elapsed=0

    while (( elapsed < timeout )); do
        if adb_find_by_id "$resource_id" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    echo "TIMEOUT: Element '$resource_id' not found after ${timeout}s" >&2
    return 1
}

# ─── Self-test ──────────────────────────────────────────────────────────────

# Run basic self-test to verify ADB setup.
adb_selftest() {
    echo "=== ADB Wrapper Self-Test ==="

    echo -n "1. ADB binary: "
    if adb_find_binary >/dev/null 2>&1; then
        echo "OK ($(adb_find_binary))"
    else
        echo "FAIL"
        return 1
    fi

    echo -n "2. Device connected: "
    if adb_auto_select 2>/dev/null; then
        echo "OK ($ADB_DEVICE)"
    else
        echo "FAIL (no device)"
        return 1
    fi

    echo -n "3. Device info: "
    local info
    info="$(adb_device_info 2>/dev/null)"
    if [[ -n "$info" ]]; then
        echo "OK"
        echo "   $info"
    else
        echo "FAIL"
        return 1
    fi

    echo -n "4. Screenshot: "
    local ss
    ss="$(adb_screenshot /tmp/_selftest_screen.png 2>/dev/null)"
    if [[ -f "$ss" ]]; then
        local size
        size="$(stat -c%s "$ss" 2>/dev/null || echo "0")"
        echo "OK (${size} bytes)"
        rm -f "$ss"
    else
        echo "FAIL"
    fi

    echo -n "5. Hierarchy dump: "
    local hier
    hier="$(adb_hierarchy /tmp/_selftest_hier.xml 2>/dev/null)"
    if [[ -f "$hier" ]]; then
        local lines
        lines="$(wc -l < "$hier")"
        echo "OK (${lines} lines)"
        rm -f "$hier"
    else
        echo "FAIL"
    fi

    echo -n "6. Logcat: "
    local logs
    logs="$(adb_logcat_recent 5 2>/dev/null)"
    if [[ -n "$logs" ]]; then
        local log_lines
        log_lines="$(echo "$logs" | wc -l)"
        echo "OK (${log_lines} lines)"
    else
        echo "FAIL (empty)"
    fi

    echo -n "7. Security classification: "
    local s1 s2 s3
    s1="$(adb_classify "shell screencap -p /sdcard/test.png")"
    s2="$(adb_classify "install /tmp/app.apk")"
    s3="$(adb_classify "shell rm -rf /data")"
    if [[ "$s1" == "safe" && "$s2" == "risky" && "$s3" == "blocked" ]]; then
        echo "OK (safe/risky/blocked)"
    else
        echo "FAIL ($s1/$s2/$s3)"
    fi

    echo "=== Self-Test Complete ==="
}
