# emergency-plan.ps1 — Pre-descarga de Ollama y modelo LLM para offline (Windows)
# Uso: .\scripts\emergency-plan.ps1 [-Model MODEL] [-Check] [-Help]
param([string]$Model = "", [switch]$Check, [switch]$Help)

$CacheDir = "$env:USERPROFILE\.pm-workspace-emergency"
$MarkerFile = "$CacheDir\.plan-executed"

if ($Help) {
    Write-Host "PM-Workspace Emergency Plan — Pre-descarga Ollama + LLM para offline" -ForegroundColor Cyan
    Write-Host "Uso: .\scripts\emergency-plan.ps1 [-Model MODEL] [-Check]"
    Write-Host "Modelos: 8GB->qwen2.5:3b | 16GB->qwen2.5:7b | 32GB+->qwen2.5:14b"; exit 0
}
if ($Check) {
    if (Test-Path $MarkerFile) { Write-Host "OK Emergency plan ejecutado ($(Get-Content $MarkerFile))" -ForegroundColor Green; exit 0 }
    else { Write-Host "Emergency plan NO ejecutado" -ForegroundColor Yellow; exit 1 }
}

Write-Host "`nPM-Workspace - Emergency Plan (Windows)" -ForegroundColor Cyan
Write-Host "Pre-descarga de recursos para instalacion offline.`n"

# ── 1. Detectar hardware ─────────────────────────────────────────────────────
Write-Host "[1/4] Detectando hardware..." -ForegroundColor Blue
$Arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
$RamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$GpuName = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
Write-Host "  OS: Windows · Arch: $Arch · RAM: ${RamGB}GB · GPU: $GpuName"

if (-not $Model) {
    if ($RamGB -ge 32) { $Model = "qwen2.5:14b" }
    elseif ($RamGB -ge 16) { $Model = "qwen2.5:7b" }
    else { $Model = "qwen2.5:3b" }
    Write-Host "  Modelo: $Model (auto)" -ForegroundColor Cyan
}
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

# ── 2. Descargar Ollama ──────────────────────────────────────────────────────
Write-Host "`n[2/4] Descargando Ollama para Windows..." -ForegroundColor Blue
$InstallerPath = "$CacheDir\OllamaSetup.exe"

if (Test-Path $InstallerPath) {
    Write-Host "  OK Instalador ya en cache" -ForegroundColor Green
} else {
    Write-Host "  -> Descargando OllamaSetup.exe..." -ForegroundColor Yellow
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $InstallerPath
        Write-Host "  OK Instalador descargado" -ForegroundColor Green
    } catch {
        Write-Host "  WARN No se pudo descargar instalador: $_" -ForegroundColor Yellow
    }
}

# ── 3. Pre-descargar modelo LLM ──────────────────────────────────────────────
Write-Host "`n[3/4] Pre-descargando modelo $Model..." -ForegroundColor Blue
$OllamaCmd = Get-Command ollama -ErrorAction SilentlyContinue

if ($OllamaCmd) {
    $ServerUp = try { (Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -TimeoutSec 3).StatusCode -eq 200 } catch { $false }
    if ($ServerUp) {
        $Models = ollama list 2>$null
        if ($Models -match [regex]::Escape($Model)) {
            Write-Host "  OK Modelo ya disponible" -ForegroundColor Green
        } else {
            Write-Host "  -> Descargando modelo (puede tardar minutos)..." -ForegroundColor Yellow
            ollama pull $Model
            Write-Host "  OK Modelo descargado" -ForegroundColor Green
        }
    } else {
        Write-Host "  -> Iniciando Ollama para descargar modelo..." -ForegroundColor Yellow
        Start-Process ollama -ArgumentList "serve" -WindowStyle Hidden
        Start-Sleep -Seconds 4
        ollama pull $Model 2>$null
        Write-Host "  OK Modelo pre-descargado" -ForegroundColor Green
    }
} else {
    if (Test-Path $InstallerPath) {
        Write-Host "  WARN Instala Ollama primero: ejecuta $InstallerPath" -ForegroundColor Yellow
        Write-Host "  Luego re-ejecuta este script para descargar el modelo."
    } else {
        Write-Host "  WARN Ollama no instalado. Descarga desde https://ollama.com/download" -ForegroundColor Yellow
    }
}

# ── 4. Guardar metadata y marcador ───────────────────────────────────────────
Write-Host "`n[4/4] Guardando metadata..." -ForegroundColor Blue
$Meta = @{ executed = (Get-Date -Format "o"); os = "Windows"; arch = $Arch; ram_gb = $RamGB; model = $Model }
$Meta | ConvertTo-Json | Set-Content "$CacheDir\plan-info.json"
Get-Date -Format "o" | Set-Content $MarkerFile

Write-Host "`nOK Emergency Plan completado" -ForegroundColor Green
Write-Host "Cache: $CacheDir · Modelo: $Model" -ForegroundColor Cyan
Write-Host "Offline: .\scripts\emergency-setup.ps1 (usara cache local)"
