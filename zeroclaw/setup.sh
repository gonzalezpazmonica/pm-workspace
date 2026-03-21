#!/usr/bin/env bash
# ZeroClaw Setup — Detects ESP32, installs deps, flashes MicroPython, deploys firmware.
# Usage: bash zeroclaw/setup.sh [--skip-flash]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_DIR="$SCRIPT_DIR/firmware"
MICROPYTHON_URL="https://micropython.org/resources/firmware/ESP32_GENERIC-20241129-v1.24.1.bin"
MICROPYTHON_BIN="$SCRIPT_DIR/.cache/micropython.bin"
SKIP_FLASH=false

[[ "${1:-}" == "--skip-flash" ]] && SKIP_FLASH=true

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🦎 ZeroClaw Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── 1. Install Python dependencies ──
echo "📋 1/5 — Installing Python dependencies..."
pip3 install --user --quiet esptool mpremote 2>/dev/null
for pkg in esptool mpremote; do
    if python3 -m "$pkg" --help >/dev/null 2>&1 || which "$pkg" >/dev/null 2>&1; then
        echo "  ✅ $pkg"
    else
        echo "  ❌ $pkg — install manually: pip3 install $pkg"
        exit 1
    fi
done
echo ""

# ── 2. Detect ESP32 ──
echo "📋 2/5 — Detecting ESP32..."
PORT=""
for p in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyACM0 /dev/ttyACM1; do
    if [[ -e "$p" ]]; then
        PORT="$p"
        break
    fi
done

if [[ -z "$PORT" ]]; then
    echo "  ❌ No ESP32 detected."
    echo "     1. Connect ESP32 via USB"
    echo "     2. Check: ls /dev/ttyUSB* /dev/ttyACM*"
    echo "     3. Add user to dialout group: sudo usermod -aG dialout $USER"
    echo "     4. Re-run this script"
    exit 1
fi
echo "  ✅ Found ESP32 at $PORT"
echo ""

# ── 3. Flash MicroPython ──
if [[ "$SKIP_FLASH" == true ]]; then
    echo "📋 3/5 — Skipping flash (--skip-flash)"
else
    echo "📋 3/5 — Flashing MicroPython..."
    mkdir -p "$SCRIPT_DIR/.cache"
    if [[ ! -f "$MICROPYTHON_BIN" ]]; then
        echo "  Downloading MicroPython firmware..."
        curl -sL "$MICROPYTHON_URL" -o "$MICROPYTHON_BIN"
    fi
    echo "  Erasing flash..."
    python3 -m esptool --port "$PORT" erase_flash 2>&1 | tail -2
    echo "  Writing MicroPython..."
    python3 -m esptool --port "$PORT" --baud 460800 write_flash -z 0x1000 "$MICROPYTHON_BIN" 2>&1 | tail -2
    echo "  ✅ MicroPython flashed"
    sleep 3  # Wait for ESP32 to reboot
fi
echo ""

# ── 4. Deploy ZeroClaw firmware ──
echo "📋 4/5 — Deploying ZeroClaw firmware..."
for f in boot.py main.py; do
    echo "  Uploading $f..."
    python3 -m mpremote connect "$PORT" cp "$FIRMWARE_DIR/$f" ":$f"
done
# Upload lib/
for f in "$FIRMWARE_DIR"/lib/*.py; do
    fname=$(basename "$f")
    echo "  Uploading lib/$fname..."
    python3 -m mpremote connect "$PORT" mkdir ":lib" 2>/dev/null || true
    python3 -m mpremote connect "$PORT" cp "$f" ":lib/$fname"
done
echo "  ✅ Firmware deployed"
echo ""

# ── 5. Verify ──
echo "📋 5/5 — Verifying..."
python3 -m mpremote connect "$PORT" exec "
import sys
print('MicroPython', sys.version)
import machine
led = machine.Pin(2, machine.Pin.OUT)
led.value(1)
import time
time.sleep_ms(500)
led.value(0)
print('ZeroClaw: LED blink OK')
print('ZeroClaw: Ready')
"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ ZeroClaw ready on $PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Next: python3 zeroclaw/host/bridge.py --port $PORT"
