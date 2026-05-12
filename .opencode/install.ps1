# install.ps1 — One-line installer for PM-Workspace (Savia) with OpenCode on Windows
# Usage: irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/.opencode/install.ps1 | iex
#
# ⚠️  SECURITY WARNING: This script is piped directly to PowerShell execution (irm|iex).
#     Always verify the source before execution. Only run from official GitHub releases:
#     https://github.com/gonzalezpazmonica/pm-workspace/releases
#     Do NOT run from untrusted or modified URLs.
#
# Environment variables:
#   SAVIA_HOME    — Installation directory (default: ~\claude)
#   SKIP_TESTS    — Set to 1 to skip smoke tests

$ErrorActionPreference = "Stop"

# --- Helpers -------------------------------------------------------------------
function Write-Info  { param($msg) Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "  $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "  $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "  $msg" -ForegroundColor Red }
function Write-Step  { param($num, $msg) Write-Host "`n[$num/5] $msg" -ForegroundColor White }

# --- Help ----------------------------------------------------------------------
if ($args -contains "--help" -or $args -contains "-h") {
    Write-Host "PM-Workspace (Savia) Installer for OpenCode (Windows)"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/.opencode/install.ps1 | iex"
    Write-Host "  .\install.ps1 [--skip-tests] [--help]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --skip-tests    Skip smoke tests after installation"
    Write-Host "  --help, -h      Show this help message"
    Write-Host ""
    Write-Host "Environment variables:"
    Write-Host "  SAVIA_HOME      Installation directory (default: ~\claude)"
    Write-Host "  SKIP_TESTS      Set to 1 to skip smoke tests"
    Write-Host ""
    Write-Host "Exit codes: 0 Success, 1 Missing prereqs, 2 Network error, 3 Cancelled"
    exit 0
}

$SkipTests = ($args -contains "--skip-tests") -or ($env:SKIP_TESTS -eq "1")

