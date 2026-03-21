"""ESP32 WiFi operations via mpremote — scan, verify, deploy config."""
import subprocess
import json
import os


def scan_wifi(port=None):
    """Ask ESP32 to scan WiFi networks. Returns scan output text."""
    cmd = ["python3", "-m", "mpremote"]
    if port:
        cmd += ["connect", port]
    cmd += ["exec", """
import network
wlan = network.WLAN(network.STA_IF)
wlan.active(True)
nets = wlan.scan()
for ssid, bssid, ch, rssi, auth, hidden in nets:
    name = ssid.decode('utf-8', 'ignore')
    sec = ['Open','WEP','WPA-PSK','WPA2-PSK','WPA/WPA2'][min(auth,4)]
    print(f'{rssi:>4}dBm  {sec:<12} {name}')
"""]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        return r.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def verify_wifi(port=None):
    """Check if ESP32 is connected to WiFi. Returns status dict."""
    cmd = ["python3", "-m", "mpremote"]
    if port:
        cmd += ["connect", port]
    cmd += ["exec", """
import network, json
wlan = network.WLAN(network.STA_IF)
r = {
    'connected': wlan.isconnected(),
    'ip': wlan.ifconfig()[0] if wlan.isconnected() else None,
    'ssid': wlan.config('essid') if wlan.isconnected() else None,
}
print(json.dumps(r))
"""]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        for line in r.stdout.strip().split('\n'):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return {"connected": False, "ip": None, "ssid": None}


def deploy_config(config, port=None):
    """Deploy config.json to ESP32 via mpremote. Returns (ok, output)."""
    config_path = os.path.join(
        os.path.dirname(__file__), '..', 'firmware', 'config.json')
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=4)
    cmd = ["python3", "-m", "mpremote"]
    if port:
        cmd += ["connect", port]
    cmd += ["cp", config_path, ":config.json"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        return r.returncode == 0, r.stdout + r.stderr
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        return False, str(e)


def reset(port=None):
    """Reset ESP32 via mpremote."""
    cmd = ["python3", "-m", "mpremote"]
    if port:
        cmd += ["connect", port]
    cmd += ["exec", "import machine; machine.reset()"]
    try:
        subprocess.run(cmd, capture_output=True, timeout=5)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
