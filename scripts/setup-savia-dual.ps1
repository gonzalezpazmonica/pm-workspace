# setup-savia-dual.ps1 — Installer for Savia Dual (Windows)
#
# Installs/updates Ollama via winget, detects hardware, picks the best
# gemma4 variant, downloads it, writes config, and prepares the environment
# to run the savia-dual-proxy. Hardware details stay local and are never
# written to tracked files.
#
# Usage:
#   pwsh .\scripts\setup-savia-dual.ps1
#   pwsh .\scripts\setup-savia-dual.ps1 -DryRun
#   pwsh .\scripts\setup-savia-dual.ps1 -Reconfigure

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Reconfigure
)

$ErrorActionPreference = "Stop"

function Say($msg)  { Write-Host "[savia-dual] $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "[savia-dual] $msg" -ForegroundColor Yellow }
function Err($msg)  { Write-Host "[savia-dual] $msg" -ForegroundColor Red }

function Invoke-Step($description, [scriptblock]$action) {
    if ($DryRun) {
        Write-Host "  + $description"
    } else {
        & $action
    }
}

# ── Platform check ─────────────────────────────────────────────────────────
if (-not $IsWindows -and $PSVersionTable.PSEdition -ne 'Desktop') {
    Err "This script is Windows-only. Use setup-savia-dual.sh on Linux/macOS."
    exit 1
}
Say "Platform: Windows"

# ── Install/update Ollama ──────────────────────────────────────────────────
function Install-Ollama {
    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollama) {
        Say "Ollama already installed: $(& ollama --version 2>&1 | Select-Object -First 1)"
        return
    }
    Say "Installing Ollama via winget..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Err "winget not found. Install Ollama manually from https://ollama.com/download/windows"
        throw "winget missing"
    }
    Invoke-Step "winget install Ollama.Ollama" {
        winget install --id Ollama.Ollama --silent --accept-source-agreements --accept-package-agreements | Out-Host
    }
    $env:PATH += ";$env:LOCALAPPDATA\Programs\Ollama"
}

if (-not $Reconfigure) { Install-Ollama }

# ── Start Ollama daemon (idempotent) ───────────────────────────────────────
function Ensure-OllamaRunning {
    try {
        $null = Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        return
    } catch {
        Say "Ollama daemon not responding — will start it ($($_.Exception.Message))"
    }
    Invoke-Step "Start ollama serve" {
        Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }
}
if (-not $Reconfigure) { Ensure-OllamaRunning }

# ── Detect hardware (stays local) ──────────────────────────────────────────
function Get-RamGB {
    try {
        $bytes = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
        return [int]([math]::Floor($bytes / 1GB))
    } catch {
        Warn "RAM detection failed: $($_.Exception.Message). Assuming 8 GB (conservative)."
        return 8
    }
}

function Get-VramGB {
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        try {
            $raw = & nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>$null | Select-Object -First 1
            if ($raw) { return [int]([math]::Floor([int]$raw / 1024)) }
        } catch {
            Warn "nvidia-smi query failed: $($_.Exception.Message). Falling back to WMI."
        }
    }
    try {
        $gpu = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Select-Object -First 1
        if ($gpu -and $gpu.AdapterRAM -gt 0) {
            return [int]([math]::Floor($gpu.AdapterRAM / 1GB))
        }
        Warn "WMI returned no VRAM information. Assuming 0 GB (CPU-only mode)."
    } catch {
        Warn "GPU detection failed: $($_.Exception.Message). Assuming 0 GB (CPU-only mode)."
    }
    return 0
}

$RamGB = Get-RamGB
$VramGB = Get-VramGB
Say "Hardware detection complete (values kept local, not logged)."

# ── Pick gemma4 variant ────────────────────────────────────────────────────
function Select-GemmaVariant($ram, $vram) {
    if ($ram -lt 12) { return "gemma4:e2b" }
    if ($ram -lt 24) { return "gemma4:e4b" }
    if ($vram -ge 12) { return "gemma4:26b" }
    if ($ram -ge 32) { return "gemma4:e4b" }
    return "gemma4:e2b"
}

$Model = Select-GemmaVariant $RamGB $VramGB
Say "Selected local model: $Model"

# ── Download model ─────────────────────────────────────────────────────────
if (-not $Reconfigure) {
    $installed = (& ollama list 2>$null) -split "`n" | ForEach-Object { ($_ -split '\s+')[0] }
    if ($installed -contains $Model) {
        Say "Model $Model already present."
    } else {
        Say "Downloading $Model (this may take a while)..."
        Invoke-Step "ollama pull $Model" { & ollama pull $Model | Out-Host }
    }
}

# ── Write config ───────────────────────────────────────────────────────────
$ConfigDir = Join-Path $env:USERPROFILE ".savia\dual"
$ConfigPath = Join-Path $ConfigDir "config.json"
$EnvPath = Join-Path $ConfigDir "env.ps1"
$LogPath = Join-Path $ConfigDir "events.jsonl"

Invoke-Step "mkdir $ConfigDir" {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
}

if (-not $DryRun) {
    $config = [ordered]@{
        listen_host = "127.0.0.1"
        listen_port = 8787
        anthropic_upstream = "https://api.anthropic.com"
        ollama_upstream = "http://127.0.0.1:11434"
        fallback_triggers = [ordered]@{
            network_error = $true
            http_5xx = $true
            http_429 = $true
            timeout_seconds = 30
        }
        circuit_breaker = [ordered]@{
            consecutive_failures = 3
            cooldown_seconds = 60
        }
        local_model = $Model
        log_path = $LogPath
    }
    $config | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8

    @"
# Dot-source this file to route Claude Code through Savia Dual.
`$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:8787"
`$env:SAVIA_DUAL_ACTIVE = "1"
`$env:OLLAMA_KEEP_ALIVE = "24h"
"@ | Set-Content -Path $EnvPath -Encoding UTF8

    Say "Config written: $ConfigPath"
    Say "Env file:       $EnvPath"
}

# ── Final instructions ─────────────────────────────────────────────────────
@"

Savia Dual is ready.

Next steps:
  1. Start the proxy in a terminal:
       python scripts\savia-dual-proxy.py

  2. In another terminal, dot-source the env file and start Claude Code:
       . $EnvPath
       claude

  3. Verify routing:
       Invoke-WebRequest http://127.0.0.1:8787/health
       Get-Content $LogPath -Wait

To reconfigure later: pwsh .\scripts\setup-savia-dual.ps1 -Reconfigure
"@ | Write-Host
