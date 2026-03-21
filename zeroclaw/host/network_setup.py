"""ZeroClaw Network Setup — detects host WiFi and configures ESP32.

Detects the host PC's current WiFi SSID and IP, generates config
for ESP32 to join the same network. Cross-platform: Linux/macOS/Windows.
"""
import subprocess
import platform
import re


def detect_ssid():
    """Detect current WiFi SSID of the host. Cross-platform."""
    system = platform.system()
    try:
        if system == "Linux":
            r = subprocess.run(
                ["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"],
                capture_output=True, text=True, timeout=5)
            if r.returncode == 0:
                for line in r.stdout.strip().split('\n'):
                    if line.startswith('yes:'):
                        return line.split(':', 1)[1]
            r = subprocess.run(
                ["iwgetid", "-r"],
                capture_output=True, text=True, timeout=5)
            if r.returncode == 0 and r.stdout.strip():
                return r.stdout.strip()
        elif system == "Darwin":
            r = subprocess.run(
                ["/System/Library/PrivateFrameworks/Apple80211.framework/"
                 "Versions/Current/Resources/airport", "-I"],
                capture_output=True, text=True, timeout=5)
            for line in r.stdout.split('\n'):
                if ' SSID:' in line:
                    return line.split('SSID:')[1].strip()
        elif system == "Windows":
            r = subprocess.run(
                ["netsh", "wlan", "show", "interfaces"],
                capture_output=True, text=True, timeout=5, shell=True)
            for line in r.stdout.split('\n'):
                if 'SSID' in line and 'BSSID' not in line:
                    return line.split(':')[1].strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def detect_host_ip():
    """Detect host's local IP on WiFi. Cross-platform."""
    system = platform.system()
    try:
        if system == "Linux":
            r = subprocess.run(
                ["ip", "-4", "addr", "show"],
                capture_output=True, text=True, timeout=5)
            for m in re.finditer(
                    r'inet (\d+\.\d+\.\d+\.\d+).*?(wl\w+|wlan\w+)',
                    r.stdout):
                return m.group(1)
            for m in re.finditer(r'inet (\d+\.\d+\.\d+\.\d+)', r.stdout):
                if not m.group(1).startswith('127.'):
                    return m.group(1)
        elif system == "Darwin":
            r = subprocess.run(
                ["ipconfig", "getifaddr", "en0"],
                capture_output=True, text=True, timeout=5)
            if r.stdout.strip():
                return r.stdout.strip()
        elif system == "Windows":
            r = subprocess.run(
                ["ipconfig"], capture_output=True, text=True,
                timeout=5, shell=True)
            for m in re.finditer(r'IPv4.*?:\s*(\d+\.\d+\.\d+\.\d+)', r.stdout):
                if not m.group(1).startswith('127.'):
                    return m.group(1)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def generate_esp32_config(ssid, password, host_ip, host_port=8765):
    """Generate config.json for ESP32 ZeroClaw firmware."""
    return {
        "device_id": "zeroclaw-01",
        "wifi_ssid": ssid,
        "wifi_pass": password,
        "host_url": f"http://{host_ip}:{host_port}",
        "led_pin": 2,
        "watchdog_ms": 10000,
        "version": "0.1.0",
    }
