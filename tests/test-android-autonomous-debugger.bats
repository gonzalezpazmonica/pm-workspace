#!/usr/bin/env bats
# BATS tests for the android-autonomous-debugger skill:
#   scripts/adb-run.sh (single-command runner) + scripts/lib/adb-wrapper.sh.
# No hardware: a fake `adb` (written in setup) logs every call and answers
# from files in $FAKE_ADB_DIR. The real adb and gradle are never executed.
# Ref: .claude/skills/android-autonomous-debugger/SKILL.md
# Ref: docs/rules/domain/autonomous-safety.md

SCRIPT="scripts/adb-run.sh"
WRAPPER="scripts/lib/adb-wrapper.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMPDIR="$(mktemp -d)"
  export TMPDIR
  export FAKE_ADB_DIR="$TMPDIR/fake"
  mkdir -p "$FAKE_ADB_DIR" "$TMPDIR/bin"
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  export ADB_PATH="$TMPDIR/bin/adb"
  export ADB_RETRIES=1
  unset ADB_DEVICE
  _write_fake_adb "$ADB_PATH"
  printf 'List of devices attached\nSER1\tdevice usb:1-1 product:p model:Pixel_8 device:shiba transport_id:3\n' \
    > "$FAKE_ADB_DIR/devices"
  : > "$FAKE_ADB_DIR/calls.log"
}

teardown() {
  rm -rf "$TMPDIR"
}

# Fake adb: logs "ARGS [a] [b] ..." per call; emulates the device shell with
# `sh -c` for `input text`, so an unescaped payload really executes.
_write_fake_adb() {
  cat > "$1" <<'FAKE'
#!/usr/bin/env bash
F="${FAKE_ADB_DIR:?}"
{ printf '%s' "ARGS"; for a in "$@"; do printf ' [%s]' "$a"; done; printf '\n'; } >> "$F/calls.log"
args=("$@")
if [[ "${args[0]:-}" == "-s" ]]; then args=("${args[@]:2}"); fi
if [[ -f "$F/fail-all" ]]; then echo "error: device offline" >&2; exit 1; fi
case "${args[0]:-}" in
  devices)
    if [[ "${args[1]:-}" == "-l" ]]; then cat "$F/devices"
    else awk '/^List of devices/ || /^\*/ {print; next} NF {print $1 "\t" $2}' "$F/devices"; fi
    exit 0 ;;
  install|uninstall) cat "$F/${args[0]}.out" 2>/dev/null; exit "$(cat "$F/${args[0]}.rc" 2>/dev/null || echo 0)" ;;
  pull)
    echo "${args[2]}" >> "$F/pull-dst.log"
    case "${args[1]}" in
      *.png) [[ -f "$F/screen.png" ]] || { echo "remote object does not exist" >&2; exit 1; }; cp "$F/screen.png" "${args[2]}" ;;
      *.xml) [[ -f "$F/hierarchy.xml" ]] || { echo "remote object does not exist" >&2; exit 1; }; cp "$F/hierarchy.xml" "${args[2]}" ;;
    esac
    exit 0 ;;
  logcat)
    [[ " ${args[*]} " == *" -c "* ]] && exit 0
    [[ -f "$F/logcat-fail" ]] && { echo "error: closed" >&2; exit 1; }
    cat "$F/logcat" 2>/dev/null; exit 0 ;;
  shell)
    cmd="${args[*]:1}"
    case "$cmd" in
      "date +%s") [[ -f "$F/date-fail" ]] && exit 1; echo "1700000000" ;;
      "getprop ro.build.version.release") echo "14" ;;
      "getprop ro.build.version.sdk") echo "34" ;;
      "getprop ro.product.model") echo "Pixel \"8\"" ;;
      "getprop ro.product.manufacturer") echo "Google" ;;
      "wm size") cat "$F/wm_size" 2>/dev/null || echo "Physical size: 1080x2400" ;;
      "wm density") echo "Physical density: 420" ;;
      pidof*) [[ -f "$F/pidof" ]] || exit 1; cat "$F/pidof" ;;
      "pm list packages"*) cat "$F/packages" 2>/dev/null ;;
      "input text "*) sh -c "printf '%s' ${cmd#input text }" > "$F/typed" ;;
      *) exit "$(cat "$F/shell.rc" 2>/dev/null || echo 0)" ;;
    esac
    exit 0 ;;
