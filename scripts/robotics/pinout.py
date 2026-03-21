"""ASCII pinout generator for common microcontrollers.

Generates annotated pinout diagrams showing which pins connect where.
"""

# ESP32 DevKit V1 — 38 pins (left/right columns)
ESP32_DEVKIT_V1 = {
    "name": "ESP32 DevKit V1",
    "left": [
        "3V3", "EN", "G36", "G39", "G34", "G35", "G32", "G33",
        "G25", "G26", "G27", "G14", "G12", "GND", "G13", "D2",
        "D3", "CMD", "5V",
    ],
    "right": [
        "GND", "G23", "G22", "TX", "RX", "G21", "GND", "G19",
        "G18", "G5", "G17", "G16", "G4", "G2", "G15", "D1",
        "D0", "CLK", "3V3",
    ],
}

# Arduino Uno
ARDUINO_UNO = {
    "name": "Arduino Uno",
    "left": [
        "IOREF", "RST", "3V3", "5V", "GND", "GND", "VIN", "",
        "A0", "A1", "A2", "A3", "A4", "A5",
    ],
    "right": [
        "D13/SCK", "D12/MISO", "D11/MOSI", "D10/SS", "D9", "D8",
        "", "D7", "D6", "D5", "D4", "D3", "D2", "D1/TX", "D0/RX",
    ],
}

# Raspberry Pi Pico / RP2040
RPI_PICO = {
    "name": "Raspberry Pi Pico",
    "left": [
        "GP0", "GP1", "GND", "GP2", "GP3", "GP4", "GP5", "GND",
        "GP6", "GP7", "GP8", "GP9", "GND", "GP10", "GP11", "GP12",
        "GP13", "GND", "GP14", "GP15",
    ],
    "right": [
        "VBUS", "VSYS", "GND", "3V3_EN", "3V3", "ADC_VREF",
        "GP28", "GND", "GP27", "GP26", "RUN", "GP22", "GND",
        "GP21", "GP20", "GP19", "GP18", "GND", "GP17", "GP16",
    ],
}

BOARDS = {
    "esp32": ESP32_DEVKIT_V1,
    "arduino-uno": ARDUINO_UNO,
    "rpi-pico": RPI_PICO,
}


def generate_pinout(board_key, connections=None):
    """Generate ASCII pinout with optional connection annotations.

    Args:
        board_key: Key from BOARDS dict
        connections: List of {pin, device, label, color} dicts

    Returns:
        Multi-line ASCII string
    """
    board = BOARDS.get(board_key)
    if not board:
        return f"Board '{board_key}' not found. Available: {list(BOARDS.keys())}"

    conn_map = {}
    if connections:
        for c in connections:
            pin = c.get("pin", "").upper().replace("GPIO", "G")
            label = c.get("label", c.get("device", ""))
            color = c.get("color", "")
            suffix = f" ── {label}"
            if color:
                suffix += f" ({color})"
            conn_map[pin] = suffix

    name = board["name"]
    left = board["left"]
    right = board["right"]
    rows = max(len(left), len(right))

    # Pad to equal length
    left = left + [""] * (rows - len(left))
    right = right + [""] * (rows - len(right))

    # Build diagram
    w = 16  # box width
    lines = []
    lines.append(f"    ┌{'─' * w}┐")
    lines.append(f"    │ {name:^{w - 2}} │")
    lines.append(f"    │{' ' * w}│")

    for i in range(rows):
        lp = left[i]
        rp = right[i]
        l_conn = conn_map.get(lp.upper(), "")
        r_conn = conn_map.get(rp.upper(), "")
        l_label = f"{l_conn} " if l_conn else ""
        r_label = r_conn if r_conn else ""
        l_str = f"{l_label}{lp:>4}" if lp else "    "
        r_str = f"{rp:<4}{r_label}" if rp else "    "
        n_l = i + 1
        n_r = rows * 2 - i
        lines.append(
            f"{l_str} ┤{n_l:>2}  {' ' * (w - 8)}  {n_r:<2}├ {r_str}")

    lines.append(f"    └{'─' * w}┘")
    return "\n".join(lines)


def list_boards():
    """Return list of available board keys and names."""
    return [(k, v["name"]) for k, v in BOARDS.items()]
