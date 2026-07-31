# install.ps1 — SaviaVaults installer (Windows PowerShell)
# Copyright (c) 2026 Savia. MIT License.

param(
    [switch]$SkipNodeCheck = $false
)

$ErrorActionPreference = "Stop"

Write-Host "[savia-vaults] SaviaVaults Installer (Windows)" -ForegroundColor Green
Write-Host ""

# ── Check Node.js ──
if (-not $SkipNodeCheck) {
    try {
        $nodeVersion = (node -v) -replace 'v', ''
        $majorVersion = [int]($nodeVersion.Split('.')[0])
        if ($majorVersion -lt 22) {
            Write-Host "[ERROR] Node.js $nodeVersion detected. SaviaVaults requires Node.js 22+." -ForegroundColor Red
            Write-Host "Install from https://nodejs.org"
            exit 1
        }
        Write-Host "Node.js v$nodeVersion" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Node.js not found. Install Node.js 22+ from https://nodejs.org" -ForegroundColor Red
        exit 1
    }
}

# ── Check Git ──
try {
    $gitVersion = (git --version) -replace 'git version ', ''
    Write-Host "Git $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Git not found. Install from https://git-scm.com" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ── Install globally ──
Write-Host "Installing savia-vaults..." -ForegroundColor Green
try {
    npm install -g savia-vaults
    Write-Host "SaviaVaults installed successfully!" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Global install failed. Use: npx savia-vaults <command>" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Quick start:" -ForegroundColor Green
Write-Host "  savia-vaults init my-knowledge"
Write-Host "  cd vaults\my-knowledge"
Write-Host "  savia-vaults serve --transport mcp"
Write-Host ""
Write-Host "Documentation: https://github.com/gonzalezpazmonica/savia-vaults" -ForegroundColor Green