esac
exit 0
FAKE
  chmod +x "$1"
}

_hierarchy() {
  cat > "$FAKE_ADB_DIR/hierarchy.xml" <<'XML'
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?><hierarchy rotation="0"><node index="0" text="Conectar (beta)" resource-id="com.x:id/login_button_secondary" class="android.widget.Button" bounds="[0,0][100,100]" /><node index="1" text="Conectar" resource-id="com.x:id/login_button" class="android.widget.Button" bounds="[200,300][400,500]" /><node index="2" text="T&amp;C" resource-id="com.x:id/tc" class="android.widget.TextView" bounds="[10,10][30,50]" /></hierarchy>
XML
}

_calls() { cat "$FAKE_ADB_DIR/calls.log"; }

# ── Contract of the runner ─────────────────────────────────

@test "runner: uses set -uo pipefail and passes bash -n" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [ "$output" -ge 1 ]
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
  run bash -n "$WRAPPER"
  [ "$status" -eq 0 ]
}

@test "runner: no arguments is an error, --help exits 0 with usage" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No commands specified"* ]]
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "runner: shell injection after a function is rejected and never executed" {
  run bash "$SCRIPT" "adb_auto_select; touch $TMPDIR/pwned"
  [ "$status" -ne 0 ]
  [ ! -e "$TMPDIR/pwned" ]
  run bash "$SCRIPT" "adb_tap 1 \$(touch $TMPDIR/pwned2)"
  [ "$status" -ne 0 ]
  [ ! -e "$TMPDIR/pwned2" ]
}

@test "runner: rejects anything that is not an adb-wrapper function" {
  run bash "$SCRIPT" "touch $TMPDIR/x"
  [ "$status" -ne 0 ]
  [[ "$output" == *"REJECTED"* ]]
  [ ! -e "$TMPDIR/x" ]
  run bash "$SCRIPT" "_adb_exec shell reboot"
  [ "$status" -ne 0 ]
  [[ "$output" == *"REJECTED"* ]]
}

@test "runner: invalid unmatched quote is rejected" {
  run bash "$SCRIPT" "adb_tap_text 'Conectar"
  [ "$status" -ne 0 ]
  [[ "$output" == *"REJECTED"* ]]
}

@test "runner: a command with a missing argument fails alone, the rest still run" {
  run bash "$SCRIPT" adb_install adb_devices
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAILED: adb_install"* ]]
  [[ "$output" == *'"serial":"SER1"'* ]]
  [[ "$output" == *"1 command(s) failed"* ]]
}

@test "runner: device chosen by adb_auto_select persists to later commands" {
  run bash "$SCRIPT" adb_auto_select "adb_tap 500 900"
  [ "$status" -eq 0 ]
  run _calls
  [[ "$output" == *"ARGS [-s] [SER1] [shell] [input] [tap] [500] [900]"* ]]
}

# ── Binary and device discovery ────────────────────────────

@test "binary: invalid ADB_PATH errors instead of falling back to another adb" {
  cp "$ADB_PATH" "$TMPDIR/bin/other"
  mkdir -p "$TMPDIR/pathbin"
  mv "$TMPDIR/bin/other" "$TMPDIR/pathbin/adb"
  ADB_PATH="$TMPDIR/missing/adb" PATH="$TMPDIR/pathbin:$PATH" run bash "$SCRIPT" adb_auto_select
  [ "$status" -ne 0 ]
  [[ "$output" == *"ADB_PATH"* ]]
  run _calls
  [ -z "$output" ]
}

@test "binary: ADB_PATH with spaces works for every call path" {
  mkdir -p "$TMPDIR/my sdk"
  cp "$ADB_PATH" "$TMPDIR/my sdk/adb"
  ADB_PATH="$TMPDIR/my sdk/adb" run bash "$SCRIPT" adb_auto_select "adb_tap 1 2" adb_devices
  [ "$status" -eq 0 ]
  [[ "$output" == *'"serial":"SER1"'* ]]
}

