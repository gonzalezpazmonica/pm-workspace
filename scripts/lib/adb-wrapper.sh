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
#   ADB_RETRIES  — Max attempts per command, transient failures (default: 3, min 1)
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
    # An explicit ADB_PATH is authoritative: never fall back to another adb.
    if [[ -n "$ADB_PATH" ]]; then
        if [[ -f "$ADB_PATH" && -x "$ADB_PATH" ]]; then
            echo "$ADB_PATH"
            return 0
        fi
        echo "ERROR: ADB_PATH is not an executable file: $ADB_PATH" >&2
        return 1
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
    adb="$(adb_find_binary)" || return 1

    local -a cmd=("$adb")
    if [[ -n "$ADB_DEVICE" ]]; then
        cmd+=(-s "$ADB_DEVICE")
    fi

    local attempt=0
    local max_attempts=1
    if _adb_is_uint "$ADB_RETRIES" && (( ADB_RETRIES > 1 )); then
        max_attempts=$ADB_RETRIES
    fi
    local tmo=30
    if _adb_is_uint "$ADB_TIMEOUT" && (( ADB_TIMEOUT > 0 )); then
        tmo=$ADB_TIMEOUT
    fi
    local delay=1

    while (( attempt < max_attempts )); do
        # stderr stays on stderr: adb error text must never be parsed as data
        if timeout "$tmo" "${cmd[@]}" "$@"; then
            return 0
        fi

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
    local cmd=" $* "

    # Patterns match whole words: "pull /sdcard/rootfs.img" is not "root".
    # A pattern ending in "=" (dd if=) is a prefix of its argument.
    local pat
    for pat in "${_BLOCKED_OPERATIONS[@]}"; do
        if [[ "$cmd" == *" $pat "* || ( "$pat" == *"=" && "$cmd" == *" $pat"* ) ]]; then
            echo "blocked"
            return 0
        fi
    done

    for pat in "${_RISKY_OPERATIONS[@]}"; do
        if [[ "$cmd" == *" $pat "* ]]; then
            echo "risky"
            return 0
        fi
    done

    echo "safe"
}

# ─── Input Validation ──────────────────────────────────────────────────────
# Arguments are joined into a device-side shell command by `adb shell`, so
# anything reaching it must be validated or escaped (no injection on device).

_adb_is_uint() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

_adb_need_uint() {
    local name="$1" value="${2:-}"
    if ! _adb_is_uint "$value"; then
        echo "ERROR: $name must be a non-negative integer, got: '$value'" >&2
        return 1
    fi
}

_adb_need_package() {
    if [[ ! "${1:-}" =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$ ]]; then
        echo "ERROR: invalid package name: '${1:-}'" >&2
        return 1
    fi
}

_adb_need_arg() {
    if [[ -z "${2:-}" ]]; then
        echo "ERROR: missing argument: $1" >&2
        return 1
    fi
}

# Escape a string for JSON output.
_adb_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/}"
    s="${s//$'\n'/\\n}"
    printf '%s' "$s"
}

