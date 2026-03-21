"""Generate step-by-step assembly guides for hardware projects.

Produces markdown manuals with BOM, wiring steps, verification
checklists, and safety warnings per component.
"""

# Component knowledge base: safety, voltages, color codes
COMPONENTS = {
    "esp32": {
        "name": "ESP32 DevKit V1",
        "voltage": "3.3V logic, 5V USB power",
        "warning": "GPIO pins are 3.3V. NEVER apply 5V to GPIO.",
    },
    "servo-sg90": {
        "name": "Servo SG90 (micro)",
        "voltage": "4.8-6V external",
        "warning": "NEVER power from ESP32 3V3 — use external 5V supply. "
                   "Can draw >500mA under load.",
        "colors": "Orange=signal, Red=VCC(5V), Brown=GND",
        "pins": ["Signal (PWM)", "VCC (5V)", "GND"],
    },
    "bme280": {
        "name": "BME280 (temp/humidity/pressure)",
        "voltage": "3.3V",
        "warning": "Do NOT connect to 5V — will damage the sensor.",
        "pins": ["VCC (3.3V)", "GND", "SCL", "SDA"],
        "protocol": "I2C (addr 0x76 or 0x77)",
    },
    "hcsr04": {
        "name": "HC-SR04 (ultrasonic distance)",
        "voltage": "5V",
        "warning": "ECHO pin outputs 5V — use voltage divider for "
                   "3.3V MCUs (2x 10kΩ resistors).",
        "pins": ["VCC (5V)", "TRIG", "ECHO", "GND"],
    },
    "mpu6050": {
        "name": "MPU6050 (6-axis IMU)",
        "voltage": "3.3V",
        "pins": ["VCC (3.3V)", "GND", "SCL", "SDA", "INT"],
        "protocol": "I2C (addr 0x68)",
    },
    "led": {
        "name": "LED (standard 5mm)",
        "voltage": "2V forward, 20mA max",
        "warning": "ALWAYS use a current-limiting resistor (220Ω for 3.3V).",
        "pins": ["Anode (+, long leg)", "Cathode (-, short leg)"],
    },
    "relay-5v": {
        "name": "Relay module 5V",
        "voltage": "5V coil, up to 250VAC/10A contacts",
        "warning": "DANGER if controlling AC mains. Ensure proper isolation. "
                   "NEVER touch relay terminals when AC is connected.",
        "safety_level": "critical",
        "pins": ["VCC (5V)", "GND", "IN (signal)", "COM", "NO", "NC"],
    },
    "l298n": {
        "name": "L298N (dual motor driver)",
        "voltage": "5-35V motor, 5V logic",
        "warning": "Motor voltage and logic voltage are separate. "
                   "Flyback diodes included on board.",
        "pins": ["ENA", "IN1", "IN2", "IN3", "IN4", "ENB", "5V", "GND"],
    },
}


def generate_bom(component_keys):
    """Generate Bill of Materials from component list."""
    lines = ["## Bill of Materials (BOM)", ""]
    lines.append("| # | Component | Voltage | Notes |")
    lines.append("|---|-----------|---------|-------|")
    for i, key in enumerate(component_keys, 1):
        comp = COMPONENTS.get(key, {"name": key, "voltage": "?", "warning": ""})
        lines.append(f"| {i} | {comp['name']} | {comp.get('voltage', '?')} "
                     f"| {comp.get('warning', '')[:60]} |")
    lines.append("")
    lines.append("### Additional materials")
    lines.append("- Breadboard (830 holes recommended)")
    lines.append("- Dupont jumper wires (M-M, M-F, F-F)")
    lines.append("- USB cable for ESP32 programming")
    lines.append("- External 5V power supply (if using servos/motors)")
    return "\n".join(lines)


def generate_step(step_num, total, connection, component_db=None):
    """Generate a single assembly step."""
    comp_key = connection.get("component", "unknown")
    comp = (component_db or COMPONENTS).get(comp_key, {})
    lines = []
    lines.append(f"## Step {step_num} of {total}: "
                 f"Connect {comp.get('name', comp_key)}")
    lines.append("")

    if comp.get("colors"):
        lines.append(f"**Wire colors**: {comp['colors']}")
        lines.append("")

    lines.append("### Connections")
    for i, wire in enumerate(connection.get("wires", []), 1):
        color = wire.get("color", "")
        c_str = f" ({color} wire)" if color else ""
        lines.append(f"{i}. {wire['from']} → {wire['to']}{c_str}")
    lines.append("")

    lines.append("### Verification")
    for check in connection.get("checks", ["Connections are firm"]):
        lines.append(f"- [ ] {check}")
    lines.append("")

    if comp.get("warning"):
        level = comp.get("safety_level", "warning")
        icon = "🔴 DANGER" if level == "critical" else "⚠️ Safety"
        lines.append(f"### {icon}")
        lines.append(f"{comp['warning']}")
        lines.append("")

    return "\n".join(lines)


def generate_full_guide(title, components, connections):
    """Generate complete assembly guide.

    Args:
        title: Project title
        components: List of component keys
        connections: List of connection dicts with wires and checks
    """
    lines = [f"# Assembly Guide: {title}", ""]
    lines.append(generate_bom(components))
    lines.append("")
    for i, conn in enumerate(connections, 1):
        lines.append(generate_step(i, len(connections), conn))
    lines.append("## Final verification")
    lines.append("- [ ] All connections double-checked")
    lines.append("- [ ] No loose wires")
    lines.append("- [ ] Power supply OFF before first power-on")
    lines.append("- [ ] USB connected, serial monitor open")
    lines.append("- [ ] Ready to flash firmware")
    return "\n".join(lines)