@test "devices: daemon banner lines are not reported as devices" {
  printf '* daemon not running; starting now at tcp:5037\n* daemon started successfully\nList of devices attached\nSER1\tdevice model:Pixel_8 device:shiba transport_id:3\n' \
    > "$FAKE_ADB_DIR/devices"
  run bash "$SCRIPT" adb_devices
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert [x["serial"] for x in d]==["SER1"], d; assert d[0]["model"]=="Pixel_8"'
}

@test "devices: empty device list yields an empty JSON array" {
  printf 'List of devices attached\n\n' > "$FAKE_ADB_DIR/devices"
  run bash "$SCRIPT" adb_devices
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; assert json.load(sys.stdin)==[]'
}

@test "auto_select: zero, unauthorized-only and multiple devices are errors" {
  printf 'List of devices attached\n' > "$FAKE_ADB_DIR/devices"
  run bash "$SCRIPT" adb_auto_select
  [ "$status" -ne 0 ]
  [[ "$output" == *"No Android devices"* ]]
  printf 'List of devices attached\nSER9\tunauthorized\n' > "$FAKE_ADB_DIR/devices"
  run bash "$SCRIPT" adb_auto_select
  [ "$status" -ne 0 ]
  printf 'List of devices attached\nA\tdevice\nB\tdevice\n' > "$FAKE_ADB_DIR/devices"
  run bash "$SCRIPT" adb_auto_select
  [ "$status" -ne 0 ]
  [[ "$output" == *"Multiple devices"* ]]
}

@test "device_info: valid JSON with escaped quotes from getprop" {
  run bash "$SCRIPT" adb_device_info
  [ "$status" -eq 0 ]
  echo "${lines[-1]}" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["model"]=="Pixel \"8\"", d; assert d["screen"]=="1080x2400"; assert d["sdk"]=="34"'
}

@test "device_info: offline device fails instead of reporting error text as data" {
  export ADB_DEVICE=SER1
  touch "$FAKE_ADB_DIR/fail-all"
  run bash "$SCRIPT" adb_device_info
  [ "$status" -ne 0 ]
  [[ "$output" != *'"android":"error'* ]]
}

@test "retries: ADB_RETRIES=0 still runs the command once; =2 attempts twice" {
  ADB_RETRIES=0 ADB_DEVICE=SER1 run bash "$SCRIPT" "adb_tap 1 2"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'input\] \[tap' "$FAKE_ADB_DIR/calls.log")" -eq 1 ]
  : > "$FAKE_ADB_DIR/calls.log"
  touch "$FAKE_ADB_DIR/fail-all"
  ADB_RETRIES=2 ADB_DEVICE=SER1 run bash "$SCRIPT" "adb_tap 1 2"
  [ "$status" -ne 0 ]
  [ "$(grep -c 'input\] \[tap' "$FAKE_ADB_DIR/calls.log")" -eq 2 ]
}

# ── Input validation: nothing reaches the device shell unescaped ──

@test "type: shell metacharacters are escaped and the payload never runs" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_type 'a;touch $TMPDIR/pwned&b'"
  [ "$status" -eq 0 ]
  [ ! -e "$TMPDIR/pwned" ]
  # the device shell sees the literal text; `input` itself maps %s to a space
  [ "$(cat "$FAKE_ADB_DIR/typed")" = "a;touch%s$TMPDIR/pwned&b" ]
}

@test "type: spaces become %s and quotes survive" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_type \"it's ok\""
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_ADB_DIR/typed")" = "it's%sok" ]
}

@test "tap/swipe/key/launch: invalid arguments are rejected without calling adb" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_tap '1;reboot' 2"
  [ "$status" -ne 0 ]
  run bash "$SCRIPT" "adb_swipe 1 2 3 x"
  [ "$status" -ne 0 ]
  run bash "$SCRIPT" "adb_key 'back;reboot'"
  [ "$status" -ne 0 ]
  run bash "$SCRIPT" "adb_launch 'com.x;reboot'"
  [ "$status" -ne 0 ]
  run bash "$SCRIPT" "adb_meminfo 'com.x|sh'"
  [ "$status" -ne 0 ]
  run _calls
  [ -z "$output" ]
}

