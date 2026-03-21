"""SearxNG integration — auto-start Docker, search, health check. Cross-platform."""
import subprocess, json, time, os, platform
import urllib.request, urllib.error, urllib.parse

COMPOSE_FILE = os.path.join(os.path.dirname(__file__),
                            "docker-compose.searxng.yml")
SEARXNG_URL = os.environ.get("SEARXNG_URL", "http://127.0.0.1:8888")
CONTAINER_NAME = "savia-searxng"
STARTUP_TIMEOUT = 30  # seconds
IS_WINDOWS = platform.system() == "Windows"


def _run(cmd, **kwargs):
    """Run subprocess, adding shell=True on Windows for PATH resolution."""
    defaults = {"capture_output": True, "text": True, "timeout": 10}
    defaults.update(kwargs)
    if IS_WINDOWS:
        defaults.setdefault("shell", True)
    return subprocess.run(cmd, **defaults)


def _docker_compose_cmd():
    """Return docker compose command (v2 plugin or standalone)."""
    for cmd in [["docker", "compose"], ["docker-compose"]]:
        try:
            if _run(cmd + ["version"], timeout=5).returncode == 0:
                return cmd
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    return None


def _docker_available():
    """Check if Docker is available."""
    try:
        r = _run(["docker", "info"], timeout=5)
        return r.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _container_running():
    """Check if SearxNG container is running."""
    try:
        r = _run(["docker", "inspect", "-f", "{{.State.Running}}",
                  CONTAINER_NAME], timeout=5)
        return r.stdout.strip() == "true"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _health_check():
    """Check if SearxNG API responds."""
    try:
        url = f"{SEARXNG_URL}/search?q=test&format=json"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except (urllib.error.URLError, OSError, ValueError):
        return False


def ensure_running():
    """Ensure SearxNG is running. Auto-start Docker if available."""
    # 1. Already healthy?
    if _health_check():
        return {"available": True, "url": SEARXNG_URL,
                "method": "existing", "message": "SearxNG already running"}

    # 2. Container exists but stopped?
    if not _docker_available():
        return {"available": False, "url": "",
                "method": "none", "message": "Docker not available"}

    if not os.path.isfile(COMPOSE_FILE):
        return {"available": False, "url": "",
                "method": "none", "message": "docker-compose.searxng.yml missing"}

    # 3. Start container
    compose_cmd = _docker_compose_cmd()
    if not compose_cmd:
        return {"available": False, "url": "",
                "method": "none", "message": "docker compose not found"}
    try:
        _run(compose_cmd + ["-f", COMPOSE_FILE, "up", "-d"], timeout=60)
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        return {"available": False, "url": "",
                "method": "failed", "message": f"Docker start failed: {e}"}

    # 4. Wait for healthy
    deadline = time.time() + STARTUP_TIMEOUT
    while time.time() < deadline:
        if _health_check():
            return {"available": True, "url": SEARXNG_URL,
                    "method": "auto-started",
                    "message": "SearxNG auto-started via Docker"}
        time.sleep(2)

    return {"available": False, "url": "",
            "method": "timeout",
            "message": f"SearxNG started but not healthy after {STARTUP_TIMEOUT}s"}


def search(query, engines=None, max_results=5, language="en"):
    """Search via SearxNG API. Returns list of results or None."""
    status = ensure_running()
    if not status["available"]:
        return None

    params = {
        "q": query,
        "format": "json",
        "language": language,
    }
    if engines:
        params["engines"] = engines

    url = f"{status['url']}/search?{urllib.parse.urlencode(params)}"
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
    except (urllib.error.URLError, OSError, json.JSONDecodeError):
        return None

    results = []
    for r in data.get("results", [])[:max_results]:
        results.append({
            "title": r.get("title", ""),
            "url": r.get("url", ""),
            "snippet": r.get("content", ""),
            "engine": r.get("engine", ""),
        })
    return results


def stop():
    """Stop SearxNG container."""
    compose_cmd = _docker_compose_cmd()
    if not compose_cmd:
        return "docker compose not found"
    _run(compose_cmd + ["-f", COMPOSE_FILE, "down"], timeout=30)
    return "SearxNG stopped"


def status():
    """Get SearxNG status."""
    return {"docker": _docker_available(), "running": _container_running(),
            "healthy": _health_check(), "url": SEARXNG_URL}
