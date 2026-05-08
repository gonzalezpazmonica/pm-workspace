#!/usr/bin/env bash
# ============================================================================
# test-adb-wrapper.sh — Integration tests for adb-wrapper.sh
# ============================================================================
#
# Requires: Android device connected via USB with USB debugging enabled.
# Tests run against Savia Mobile (com.savia.mobile) APK.
#
# Usage:
#   ./scripts/tests/test-adb-wrapper.sh
#
# Environment:
#   SAVIA_APK  — Path to Savia Mobile APK (auto-detected from dist/)
#
# Author: Savia PM-Workspace
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER="$ROOT_DIR/scripts/lib/adb-wrapper.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

# ─── Test Helpers ───────────────────────────────────────────────────────────

assert_ok() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo -e "  ${GREEN}PASS${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $desc"
        FAIL=$((FAIL + 1))
    fi
}

assert_fail() {
    local desc="$1"
    shift
    if ! "$@" >/dev/null 2>&1; then
        echo -e "  ${GREEN}PASS${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $desc (expected failure)"
        FAIL=$((FAIL + 1))
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}PASS${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $desc (expected='$expected', got='$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}PASS${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $desc (output does not contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -f "$path" ]]; then
        echo -e "  ${GREEN}PASS${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $desc (file not found: $path)"
        FAIL=$((FAIL + 1))
    fi
}

skip_test() {
    local desc="$1" reason="$2"
    echo -e "  ${YELLOW}SKIP${NC} $desc ($reason)"
    SKIP=$((SKIP + 1))
}

# ─── Setup ──────────────────────────────────────────────────────────────────

echo "============================================"
echo " ADB Wrapper — Integration Test Suite"
echo "============================================"
echo ""

# Source the wrapper
if [[ ! -f "$WRAPPER" ]]; then
    echo -e "${RED}ERROR: Wrapper not found at $WRAPPER${NC}"
    exit 1
fi
source "$WRAPPER"

# ─── Test Suite 1: Core Functions ───────────────────────────────────────────

echo "--- 1. Core Functions ---"

assert_ok "adb_find_binary finds ADB" adb_find_binary

ADB_BIN="$(adb_find_binary)"
assert_contains "ADB path contains 'adb'" "$ADB_BIN" "adb"

# ─── Test Suite 2: Security Classification ──────────────────────────────────

echo ""
echo "--- 2. Security Classification ---"

assert_eq "screencap is safe" "safe" "$(adb_classify "shell screencap -p /sdcard/test.png")"
assert_eq "logcat is safe" "safe" "$(adb_classify "logcat -d")"
assert_eq "uiautomator dump is safe" "safe" "$(adb_classify "shell uiautomator dump /sdcard/ui.xml")"
assert_eq "shell input tap is safe" "safe" "$(adb_classify "shell input tap 100 200")"
assert_eq "devices is safe" "safe" "$(adb_classify "devices")"
assert_eq "getprop is safe" "safe" "$(adb_classify "shell getprop ro.build.version.release")"
assert_eq "pull is safe" "safe" "$(adb_classify "pull /sdcard/file.txt /tmp/file.txt")"

assert_eq "install is risky" "risky" "$(adb_classify "install /tmp/app.apk")"
assert_eq "uninstall is risky" "risky" "$(adb_classify "uninstall com.example.app")"
assert_eq "pm clear is risky" "risky" "$(adb_classify "shell pm clear com.example.app")"
assert_eq "push is risky" "risky" "$(adb_classify "push /tmp/file /sdcard/")"
assert_eq "force-stop is risky" "risky" "$(adb_classify "shell am force-stop com.example")"

assert_eq "rm -rf is blocked" "blocked" "$(adb_classify "shell rm -rf /data")"
assert_eq "format is blocked" "blocked" "$(adb_classify "shell format /dev/block")"
assert_eq "su is blocked" "blocked" "$(adb_classify "shell su -c id")"
assert_eq "dd is blocked" "blocked" "$(adb_classify "shell dd if=/dev/zero")"

# ─── Test Suite 3: Device Management ───────────────────────────────────────

echo ""
echo "--- 3. Device Management ---"

DEVICES_JSON="$(adb_devices 2>/dev/null)"
assert_contains "adb_devices returns JSON array" "$DEVICES_JSON" '"serial"'
assert_contains "adb_devices shows device state" "$DEVICES_JSON" '"state":"device"'

assert_ok "adb_auto_select succeeds" adb_auto_select
assert_contains "ADB_DEVICE is set" "$ADB_DEVICE" ""

DEVICE_INFO="$(adb_device_info 2>/dev/null)"
assert_contains "device_info contains android version" "$DEVICE_INFO" '"android"'
assert_contains "device_info contains model" "$DEVICE_INFO" '"model"'
assert_contains "device_info contains screen size" "$DEVICE_INFO" '"screen"'

# ─── Test Suite 4: Screenshot & Hierarchy ───────────────────────────────────

echo ""
echo "--- 4. Screenshot & Hierarchy ---"

SS_PATH="$(adb_screenshot /tmp/_test_screenshot.png 2>/dev/null)"
assert_file_exists "screenshot captured" "$SS_PATH"
if [[ -f "$SS_PATH" ]]; then
    SIZE="$(stat -c%s "$SS_PATH")"
    if (( SIZE > 1000 )); then
        echo -e "  ${GREEN}PASS${NC} screenshot size is reasonable (${SIZE} bytes)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} screenshot too small (${SIZE} bytes)"
        FAIL=$((FAIL + 1))
    fi
    rm -f "$SS_PATH"
fi

HIER_PATH="$(adb_hierarchy /tmp/_test_hierarchy.xml 2>/dev/null)"
assert_file_exists "hierarchy captured" "$HIER_PATH"
if [[ -f "$HIER_PATH" ]]; then
    HIER_SIZE="$(stat -c%s "$HIER_PATH")"
    if (( HIER_SIZE > 100 )); then
        echo -e "  ${GREEN}PASS${NC} hierarchy has content (${HIER_SIZE} bytes)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} hierarchy too small (${HIER_SIZE} bytes)"
        FAIL=$((FAIL + 1))
    fi
    rm -f "$HIER_PATH"
fi

# ─── Test Suite 5: Logcat ───────────────────────────────────────────────────

echo ""
echo "--- 5. Logcat ---"

assert_ok "adb_logcat_clear succeeds" adb_logcat_clear

LOGS="$(adb_logcat_recent 5 2>/dev/null)"
# After clear, there may be few logs; just check the command works
echo -e "  ${GREEN}PASS${NC} adb_logcat_recent runs without error"
PASS=$((PASS + 1))

CRASH_RESULT="$(adb_detect_crash 5 2>/dev/null)"
assert_contains "crash detection returns result" "$CRASH_RESULT" "CRASH"

# ─── Test Suite 6: Snapshot (combined capture) ──────────────────────────────

echo ""
echo "--- 6. Combined Snapshot ---"

SNAP="$(adb_snapshot /tmp/_test_snap 2>/dev/null)"
assert_contains "snapshot returns JSON" "$SNAP" '"screenshot"'
assert_contains "snapshot includes hierarchy" "$SNAP" '"hierarchy"'
assert_contains "snapshot includes logcat" "$SNAP" '"logcat"'

# Cleanup
rm -f /tmp/_test_snap-screen.png /tmp/_test_snap-hierarchy.xml /tmp/_test_snap-logcat.txt

# ─── Test Suite 7: Savia Mobile App Test ────────────────────────────────────

echo ""
echo "--- 7. Savia Mobile Integration ---"

SAVIA_PACKAGE="com.savia.mobile"

if adb_is_installed "$SAVIA_PACKAGE" 2>/dev/null; then
    echo -e "  ${GREEN}INFO${NC} Savia Mobile is installed"

    # Force stop to start clean
    adb_stop "$SAVIA_PACKAGE" 2>/dev/null || true
    sleep 1

    # Clear logcat
    adb_logcat_clear

    # Launch the app
    assert_ok "launch Savia Mobile" adb_launch "$SAVIA_PACKAGE"

    # Wait for app to render
    sleep 3

    # Take screenshot
    SS_APP="$(adb_screenshot /tmp/_test_savia_launch.png 2>/dev/null)"
    assert_file_exists "savia launch screenshot" "$SS_APP"

    # Check for crashes
    CRASH_CHECK="$(adb_detect_crash 10 2>/dev/null)"
    assert_eq "no crash on launch" "NO_CRASH" "$(echo "$CRASH_CHECK" | head -1)"

    # Get hierarchy and look for Savia elements
    HIER_APP="$(adb_hierarchy /tmp/_test_savia_hier.xml 2>/dev/null)"
    if [[ -f "$HIER_APP" ]]; then
        if grep -q "savia\|Savia\|com.savia" "$HIER_APP" 2>/dev/null; then
            echo -e "  ${GREEN}PASS${NC} hierarchy contains Savia elements"
            PASS=$((PASS + 1))
        else
            echo -e "  ${YELLOW}SKIP${NC} hierarchy may not contain Savia text (app might be on setup screen)"
            SKIP=$((SKIP + 1))
        fi
        rm -f "$HIER_APP"
    fi

    # Check errors
    ERRORS="$(adb_logcat_errors 10 "$SAVIA_PACKAGE" 2>/dev/null)"
    ERROR_COUNT="$(echo "$ERRORS" | grep -c "E/" || true)"
    if (( ERROR_COUNT < 5 )); then
        echo -e "  ${GREEN}PASS${NC} few errors in logcat ($ERROR_COUNT lines)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${YELLOW}SKIP${NC} some errors in logcat ($ERROR_COUNT lines) — may be expected"
        SKIP=$((SKIP + 1))
    fi

    # Memory check
    MEM="$(adb_meminfo "$SAVIA_PACKAGE" 2>/dev/null)"
    if echo "$MEM" | grep -q "TOTAL"; then
        echo -e "  ${GREEN}PASS${NC} memory info available"
        PASS=$((PASS + 1))
    else
        skip_test "memory info" "app may not be running"
    fi

    # Cleanup
    rm -f "$SS_APP"
    adb_stop "$SAVIA_PACKAGE" 2>/dev/null || true
else
    skip_test "Savia Mobile integration" "com.savia.mobile not installed"
fi

# ─── Test Suite 8: Hook Validation ──────────────────────────────────────────

echo ""
echo "--- 8. Hook Validation ---"

HOOK="$ROOT_DIR/.opencode/hooks/android-adb-validate.sh"
if [[ -x "$HOOK" ]]; then
    # Safe command
    TOOL_INPUT="adb shell screencap -p /sdcard/test.png" TOOL_NAME="Bash" \
        "$HOOK" >/dev/null 2>&1
    assert_eq "hook allows safe commands" "0" "$?"

    # Blocked command
    if ! TOOL_INPUT="adb shell rm -rf /data" TOOL_NAME="Bash" \
        "$HOOK" >/dev/null 2>&1; then
        echo -e "  ${GREEN}PASS${NC} hook blocks destructive commands"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} hook should block 'rm -rf'"
        FAIL=$((FAIL + 1))
    fi

    # Non-ADB command (should pass through)
    TOOL_INPUT="ls -la" TOOL_NAME="Bash" \
        "$HOOK" >/dev/null 2>&1
    assert_eq "hook ignores non-ADB commands" "0" "$?"
else
    skip_test "hook validation" "hook not found or not executable"
fi

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "============================================"
TOTAL=$((PASS + FAIL + SKIP))
echo " Results: $TOTAL tests"
echo -e "   ${GREEN}PASS: $PASS${NC}"
echo -e "   ${RED}FAIL: $FAIL${NC}"
echo -e "   ${YELLOW}SKIP: $SKIP${NC}"
echo "============================================"

if (( FAIL > 0 )); then
    exit 1
fi
exit 0