@test "key: names map to keycodes" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_key back" "adb_key ENTER" "adb_key 24"
  [ "$status" -eq 0 ]
  run _calls
  [[ "$output" == *"[keyevent] [4]"* ]]
  [[ "$output" == *"[keyevent] [66]"* ]]
  [[ "$output" == *"[keyevent] [24]"* ]]
}

# ── Element finding ────────────────────────────────────────

@test "tap_id: exact resource-id, not the first id containing it" {
  _hierarchy
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_tap_id login_button"
  [ "$status" -eq 0 ]
  run _calls
  [[ "$output" == *"[tap] [300] [400]"* ]]
  [[ "$output" != *"[tap] [50] [50]"* ]]
}

@test "tap_text: text with spaces and parentheses is matched literally" {
  _hierarchy
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_tap_text 'Conectar (beta)'"
  [ "$status" -eq 0 ]
  run _calls
  [[ "$output" == *"[tap] [50] [50]"* ]]
}

@test "tap_text: XML-escaped text (ampersand) is found" {
  _hierarchy
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_tap_text 'T&C'"
  [ "$status" -eq 0 ]
  run _calls
  [[ "$output" == *"[tap] [20] [30]"* ]]
}

@test "tap_text: regex metacharacters do not act as wildcards (reject C.nectar)" {
  _hierarchy
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_tap_text C.nectar"
  [ "$status" -ne 0 ]
  run grep -c '\[tap\]' "$FAKE_ADB_DIR/calls.log"
  [ "$output" -eq 0 ]
}

@test "find_by_text: temp hierarchy lives under TMPDIR, not a fixed /tmp path" {
  _hierarchy
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_find_by_text Conectar"
  [ "$status" -eq 0 ]
  [[ "$output" == *"200,300,400,500"* ]]
  run cat "$FAKE_ADB_DIR/pull-dst.log"
  [[ "$output" == "$TMPDIR/"* ]]
  [[ "$output" != *"/tmp/_hierarchy_tmp.xml"* ]]
}

@test "find_by_text: large hierarchy (3000 nodes) finds the last node" {
  export ADB_DEVICE=SER1
  python3 - "$FAKE_ADB_DIR/hierarchy.xml" <<'PY'
import sys
nodes = "".join(f'<node index="{i}" text="item {i}" resource-id="com.x:id/row{i}" bounds="[0,{i}][10,{i+2}]" />' for i in range(3000))
open(sys.argv[1], "w").write(f"<hierarchy>{nodes}</hierarchy>")
PY
  run bash "$SCRIPT" "adb_find_by_text 'item 2999'" "adb_find_by_id row2999"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "0,2999,10,3001" ]
  [ "${lines[1]}" = "0,2999,10,3001" ]
}

# ── Captures ───────────────────────────────────────────────

@test "screenshot: failed pull is an error even if a stale file exists" {
  export ADB_DEVICE=SER1
  echo stale > "$TMPDIR/shot.png"
  run bash "$SCRIPT" "adb_screenshot $TMPDIR/shot.png"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Screenshot failed"* ]]
}

@test "screenshot: success pulls to a path with spaces and prints it" {
  export ADB_DEVICE=SER1
  printf 'PNG' > "$FAKE_ADB_DIR/screen.png"
  mkdir -p "$TMPDIR/out dir"
  run bash "$SCRIPT" "adb_screenshot '$TMPDIR/out dir/s.png'"
  [ "$status" -eq 0 ]
  [ "$(cat "$TMPDIR/out dir/s.png")" = "PNG" ]
  [[ "$output" == *"$TMPDIR/out dir/s.png"* ]]
}

@test "hierarchy: failed dump is an error even if a stale file exists" {
  export ADB_DEVICE=SER1
  echo stale > "$TMPDIR/ui.xml"
  run bash "$SCRIPT" "adb_hierarchy $TMPDIR/ui.xml"
  [ "$status" -ne 0 ]
}

# ── Logcat and crash detection ─────────────────────────────

