# Savia Claw Bridge — Architecture & Runbook

> The bridge is the component that lets Savia Claw reach Claude Code.
> If the bridge is down, Savia Claw loops `remote:unreachable` SOS
> alerts on Nextcloud Talk. This document describes the bridge's
> architecture, lifecycle, failure modes, and operational runbook.

## What is the bridge

`savia-bridge` is a zero-dependency Python HTTPS server (`scripts/savia-bridge.py`,
stdlib only) that listens on port 8922 and exposes Claude Code CLI to:

- **Savia Mobile (Android)** — HTTPS + SSE streaming of Claude responses
- **Savia Claw daemon** — via SSH loopback, detects Claude Code health
- **Any LAN client** — health check, session listing, profile management

Endpoints: `POST /chat`, `GET /health`, `GET /sessions`, `DELETE /sessions`,
`GET /install`, `GET /download/apk`, `GET /update/check`, `GET /update/download`,
`GET|PUT /profile`, `GET|PUT /git-config`, `GET|PUT /team`.

State lives entirely under `~/.savia/bridge/`:
- `auth_token` — mode 0600, auto-generated on first run
- `cert.pem` + `key.pem` — self-signed TLS, auto-generated on first run
- `bridge.log` — application log
- `chat.log` — chat transcripts
- `sessions/` — Claude CLI session directory
- `workdirs/` — per-session working directories
- `users/` — per-user profiles
- `apk/` — APK files for Savia Mobile distribution
- `systemd.log` — systemd stdout/stderr (when run as a unit)

## Architecture diagram

```
Savia Mobile (Android)         Savia Claw daemon (Lima)
        │                              │
        │ HTTPS + SSE                  │ SSH loopback (monica@localhost)
        │ port 8922                    │ `pgrep -f claude`
        │                              │
        ▼                              ▼
   ┌─────────────────────────────────────────┐
   │  savia-bridge.service (systemd)         │
   │  python3 scripts/savia-bridge.py        │
   │  User=monica, MemoryMax=512M            │
   └────────────────┬────────────────────────┘
                    │ stdio pipes
                    ▼
               claude CLI
                    │
                    ▼
           api.anthropic.com
```

## Installation — required ONCE per host

### Step 1: user-level (works while Monica is logged in)

```bash
systemctl --user enable --now savia-bridge
curl -sk https://localhost:8922/health
```

The user unit lives at `~/.config/systemd/user/savia-bridge.service`.
This is the default after cloning the repo and is what this PR wires up.

### Step 2: promote to system unit (survives reboot)

User-level services stop when Monica logs out. To keep the bridge running
after power failures and reboots, promote it to a system unit:

```bash
sudo bash scripts/install-savia-bridge-system.sh
```

This script is idempotent and:

1. Stops and disables the user-level unit
2. Creates `/etc/systemd/system/savia-bridge.service` with hardening
   (PrivateTmp, ProtectSystem=strict, ProtectHome=read-only,
   NoNewPrivileges, MemoryMax=512M, CPUQuota=50%)
3. Creates `/home/monica/.savia/bridge/` with correct ownership
4. Runs `systemctl daemon-reload && enable && restart`
5. Verifies `https://localhost:8922/health`

## Savia Claw integration

Savia Claw's survival loop (`zeroclaw/host/survival_phases.py::phase_respiracion`)
calls `remote_host.is_reachable()` and `remote_host.is_bridge_running()` on
every breath. These talk to the bridge over SSH, not HTTPS — they use
the shell for maximum reliability. Wiring:

1. `~/.ssh/savia_remote_ed25519` — ed25519 key for `monica@localhost`
   (added to `~/.ssh/authorized_keys`)
2. `~/.savia/remote-host-config` — `REMOTE_HOST=localhost`,
   `REMOTE_SSH_USER=monica`, `REMOTE_SSH_KEY=~/.ssh/savia_remote_ed25519`
3. `scripts/start-bridge.sh` — invoked by `remote_host.restart_bridge()`;
   prefers `sudo -n systemctl restart savia-bridge` (system unit),
   falls back to `systemctl --user restart savia-bridge`

## Failure modes

| Symptom | Root cause | Fix |
|---|---|---|
| `remote:unreachable` in Talk | `~/.savia/remote-host-config` missing | Re-create from the template in `zeroclaw/host/remote-host-config.example` |
| `bridge:down` in daemon log | Service stopped or crashed | `systemctl restart savia-bridge` and check `journalctl -u savia-bridge` |
| Health returns 500 | Claude CLI not found in PATH | Ensure `/home/monica/.local/bin/claude` exists and PATH env is set |
| SSH loopback fails with "Permission denied" | Public key not in `authorized_keys` | `cat ~/.ssh/savia_remote_ed25519.pub >> ~/.ssh/authorized_keys` |
| Bridge returns after reboot only when Monica logs in | User unit active, system unit not installed | Run `sudo bash scripts/install-savia-bridge-system.sh` |

## Operational runbook

```bash
# Quick status
systemctl status savia-bridge
curl -sk https://localhost:8922/health

# Live logs
journalctl -u savia-bridge -f
tail -f ~/.savia/bridge/bridge.log

# Force restart (via Savia Claw's wrapper)
bash scripts/start-bridge.sh

# Full reinstall (idempotent)
sudo bash scripts/install-savia-bridge-system.sh

# Verify Savia Claw detects the bridge
python3 -c "
from zeroclaw.host.remote_host import is_reachable, is_bridge_running
print('reachable:', is_reachable())
print('bridge_running:', is_bridge_running())
"
```

Both should return `True`. If not, re-check `~/.savia/remote-host-config`.

## Security posture

- **TLS**: self-signed, auto-generated; pin via cert fingerprint on mobile
- **Auth**: bearer token in `~/.savia/bridge/auth_token` (mode 0600)
- **systemd hardening**: `ProtectSystem=strict`, `ProtectHome=read-only`,
  `NoNewPrivileges=true`, `PrivateTmp=true`, `ReadWritePaths` narrowed to
  `~/.savia/bridge` only. The service cannot modify the repo or other
  home directories.
- **Never commit**: `~/.savia/bridge/*` is outside the repo.
  `~/.savia/remote-host-config` is gitignored.

## Related files

- `scripts/savia-bridge.py` — the server
- `scripts/savia-bridge.service` — systemd unit template
- `scripts/install-savia-bridge-system.sh` — idempotent installer
- `scripts/start-bridge.sh` — wrapper invoked by Savia Claw
- `zeroclaw/host/remote_host.py` — Savia Claw's SSH client
- `zeroclaw/host/survival_phases.py` — breath loop that probes the bridge
- `zeroclaw/.agent-maps/host/survival.acm` — ACM for the survival system
- `tests/test-savia-bridge-scripts.bats` — lint-level tests
