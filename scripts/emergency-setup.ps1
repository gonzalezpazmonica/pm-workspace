# emergency-setup.ps1 — Setup rapido de LLM local para modo emergencia (Windows)
# Uso: .\scripts\emergency-setup.ps1 [-Model MODEL] [-Help]
param([string]$Model = "qwen2.5:7b", [switch]$Help)

$CacheDir = "$env:USERPROFILE\.pm-workspace-emergency"

if ($Help) {
    Write-Host "PM-Workspace Emergency Setup — Instala Ollama + LLM local (Windows)" -ForegroundColor Cyan
    Write-Host "Uso: .\scripts\emergency-setup.ps1 [-Model MODEL]"
    Write-Host "Modelos: 8GB->qwen2.5:3b | 16GB->qwen2.5:7b (default) | 32GB+->qwen2.5:14b"; exit 0
}

Write-Host "`nPM-Workspace - Emergency Setup (Windows)" -ForegroundColor Cyan

# ── 1. Detectar sistema y conectividad ───────────────────────────────────────
Write-Host "`n[1/5] Detectando sistema..." -ForegroundColor Blue
$Arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
$RamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$GpuName = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
Write-Host "  OS: Windows · Arch: $Arch · RAM: ${RamGB}GB · GPU: $GpuName"

if ($RamGB -lt 8 -and $Model -eq "qwen2.5:7b") { $Model = "qwen2.5:3b"; Write-Host "  WARN RAM < 8GB, modelo ajustado a $Model" -ForegroundColor Yellow }

$Offline = $false
try { $null = Invoke-WebRequest -Uri "https://ollama.ai" -TimeoutSec 5 -UseBasicParsing; Write-Host "  Internet: conectado" -ForegroundColor Green }
catch {
    $Offline = $true; Write-Host "  Internet: SIN CONEXION" -ForegroundColor Yellow
    if (Test-Path "$CacheDir\.plan-executed") { Write-Host "  OK Cache local detectada" -ForegroundColor Green }
    else { Write-Host "  ERROR Sin cache. Ejecuta emergency-plan.ps1 con conexion." -ForegroundColor Red; exit 1 }
}

# ── 2. Instalar Ollama ──────────────────────────────────────────────────────
Write-Host "`n[2/5] Verificando Ollama..." -ForegroundColor Blue
$OllamaCmd = Get-Command ollama -ErrorAction SilentlyContinue

if ($OllamaCmd) {
    $Ver = ollama --version 2>$null; Write-Host "  OK Ollama instalado ($Ver)" -ForegroundColor Green
} else {
    $InstallerPath = "$CacheDir\OllamaSetup.exe"
    if ($Offline) {
        if (Test-Path $InstallerPath) {
            Write-Host "  -> Ejecutando instalador desde cache..." -ForegroundColor Yellow
            Start-Process -FilePath $InstallerPath -ArgumentList "/SILENT" -Wait
            # Refrescar PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
            Write-Host "  OK Ollama instalado desde cache" -ForegroundColor Green
        } else { Write-Host "  ERROR No hay instalador en cache." -ForegroundColor Red; exit 1 }
    } else {
        Write-Host "  -> Descargando e instalando Ollama..." -ForegroundColor Yellow
        $TmpInstaller = "$env:TEMP\OllamaSetup.exe"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $TmpInstaller
        Start-Process -FilePath $TmpInstaller -ArgumentList "/SILENT" -Wait
        Remove-Item $TmpInstaller -Force -ErrorAction SilentlyContinue
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        Write-Host "  OK Ollama instalado" -ForegroundColor Green
    }
}

# ── 3. Iniciar servidor ─────────────────────────────────────────────────────
Write-Host "`n[3/5] Verificando servidor Ollama..." -ForegroundColor Blue
$ServerUp = try { (Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -TimeoutSec 3).StatusCode -eq 200 } catch { $false }
if ($ServerUp) { Write-Host "  OK Servidor activo en :11434" -ForegroundColor Green }
else {
    Write-Host "  -> Iniciando servidor..." -ForegroundColor Yellow
    Start-Process ollama -ArgumentList "serve" -WindowStyle Hidden; Start-Sleep -Seconds 4
    $ServerUp = try { (Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -TimeoutSec 3).StatusCode -eq 200 } catch { $false }
    if ($ServerUp) { Write-Host "  OK Servidor iniciado" -ForegroundColor Green }
    else { Write-Host "  ERROR No se pudo iniciar. Ejecuta: ollama serve" -ForegroundColor Red; exit 1 }
}

# ── 4. Verificar/descargar modelo ────────────────────────────────────────────
Write-Host "`n[4/5] Verificando modelo $Model..." -ForegroundColor Blue
$Models = ollama list 2>$null
if ($Models -match [regex]::Escape($Model)) { Write-Host "  OK Modelo disponible" -ForegroundColor Green }
elseif ($Offline) {
    if ($Models) {
        $Available = ($Models | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1)
        Write-Host "  WARN $Model no disponible offline. Usando: $Available" -ForegroundColor Yellow; $Model = $Available
    } else { Write-Host "  ERROR No hay modelos cacheados." -ForegroundColor Red }
} else {
    Write-Host "  -> Descargando (puede tardar minutos)..." -ForegroundColor Yellow
    ollama pull $Model; Write-Host "  OK Modelo descargado" -ForegroundColor Green
}

# ── 5. Configurar variables ─────────────────────────────────────────────────
Write-Host "`n[5/5] Configuracion para Claude Code..." -ForegroundColor Blue
$EnvFile = "$env:USERPROFILE\.pm-workspace-emergency.env"
@"
# PM-Workspace Emergency Mode — generado $(Get-Date -Format "o")
set ANTHROPIC_BASE_URL=http://localhost:11434
set PM_EMERGENCY_MODEL=$Model
set PM_EMERGENCY_MODE=active
"@ | Set-Content $EnvFile

# Tambien configurar variables de entorno del usuario
[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://localhost:11434", "User")
[Environment]::SetEnvironmentVariable("PM_EMERGENCY_MODEL", $Model, "User")
[Environment]::SetEnvironmentVariable("PM_EMERGENCY_MODE", "active", "User")

Write-Host "  OK Variables configuradas" -ForegroundColor Green
Write-Host "`nOK Setup completado" -ForegroundColor Green
Write-Host "Las variables de entorno se han configurado para el usuario actual."
Write-Host "Estado: .\scripts\emergency-status.sh (en Git Bash) o revisar Ollama manualmente"