@test "logcat_errors: window is device-now minus N seconds, not epoch second N" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_logcat_errors 30"
  [ "$status" -eq 0 ]
  run _calls
  [[ "$output" == *"[logcat] [-d] [-t] [1699999970.000]"* ]]
  [[ "$output" != *"[30.0]"* ]]
}

@test "logcat_errors: running package filters by its first pid" {
  export ADB_DEVICE=SER1
  echo "4242 4343" > "$FAKE_ADB_DIR/pidof"
  run bash "$SCRIPT" "adb_logcat_errors 10 com.savia.mobile"
  [ "$status" -eq 0 ]
  run _calls
  [[ "$output" == *"[--pid=4242] [*:E]"* ]]
}

@test "logcat_errors: dead package (crash case) warns and shows unfiltered errors, no --pid=0" {
  export ADB_DEVICE=SER1
  echo "E AndroidRuntime: FATAL EXCEPTION: main" > "$FAKE_ADB_DIR/logcat"
  run bash "$SCRIPT" "adb_logcat_errors 60 com.savia.mobile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"FATAL EXCEPTION"* ]]
  [[ "$output" == *"not running"* ]]
  run _calls
  [[ "$output" != *"--pid=0"* ]]
}

@test "logcat_errors: invalid seconds is rejected" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_logcat_errors abc"
  [ "$status" -ne 0 ]
}

@test "detect_crash: FATAL EXCEPTION is reported, clean log is NO_CRASH" {
  export ADB_DEVICE=SER1
  printf 'E AndroidRuntime: FATAL EXCEPTION: main\nE AndroidRuntime: Caused by: java.lang.NullPointerException\nE AndroidRuntime: \tat com.savia.Main.onCreate(Main.kt:12)\n' \
    > "$FAKE_ADB_DIR/logcat"
  run bash "$SCRIPT" "adb_detect_crash 60"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "CRASH_DETECTED" ]
  [[ "$output" == *"NullPointerException"* ]]
  echo "I ActivityManager: Start proc 123:com.savia.mobile" > "$FAKE_ADB_DIR/logcat"
  run bash "$SCRIPT" "adb_detect_crash 60"
  [ "$status" -eq 0 ]
  [ "$output" = "NO_CRASH" ]
}

@test "detect_crash: logcat failure is LOGCAT_ERROR rc!=0, never NO_CRASH (fail closed)" {
  export ADB_DEVICE=SER1
  echo "I ActivityManager: Start proc 123:com.savia.mobile" > "$FAKE_ADB_DIR/logcat"
  touch "$FAKE_ADB_DIR/logcat-fail"
  run bash "$SCRIPT" "adb_detect_crash 60"
  [ "$status" -ne 0 ]
  [[ "$output" == *"LOGCAT_ERROR"* ]]
  [[ "$output" != *"NO_CRASH"* ]]
}

@test "detect_crash: empty logcat is NO_LOGS rc!=0, never NO_CRASH" {
  export ADB_DEVICE=SER1
  : > "$FAKE_ADB_DIR/logcat"
  run bash "$SCRIPT" "adb_detect_crash 60"
  [ "$status" -ne 0 ]
  [[ "$output" == *"NO_LOGS"* ]]
  [[ "$output" != *"NO_CRASH"* ]]
}

@test "detect_crash: 'Process has died' at level I is detected" {
  export ADB_DEVICE=SER1
  echo "I ActivityManager: Process com.savia.mobile (pid 4242) has died: fg TOP" > "$FAKE_ADB_DIR/logcat"
  run bash "$SCRIPT" "adb_detect_crash 60"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "CRASH_DETECTED" ]
}

@test "logcat_errors/recent: logcat or device clock failure returns error" {
  export ADB_DEVICE=SER1
  touch "$FAKE_ADB_DIR/logcat-fail"
  run bash "$SCRIPT" "adb_logcat_errors 30"
  [ "$status" -ne 0 ]
  run bash "$SCRIPT" "adb_logcat_recent 30"
  [ "$status" -ne 0 ]
  mv "$FAKE_ADB_DIR/logcat-fail" "$TMPDIR/unused"
  touch "$FAKE_ADB_DIR/date-fail"
  : > "$FAKE_ADB_DIR/calls.log"
  run bash "$SCRIPT" "adb_logcat_errors 30"
  [ "$status" -ne 0 ]
  [[ "$output" == *"device clock"* ]]
  run grep -c '\[logcat\] \[-d\]' "$FAKE_ADB_DIR/calls.log"
  [ "$output" -eq 0 ]
}