# Escape text for the device shell used by `input text` (spaces become %s).
_adb_escape_input_text() {
    local text="$1" out="" ch i
    for (( i = 0; i < ${#text}; i++ )); do
        ch="${text:i:1}"
        case "$ch" in
            " ") out+="%s" ;;
            [\\\'\"\`\$\;\&\|\<\>\(\)\*\?\~\!\#\[\]\{\}]) out+="\\$ch" ;;
            *) out+="$ch" ;;
        esac
    done
    printf '%s' "$out"
}

# Screen size "WxH" (override size wins over physical). Fails if unknown.
_adb_screen_size() {
    local size
    size="$(_adb_exec shell wm size 2>/dev/null | grep -oP '\d+x\d+' | tail -1 || true)"
    if [[ ! "$size" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "ERROR: could not read screen size (wm size)" >&2
        return 1
    fi
    echo "$size"
}

# ─── Device Management ──────────────────────────────────────────────────────

# List connected devices as JSON array.
adb_devices() {
    local adb
    adb="$(adb_find_binary)" || return 1
    local raw
    if ! raw="$("$adb" devices -l)"; then
        echo "ERROR: adb devices failed" >&2
        return 1
    fi

    echo "["
    local first=true
    local line serial state model device transport
    while IFS= read -r line; do
        line="${line%$'\r'}"
        # Skip header, empty lines and daemon banners ("* daemon started ...")
        [[ "$line" == "List of devices"* ]] && continue
        [[ "$line" == "*"* ]] && continue
        [[ -z "${line// /}" ]] && continue

        serial="$(echo "$line" | awk '{print $1}')"
        state="$(echo "$line" | awk '{print $2}')"
        [[ -z "$state" ]] && continue

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
            "$(_adb_json_escape "$serial")" "$(_adb_json_escape "$state")" \
            "$(_adb_json_escape "$model")" "$(_adb_json_escape "$device")" \
            "$(_adb_json_escape "$transport")"
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
    adb="$(adb_find_binary)" || return 1
    local ready
    ready="$("$adb" devices | tr -d '\r' | awk '$2 == "device" {print $1}')"
    local count=0
    [[ -n "$ready" ]] && count="$(printf '%s\n' "$ready" | wc -l)"

    if (( count == 0 )); then
        echo "ERROR: No Android devices connected." >&2
        return 1
    elif (( count == 1 )); then
        ADB_DEVICE="$ready"
        echo "Auto-selected device: $ADB_DEVICE" >&2
        return 0
    else
        echo "ERROR: Multiple devices connected. Set ADB_DEVICE." >&2
        "$adb" devices -l >&2
        return 1
    fi
}

# Read one getprop value; fails if the device does not answer.
_adb_getprop() {
    local value
    value="$(_adb_exec shell getprop "$1")" || return 1
    printf '%s' "${value//$'\r'/}"
}

# Get device properties as JSON. Fails (no JSON) if the device does not answer.
adb_device_info() {
    adb_auto_select || return 1

    local android_ver sdk_ver model manufacturer screen_size density
    android_ver="$(_adb_getprop ro.build.version.release)" || { echo "ERROR: device not responding: $ADB_DEVICE" >&2; return 1; }
    sdk_ver="$(_adb_getprop ro.build.version.sdk)" || return 1
    model="$(_adb_getprop ro.product.model)" || return 1
    manufacturer="$(_adb_getprop ro.product.manufacturer)" || return 1
    screen_size="$(_adb_screen_size 2>/dev/null || echo "unknown")"
    density="$(_adb_exec shell wm density 2>/dev/null | grep -oP '\d+' | tail -1 || true)"
    [[ -n "$density" ]] || density="unknown"

    printf '{"serial":"%s","android":"%s","sdk":"%s","model":"%s","manufacturer":"%s","screen":"%s","density":"%s"}\n' \
        "$(_adb_json_escape "$ADB_DEVICE")" "$(_adb_json_escape "$android_ver")" \
        "$(_adb_json_escape "$sdk_ver")" "$(_adb_json_escape "$model")" \
        "$(_adb_json_escape "$manufacturer")" "$screen_size" "$density"
}

# ─── APK Operations ─────────────────────────────────────────────────────────

# Install APK on device.
adb_install() {
    _adb_need_arg "apk path" "${1:-}" || return 1
    local apk_path="$1"

    if [[ ! -f "$apk_path" ]]; then
        echo "ERROR: APK not found: $apk_path" >&2
        return 1
    fi

    echo "Installing APK: $apk_path" >&2
    _adb_exec install -r -t "$apk_path"
}

# Uninstall package. Idempotent: a package that is not installed is not an error.
adb_uninstall() {
    _adb_need_package "${1:-}" || return 1
    local package="$1"
    echo "Uninstalling: $package" >&2
    _adb_exec uninstall "$package" 2>/dev/null || true
}

# Check if package is installed (exact name, not a prefix).
adb_is_installed() {
    _adb_need_package "${1:-}" || return 1
    local package="$1"
    _adb_exec shell pm list packages 2>/dev/null | tr -d '\r' | grep -qxF "package:$package"
}

# Launch app by package/activity.
adb_launch() {
    _adb_need_package "${1:-}" || return 1
    local package="$1"
    local activity="${2:-}"

    if [[ -n "$activity" ]]; then
        if [[ ! "$activity" =~ ^[A-Za-z0-9_.]+$ ]]; then
            echo "ERROR: invalid activity name: '$activity'" >&2
            return 1
        fi
        _adb_exec shell am start -n "$package/$activity"
    else
        # Use am start with LAUNCHER intent (faster and cleaner than monkey)
        local launcher
        launcher="$(_adb_exec shell cmd package resolve-activity --brief "$package" 2>/dev/null | tail -1 | tr -d '\r' || true)"
        if [[ "$launcher" =~ ^[A-Za-z0-9_.]+/[A-Za-z0-9_.]+$ ]]; then
            _adb_exec shell am start -n "$launcher" 2>/dev/null
        else
            # Fallback: use monkey (slower but works when resolve-activity fails)
            _adb_exec shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
        fi
    fi
}

# Force-stop app.
adb_stop() {
    _adb_need_package "${1:-}" || return 1
    _adb_exec shell am force-stop "$1"
}

# Clear app data.
adb_clear_data() {
    _adb_need_package "${1:-}" || return 1
    _adb_exec shell pm clear "$1"
}

# ─── Screenshot & Recording ────────────────────────────────────────────────

# Pull a device file to a local path. Any stale local file is removed first,
# so success always means a fresh capture.
_adb_pull_fresh() {
    local device_path="$1" output="$2"
    if [[ -e "$output" ]] && ! rm -f -- "$output"; then
        echo "ERROR: cannot replace existing file: $output" >&2
        return 1
    fi
    _adb_exec pull "$device_path" "$output" >/dev/null || return 1
    [[ -f "$output" ]]
}

# Capture screenshot and pull to local path.
adb_screenshot() {
    local output="${1:-${TMPDIR:-/tmp}/android-screenshot-$(date +%s).png}"
    local device_path="/sdcard/savia-screenshot.png"

    if _adb_exec shell screencap -p "$device_path" && _adb_pull_fresh "$device_path" "$output"; then
        _adb_exec shell rm "$device_path" >/dev/null 2>&1 || echo "WARN: could not delete $device_path on device" >&2
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

    _adb_need_uint "duration" "$duration" || return 1
    if [[ ! "$output" =~ ^/[A-Za-z0-9_./-]+$ ]]; then
        echo "ERROR: invalid device path: '$output'" >&2
        return 1
    fi
    _adb_exec shell screenrecord --time-limit "$duration" "$output" &
    echo $!
}

# Pull recording from device.
adb_record_pull() {
    local device_path="${1:-/sdcard/savia-recording.mp4}"
    local local_path="${2:-${TMPDIR:-/tmp}/android-recording-$(date +%s).mp4}"

    _adb_pull_fresh "$device_path" "$local_path" || { echo "ERROR: Recording pull failed" >&2; return 1; }
    echo "$local_path"
}

# ─── UI Interaction ─────────────────────────────────────────────────────────

# Tap at coordinates.
adb_tap() {
    _adb_need_uint "x" "${1:-}" || return 1
    _adb_need_uint "y" "${2:-}" || return 1
    _adb_exec shell input tap "$1" "$2" >/dev/null
}

# Long press at coordinates (duration in ms).
adb_long_press() {
    local x="${1:-}" y="${2:-}" duration="${3:-1000}"
    _adb_need_uint "x" "$x" || return 1
    _adb_need_uint "y" "$y" || return 1
    _adb_need_uint "duration" "$duration" || return 1
    _adb_exec shell input swipe "$x" "$y" "$x" "$y" "$duration" >/dev/null
}

# Swipe from (x1,y1) to (x2,y2) over duration ms.
adb_swipe() {
    local x1="${1:-}" y1="${2:-}" x2="${3:-}" y2="${4:-}" duration="${5:-300}"
    local v
    for v in "$x1" "$y1" "$x2" "$y2" "$duration"; do
        _adb_need_uint "swipe argument" "$v" || return 1
    done
    _adb_exec shell input swipe "$x1" "$y1" "$x2" "$y2" "$duration" >/dev/null
}

# Scroll down (swipe up gesture).
adb_scroll_down() {
    local screen_info
    screen_info="$(_adb_screen_size)" || return 1
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
    screen_info="$(_adb_screen_size)" || return 1
    local w h
    w="${screen_info%x*}"
    h="${screen_info#*x}"

    local cx=$((w / 2))
    local y_start=$((h * 30 / 100))
    local y_end=$((h * 70 / 100))

    adb_swipe "$cx" "$y_start" "$cx" "$y_end" 300
}

# Type text on device. Spaces become %s (so a literal "%s" cannot be typed);
# shell metacharacters are escaped for the device shell.
adb_type() {
    _adb_need_arg "text" "${1:-}" || return 1
    local text="$1"
    if [[ "$text" == *$'\n'* || "$text" == *$'\t'* ]]; then
        echo "ERROR: adb_type does not support newlines or tabs (use adb_key enter/tab)" >&2
        return 1
    fi
    _adb_exec shell input text "$(_adb_escape_input_text "$text")" >/dev/null
}

# Press key by keycode name or number.
# Common: BACK=4, HOME=3, ENTER=66, TAB=61, DEL=67
adb_key() {
    local key="${1:-}"
    case "$key" in
        back|BACK)    _adb_exec shell input keyevent 4 >/dev/null ;;
        home|HOME)    _adb_exec shell input keyevent 3 >/dev/null ;;
        enter|ENTER)  _adb_exec shell input keyevent 66 >/dev/null ;;
        tab|TAB)      _adb_exec shell input keyevent 61 >/dev/null ;;
        delete|DEL)   _adb_exec shell input keyevent 67 >/dev/null ;;
        recent|RECENT) _adb_exec shell input keyevent 187 >/dev/null ;;
        menu|MENU)    _adb_exec shell input keyevent 82 >/dev/null ;;
        *)
            if [[ ! "$key" =~ ^[A-Za-z0-9_]+$ ]]; then
                echo "ERROR: invalid key: '$key'" >&2
                return 1
            fi
            _adb_exec shell input keyevent "$key" >/dev/null ;;
    esac
}