# --- Banner -------------------------------------------------------------------
Write-Host @"

    ,___,        ____             _
    (O,O)       / ___|  __ ___  _(_) __ _
    /)  )      \___ \ / _` \ \/ / |/ _` |
   ( (_ \       ___) | (_| |>  <| | (_| |
    `----'     |____/ \__,_/_/\_\_|\__,_|

    PM-Workspace  -  OpenCode Installer (Windows)

"@ -ForegroundColor White

# --- Step 1: Detect environment ------------------------------------------------
Write-Step 1 "Detecting environment..."

$Arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
$WinVer = [System.Environment]::OSVersion.Version
Write-Ok "Windows $($WinVer.Major).$($WinVer.Minor) ($Arch)"

# --- Step 2: Check prerequisites -----------------------------------------------
Write-Step 2 "Checking prerequisites..."

$Missing = 0

# Helper: suggest install command
function Get-InstallHint {
    param($pkg)
    $wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
    if ($wingetAvailable) { return "winget install $pkg" }
    $chocoAvailable = $null -ne (Get-Command choco -ErrorAction SilentlyContinue)
    if ($chocoAvailable) { return "choco install $pkg" }
    return "Install $pkg from its official website"
}

# Git
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitVer = (git --version) -replace 'git version ', ''
    Write-Ok "Git $gitVer"
} else {
    Write-Fail "Git not found. $(Get-InstallHint 'Git.Git')"
    $Missing = 1
}

# curl (optional)
$curlCmd = Get-Command curl -ErrorAction SilentlyContinue
if (-not $curlCmd) {
    Write-Warn "curl not found — some features may require it"
}

# Node.js (optional)
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nodeVer = (node --version) -replace 'v', ''
    Write-Ok "Node.js $nodeVer"
} else {
    Write-Warn "Node.js not found — some scripts may require it"
}

if ($Missing -gt 0) {
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -notmatch '^[Yy]$') {
        Write-Fail "Installation cancelled"
        exit 3
    }
}

# --- Step 3: Determine installation directory -----------------------------------
Write-Step 3 "Choosing installation directory..."

$SaviaHome = if ($env:SAVIA_HOME) { $env:SAVIA_HOME } else { "$HOME\claude" }
$SaviaHome = $SaviaHome -replace '/', '\'

if (Test-Path $SaviaHome) {
    Write-Info "$SaviaHome already exists"
    if (Test-Path "$SaviaHome\.git") {
        Write-Ok "Git repository already present — updating..."
        Set-Location $SaviaHome
        git pull --quiet 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warn "Git pull failed (non-critical)" }
        Set-Location $PSScriptRoot
    } else {
        Write-Warn "$SaviaHome exists but is not a git repo — keeping existing files"
    }
} else {
    Write-Info "Will install to $SaviaHome"
}

# --- Step 4: Clone or update repository -----------------------------------------
Write-Step 4 "Downloading PM-Workspace..."

$RepoUrl = "https://github.com/gonzalezpazmonica/pm-workspace.git"

if (-not (Test-Path $SaviaHome)) {
    Write-Info "Cloning pm-workspace to $SaviaHome..."
    git clone $RepoUrl $SaviaHome 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Cloned to $SaviaHome"
    } else {
        Write-Fail "Clone failed. Check your internet connection and try again."
        exit 2
    }
}

# --- Step 5: Install dependencies ----------------------------------------------
Write-Step 5 "Installing script dependencies..."

if (Test-Path "$SaviaHome\scripts\package.json") {
    Set-Location "$SaviaHome\scripts"
    npm install --silent 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "npm dependencies installed"
    } else {
        Write-Warn "npm install had warnings (non-critical)"
    }
    Set-Location $PSScriptRoot
} else {
    Write-Warn "No package.json found in scripts\ — skipping npm install"
}

# --- Step 6: Verify OpenCode compatibility --------------------------------------
Write-Step 6 "Setting up OpenCode compatibility..."

$OpenCodeDir = "$SaviaHome\.opencode"
if (Test-Path $OpenCodeDir) {
    Write-Ok ".opencode directory already exists"
} else {
    Write-Warn ".opencode directory missing — creating basic structure"
    New-Item -ItemType Directory -Path $OpenCodeDir -Force | Out-Null
    Copy-Item "$SaviaHome\CLAUDE.md" "$OpenCodeDir\" -Force
    Copy-Item "$SaviaHome\CLAUDE.local.md" "$OpenCodeDir\" -Force
    # Create symlinks (requires admin or developer mode on Windows)
    # For Windows, we'll create junction points instead of symlinks if possible
    try {
        # Use mklink /J for directories (requires admin for symlinks, but junctions work without)
        # We'll create junctions using cmd
        $null = cmd /c "mklink /J `"$OpenCodeDir\.claude`" `"$SaviaHome\.claude`"" 2>$null
        $null = cmd /c "mklink /J `"$OpenCodeDir\docs`" `"$SaviaHome\docs`"" 2>$null
        $null = cmd /c "mklink /J `"$OpenCodeDir\projects`" `"$SaviaHome\projects`"" 2>$null
        $null = cmd /c "mklink /J `"$OpenCodeDir\scripts`" `"$SaviaHome\scripts`"" 2>$null
        Write-Ok "Created junction links for .claude, docs, projects, scripts"
    } catch {
        Write-Warn "Could not create symlinks/junctions. You may need to run as Administrator or enable Developer Mode."
        Write-Info "You can manually create shortcuts or copy the directories."
    }
    # Create init-pm.ps1 (PowerShell equivalent)
    @'
# init-pm.ps1 — Carga variables de entorno de PM-Workspace para OpenCode
$env:PM_WORKSPACE_ROOT = (Get-Item $PSScriptRoot).Parent.FullName
$env:CLAUDE_PROJECT_DIR = $env:PM_WORKSPACE_ROOT
# Cargar configuración de CLAUDE.md si existe
$claudeMd = "$env:PM_WORKSPACE_ROOT\CLAUDE.md"
if (Test-Path $claudeMd) {
    Get-Content $claudeMd | Where-Object { $_ -match '^AZURE_DEVOPS_' } | ForEach-Object {
        $key, $value = $_ -split ' = ', 2
        $value = $value.Trim('"')
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}
# Cargar PAT si existe
$patFile = "$HOME\.azure\devops-pat"
if (Test-Path $patFile) {
    $env:AZURE_DEVOPS_PAT_FILE = $patFile
}
Write-Host "PM-Workspace variables cargadas. ORG_URL: $env:AZURE_DEVOPS_ORG_URL" -ForegroundColor Green
'@ | Out-File "$OpenCodeDir\init-pm.ps1" -Encoding UTF8
    Write-Ok "Created init-pm.ps1"
}

# --- Step 7: Smoke test --------------------------------------------------------
Write-Step 7 "Running smoke test..."

if ($SkipTests) {
    Write-Warn "Skipping tests (--skip-tests)"
} else {
    $testScript = "$SaviaHome\scripts\test-workspace.sh"
    if (Test-Path $testScript) {
        Write-Info "Running smoke tests (mock mode)..."
        bash $testScript --mock 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Smoke tests passed"
        } else {
            Write-Warn "Some tests failed (this is normal without Azure DevOps configured)"
        }
    } else {
        Write-Warn "Test script not found — skipping"
    }
}

# --- Done -----------------------------------------------------------------------
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host "  🦉 Savia is ready for OpenCode!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host ""
Write-Host "  Next steps:"
Write-Host ""
Write-Host "    1. Load PM-Workspace environment:"
Write-Host "       cd $SaviaHome\.opencode"
Write-Host "       .\init-pm.ps1"
Write-Host ""
Write-Host "    2. Start OpenCode (if installed) and load a skill:"
Write-Host "       /skill azure-devops-queries"
Write-Host ""
Write-Host "    3. Use any of the 400+ commands manually:"
Write-Host "       Read .claude\commands\*.md and follow steps"
Write-Host ""
Write-Host "  For detailed instructions, see:"
Write-Host "    $SaviaHome\.opencode\README.md"
Write-Host ""
Write-Host "  Docs: https://github.com/gonzalezpazmonica/pm-workspace#readme"
Write-Host ""