@test "snapshot: failed logcat is counted (failed:1) and returns non-zero" {
  export ADB_DEVICE=SER1
  printf 'PNG' > "$FAKE_ADB_DIR/screen.png"
  _hierarchy
  echo "I x: y" > "$FAKE_ADB_DIR/logcat"
  run bash "$SCRIPT" "adb_snapshot $TMPDIR/snap"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"failed":0'* ]]
  touch "$FAKE_ADB_DIR/logcat-fail"
  run bash "$SCRIPT" "adb_snapshot $TMPDIR/snap2"
  [ "$status" -ne 0 ]
  [[ "$output" == *'"failed":1'* ]]
}

# ── Packages ───────────────────────────────────────────────

@test "is_installed: exact package match, a prefix is not installed" {
  export ADB_DEVICE=SER1
  printf 'package:com.savia.mobile\r\n' > "$FAKE_ADB_DIR/packages"
  run bash "$SCRIPT" "adb_is_installed com.savia.mobile"
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" "adb_is_installed com.savia"
  [ "$status" -ne 0 ]
}

@test "install: missing APK and adb failure both return non-zero" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_install $TMPDIR/none.apk"
  [ "$status" -ne 0 ]
  [[ "$output" == *"APK not found"* ]]
  touch "$TMPDIR/app.apk"
  echo "Failure [INSTALL_FAILED_VERSION_DOWNGRADE]" > "$FAKE_ADB_DIR/install.out"
  echo 1 > "$FAKE_ADB_DIR/install.rc"
  run bash "$SCRIPT" "adb_install $TMPDIR/app.apk"
  [ "$status" -ne 0 ]
  [[ "$output" == *"INSTALL_FAILED"* ]]
}

# ── Scrolling and waiting ──────────────────────────────────

@test "scroll_down: unknown screen size fails and sends no swipe" {
  export ADB_DEVICE=SER1
  echo "" > "$FAKE_ADB_DIR/wm_size"
  run bash "$SCRIPT" adb_scroll_down
  [ "$status" -ne 0 ]
  run grep -c 'swipe' "$FAKE_ADB_DIR/calls.log"
  [ "$output" -eq 0 ]
}

@test "scroll_down: uses override size with integer coords under es_ES locale" {
  export ADB_DEVICE=SER1
  printf 'Physical size: 1080x2400\nOverride size: 720x1600\n' > "$FAKE_ADB_DIR/wm_size"
  LC_ALL=es_ES.UTF-8 run bash "$SCRIPT" adb_scroll_down
  [ "$status" -eq 0 ]
  run _calls
  [[ "$output" == *"[swipe] [360] [1120] [360] [480] [300]"* ]]
}

@test "wait_for_text: zero interval is rejected instead of looping forever" {
  _hierarchy
  export ADB_DEVICE=SER1
  run timeout 10 bash "$SCRIPT" "adb_wait_for_text Nope 2 0"
  [ "$status" -ne 124 ]
  [ "$status" -ne 0 ]
  [[ "$output" == *"interval must be an integer >= 1"* ]]
  run _calls
  [ -z "$output" ]
}

@test "wait_for_text: found returns 0, absent times out with an error" {
  _hierarchy
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_wait_for_text Conectar 2"
  [ "$status" -eq 0 ]
  run timeout 10 bash "$SCRIPT" "adb_wait_for_id nope 1"
  [ "$status" -eq 1 ]
  [[ "$output" == *"TIMEOUT"* ]]
}

# ── Security classification ────────────────────────────────

@test "classify: blocked, risky and safe without false positives on 'root' substrings" {
  run bash -c "source $WRAPPER; adb_classify shell rm -rf /data; adb_classify root; adb_classify shell su -c id; adb_classify install /x.apk; adb_classify pull /sdcard/rootfs.img /tmp/r; adb_classify shell screencap -p /s.png"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "blocked" ]
  [ "${lines[1]}" = "blocked" ]
  [ "${lines[2]}" = "blocked" ]
  [ "${lines[3]}" = "risky" ]
  [ "${lines[4]}" = "safe" ]
  [ "${lines[5]}" = "safe" ]
}