# ─── UI Hierarchy ───────────────────────────────────────────────────────────

# Dump UI hierarchy to local file. Returns path.
adb_hierarchy() {
    local output="${1:-${TMPDIR:-/tmp}/android-hierarchy-$(date +%s).xml}"
    local device_path="/sdcard/savia-hierarchy.xml"

    if _adb_exec shell uiautomator dump "$device_path" >/dev/null && _adb_pull_fresh "$device_path" "$output"; then
        _adb_exec shell rm "$device_path" >/dev/null 2>&1 || echo "WARN: could not delete $device_path on device" >&2
        echo "$output"
    else
        echo "ERROR: Hierarchy dump failed" >&2
        return 1
    fi
}

# Escape a literal for comparison against XML attribute values.
_adb_xml_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    s="${s//\'/&apos;}"
    printf '%s' "$s"
}

# Print "x1,y1,x2,y2" of the first node containing any of the given literal
# attribute fragments (fixed strings, no regex). Fails if none matches.
# The dump goes to a private mktemp file (no fixed /tmp path shared between runs).
_adb_find_bounds() {
    local hierarchy_file node bounds
    hierarchy_file="$(mktemp "${TMPDIR:-/tmp}/savia-adb-hierarchy-XXXXXX")" || return 1

    if ! adb_hierarchy "$hierarchy_file" >/dev/null; then
        rm -f -- "$hierarchy_file"
        return 1
    fi

    local -a grep_args=()
    local frag
    for frag in "$@"; do
        grep_args+=(-e "$frag")
    done
    node="$(grep -oP '<node [^>]*>' "$hierarchy_file" | grep -F "${grep_args[@]}" | head -1 || true)"
    rm -f -- "$hierarchy_file"

    bounds="$(printf '%s' "$node" | grep -oP 'bounds="\[\K\d+,\d+\]\[\d+,\d+(?=\]")' || true)"
    if [[ -z "$bounds" ]]; then
        return 1
    fi
    # "x1,y1][x2,y2" -> "x1,y1,x2,y2"
    echo "${bounds/][/,}"
}

# Find element bounds by resource-id. Returns "x1,y1,x2,y2" or fails.
# Accepts the short id (login_button) or the full one (com.app:id/login_button).
adb_find_by_id() {
    _adb_need_arg "resource-id" "${1:-}" || return 1
    local id
    id="$(_adb_xml_escape "$1")"
    _adb_find_bounds " resource-id=\"$id\"" ":id/$id\""
}

# Find element bounds by exact text content. Returns "x1,y1,x2,y2" or fails.
adb_find_by_text() {
    _adb_need_arg "text" "${1:-}" || return 1
    _adb_find_bounds " text=\"$(_adb_xml_escape "$1")\""
}

# Tap on element by resource-id (finds center of bounds).
adb_tap_id() {
    local resource_id="${1:-}"
    local bounds
    bounds="$(adb_find_by_id "$resource_id" || true)"

    if [[ -z "$bounds" ]]; then
        echo "ERROR: Element not found: $resource_id" >&2
        return 1
    fi

    local x1 y1 x2 y2
    IFS=',' read -r x1 y1 x2 y2 <<< "$bounds"
    adb_tap $(( (x1 + x2) / 2 )) $(( (y1 + y2) / 2 ))
}

# Tap on element by text content.
adb_tap_text() {
    local text="${1:-}"
    local bounds
    bounds="$(adb_find_by_text "$text" || true)"

    if [[ -z "$bounds" ]]; then
        echo "ERROR: Element not found with text: $text" >&2
        return 1
    fi

    local x1 y1 x2 y2
    IFS=',' read -r x1 y1 x2 y2 <<< "$bounds"
    adb_tap $(( (x1 + x2) / 2 )) $(( (y1 + y2) / 2 ))
}

# ─── Logcat & Debugging ────────────────────────────────────────────────────

# Clear logcat buffer.
adb_logcat_clear() {
    _adb_exec logcat -c 2>/dev/null
}

# logcat -t value for "the last N seconds". A bare "N.0" would be read by
# logcat as epoch second N (the whole buffer), so use device time minus N.
_adb_logcat_since() {
    local seconds="$1" now
    now="$(_adb_exec shell date +%s 2>/dev/null | tr -d '\r' || true)"
    if ! _adb_is_uint "$now"; then
        echo "ERROR: could not read device clock (date +%s)" >&2
        return 1
    fi
    printf '%s.000' "$(( now - seconds ))"
}

# Get error-level logs for last N seconds. Returns log text.
# If the package is not running (e.g. it just crashed) the logs are not
# filtered by pid, with a warning on stderr.
adb_logcat_errors() {
    local seconds="${1:-30}"
    local package="${2:-}"

    _adb_need_uint "seconds" "$seconds" || return 1
    local -a filter=()
    if [[ -n "$package" ]]; then
        _adb_need_package "$package" || return 1
        local pid
        pid="$(_adb_exec shell pidof "$package" 2>/dev/null | tr -d '\r' | awk '{print $1}' || true)"
        if _adb_is_uint "$pid"; then
            filter=("--pid=$pid")
        else
            echo "WARN: $package is not running; showing errors from all processes" >&2
        fi
    fi

    local since
    since="$(_adb_logcat_since "$seconds")" || return 1
    _adb_exec logcat -d -t "$since" "${filter[@]}" "*:E" 2>/dev/null || true
}

# Get all logs for last N seconds.
adb_logcat_recent() {
    local seconds="${1:-10}"
    _adb_need_uint "seconds" "$seconds" || return 1
    local since
    since="$(_adb_logcat_since "$seconds")" || return 1
    _adb_exec logcat -d -t "$since" 2>/dev/null || true
}

# Search logcat for crash patterns. Returns structured output.
adb_detect_crash() {
    local seconds="${1:-60}"
    local logs
    logs="$(adb_logcat_errors "$seconds")" || return 1

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
    _adb_need_package "${1:-}" || return 1
    _adb_exec shell dumpsys meminfo "$1" 2>/dev/null | head -30
}

# ─── Convenience Orchestration ──────────────────────────────────────────────

# Full debug snapshot: screenshot + hierarchy + recent logs.
# Prints the paths as JSON plus how many captures failed; non-zero if any did.
adb_snapshot() {
    local prefix="${1:-${TMPDIR:-/tmp}/android-snapshot-$(date +%s)}"

    adb_auto_select || return 1

    local screenshot_path="${prefix}-screen.png"
    local hierarchy_path="${prefix}-hierarchy.xml"
    local logcat_path="${prefix}-logcat.txt"
    local failed=0

    adb_screenshot "$screenshot_path" >/dev/null || failed=$((failed + 1))
    adb_hierarchy "$hierarchy_path" >/dev/null || failed=$((failed + 1))
    adb_logcat_recent 30 > "$logcat_path" || failed=$((failed + 1))

    printf '{"screenshot":"%s","hierarchy":"%s","logcat":"%s","failed":%d}\n' \
        "$(_adb_json_escape "$screenshot_path")" "$(_adb_json_escape "$hierarchy_path")" \
        "$(_adb_json_escape "$logcat_path")" "$failed"
    (( failed == 0 ))
}

# Poll a finder until it succeeds or the timeout (seconds) expires.
_adb_wait() {
    local what="$1" timeout="$2" interval="$3"
    shift 3
    _adb_need_uint "timeout" "$timeout" || return 1
    if ! _adb_is_uint "$interval" || (( interval < 1 )); then
        echo "ERROR: interval must be an integer >= 1, got: '$interval'" >&2
        return 1
    fi

    local deadline=$(( SECONDS + timeout ))
    while :; do
        if "$@" >/dev/null 2>&1; then
            return 0
        fi
        (( SECONDS >= deadline )) && break
        sleep "$interval"
    done

    echo "TIMEOUT: $what not found after ${timeout}s" >&2
    return 1
}

# Wait for element to appear (polling). Returns 0 if found, 1 if timeout.
adb_wait_for_text() {
    _adb_need_arg "text" "${1:-}" || return 1
    _adb_wait "Element with text '$1'" "${2:-10}" "${3:-1}" adb_find_by_text "$1"
}

# Wait for element by resource-id. Returns 0 if found, 1 if timeout.
adb_wait_for_id() {
    _adb_need_arg "resource-id" "${1:-}" || return 1
    _adb_wait "Element '$1'" "${2:-10}" "${3:-1}" adb_find_by_id "$1"
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
