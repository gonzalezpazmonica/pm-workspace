# savia-monitor-autostart.ps1 — Instala/desinstala autoarranque de Savia Monitor al login de Windows.
#
# Uso:
#   powershell -NoProfile -File scripts/savia-monitor-autostart.ps1 install
#   powershell -NoProfile -File scripts/savia-monitor-autostart.ps1 uninstall
#   powershell -NoProfile -File scripts/savia-monitor-autostart.ps1 status
#
# Crea un acceso directo en la carpeta Startup del usuario (scope: usuario actual).
# No requiere permisos de administrador. Reversible.

param(
  [Parameter(Position=0)]
  [ValidateSet('install','uninstall','status')]
  [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'

$ExePath      = Join-Path $env:USERPROFILE '.savia\cargo-target\savia-monitor\release\savia-monitor.exe'
$StartupDir   = [Environment]::GetFolderPath('Startup')
$ShortcutPath = Join-Path $StartupDir 'Savia Monitor.lnk'

function Get-Status {
  [PSCustomObject]@{
    ExeExists      = Test-Path $ExePath
    ExePath        = $ExePath
    ShortcutExists = Test-Path $ShortcutPath
    ShortcutPath   = $ShortcutPath
    ProcessRunning = [bool](Get-Process -Name 'savia-monitor' -ErrorAction SilentlyContinue)
  }
}

switch ($Action) {
  'install' {
    if (-not (Test-Path $ExePath)) {
      Write-Error "Ejecutable no encontrado en $ExePath. Compila primero con 'npm run tauri build' en projects/savia-monitor."
      exit 1
    }
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($ShortcutPath)
    $lnk.TargetPath       = $ExePath
    $lnk.WorkingDirectory = Split-Path $ExePath
    $lnk.WindowStyle      = 7  # minimized — la app vive en system tray
    $lnk.Description      = 'Savia Monitor — system tray (autoarranque al login)'
    $lnk.Save()
    Write-Host "Instalado: $ShortcutPath"
    Write-Host "Target:    $ExePath"
  }
  'uninstall' {
    if (Test-Path $ShortcutPath) {
      Remove-Item -LiteralPath $ShortcutPath -Force
      Write-Host "Desinstalado: $ShortcutPath"
    } else {
      Write-Host "No instalado (no existe $ShortcutPath)."
    }
  }
  'status' {
    Get-Status | Format-List
  }
}