# ── Review fixes (maker-checker HOLD) ──────────────────────

@test "uninstall: offline device fails; not-installed package is idempotent" {
  export ADB_DEVICE=SER1
  touch "$FAKE_ADB_DIR/fail-all"
  run bash "$SCRIPT" "adb_uninstall com.savia.mobile"
  [ "$status" -ne 0 ]
  mv "$FAKE_ADB_DIR/fail-all" "$TMPDIR/unused"
  echo 1 > "$FAKE_ADB_DIR/uninstall.rc"
  printf 'package:com.other.app\n' > "$FAKE_ADB_DIR/packages"
  run bash "$SCRIPT" "adb_uninstall com.savia.mobile"
  [ "$status" -eq 0 ]
  printf 'package:com.savia.mobile\n' > "$FAKE_ADB_DIR/packages"
  run bash "$SCRIPT" "adb_uninstall com.savia.mobile"
  [ "$status" -ne 0 ]
  [[ "$output" == *"still installed"* ]]
}

@test "injection: invalid activity, screenrecord path and uninstall package are rejected" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_launch com.x '.Main;reboot'"
  [ "$status" -ne 0 ]
  run bash "$SCRIPT" "adb_record_start '/sdcard/a.mp4;reboot' 5"
  [ "$status" -ne 0 ]
  run bash "$SCRIPT" "adb_uninstall 'com.x;reboot'"
  [ "$status" -ne 0 ]
  run _calls
  [ -z "$output" ]
}

@test "type: dollar, backtick and redirection reach the device as literal text" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_type 'x\$HOME\`id\`>$TMPDIR/out'"
  [ "$status" -eq 0 ]
  [ ! -e "$TMPDIR/out" ]
  [ "$(cat "$FAKE_ADB_DIR/typed")" = "x\$HOME\`id\`>$TMPDIR/out" ]
}

@test "runner: an abort inside one call (unbound variable) does not stop the batch" {
  adb_boom() { echo "$undefined_variable_for_test"; }
  export -f adb_boom
  run bash "$SCRIPT" adb_boom adb_devices
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAILED: adb_boom"* ]]
  [[ "$output" == *'"serial":"SER1"'* ]]
}

@test "runner: extra arguments are rejected, the call is not executed" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_tap 1 2 ; touch $TMPDIR/zz"
  [ "$status" -ne 0 ]
  [[ "$output" == *"REJECTED"* ]]
  [ ! -e "$TMPDIR/zz" ]
  run _calls
  [ -z "$output" ]
}

@test "integers: leading zero is rejected with a clear message, not a bash error" {
  export ADB_DEVICE=SER1
  run bash "$SCRIPT" "adb_logcat_errors 08"
  [ "$status" -ne 0 ]
  [[ "$output" == *"non-negative integer"* ]]
  [[ "$output" != *"base"* ]]
}

@test "screenshot: failed pull keeps an existing local file intact" {
  export ADB_DEVICE=SER1
  echo precious > "$TMPDIR/keep.png"
  run bash "$SCRIPT" "adb_screenshot $TMPDIR/keep.png"
  [ "$status" -ne 0 ]
  [ "$(cat "$TMPDIR/keep.png")" = "precious" ]
}

@test "devices: adb failure is an error, not an empty list" {
  touch "$FAKE_ADB_DIR/fail-all"
  run bash "$SCRIPT" adb_devices
  [ "$status" -ne 0 ]
}

@test "selftest: a failed capture makes it fail, temp files stay under TMPDIR" {
  export ADB_DEVICE=SER1
  _hierarchy
  echo "I x: y" > "$FAKE_ADB_DIR/logcat"
  run bash "$SCRIPT" adb_selftest
  [ "$status" -ne 0 ]
  [[ "$output" == *"4. Screenshot: FAIL"* ]]
  run grep -v "^$TMPDIR/" "$FAKE_ADB_DIR/pull-dst.log"
  [ -z "$output" ]
}
