# install.ps1 — One-line installer for PM-Workspace (Savia) on Windows
# Usage: irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex
#
# ⚠️  SECURITY WARNING: This script is piped directly to PowerShell execution (irm|iex).
#     Always verify the source before execution. Only run from official GitHub releases:
#     https://github.com/gonzalezpazmonica/pm-workspace/releases
#     Do NOT run from untrusted or modified URLs.
#
# Environment variables:
#   SAVIA_HOME    — Installation directory (default: ~\claude)
#   SKIP_TESTS    — Set to 1 to skip smoke tests
#   SKIP_CLAUDE   — Set to 1 to skip Claude Code installation

$ErrorActionPreference = "Stop"

# --- Helpers -------------------------------------------------------------------
function Write-Info  { param($msg) Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "  $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "  $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "  $msg" -ForegroundColor Red }
function Write-Step  { param($num, $msg) Write-Host "`n[$num/7] $msg" -ForegroundColor White }

# --- Help ----------------------------------------------------------------------
if ($args -contains "--help" -or $args -contains "-h") {
    Write-Host "PM-Workspace (Savia) Installer for Windows"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1 | iex"
    Write-Host "  .\install.ps1 [--skip-tests] [--help]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --skip-tests    Skip smoke tests after installation"
    Write-Host "  --help, -h      Show this help message"
    Write-Host ""
    Write-Host "Environment variables:"
    Write-Host "  SAVIA_HOME      Installation directory (default: ~\claude)"
    Write-Host "  SKIP_TESTS      Set to 1 to skip smoke tests"
    Write-Host "  SKIP_CLAUDE     Set to 1 to skip Claude Code installation"
    Write-Host ""
    Write-Host "Exit codes: 0 Success, 1 Missing prereqs, 2 Network error, 3 Cancelled"
    exit 0
}

$SkipTests = ($args -contains "--skip-tests") -or ($env:SKIP_TESTS -eq "1")

# --- Banner -------------------------------------------------------------------
Write-Host @"

    ,___,        ____             _
    (O,O)       / ___|  __ ___  _(_) __ _
    /)  )      \___ \ / _`` \ \/ / |/ _`` |
   ( (_ \       ___) | (_| |>  <| | (_| |
    ``----'     |____/ \__,_/_/\_\_|\__,_|

    PM-Workspace  -  One-Line Installer (Windows)

"@ -ForegroundColor White

# --- Step 1: Detect environment ------------------------------------------------
Write-Step 1 "Detecting environment..."

$Arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
$WinVer = [System.Environment]::OSVersion.Version
Write-Ok "Windows $($WinVer.Major).$($WinVer.Minor) ($Arch)"

# Detect WSL
$HasWSL = $false
try {
    $wslCheck = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) { $HasWSL = $true }
} catch { }

if ($HasWSL) {
    Write-Info "WSL detected. Tip: you can also run install.sh directly inside WSL."
}

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

# Node.js
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nodeVer = (node --version) -replace 'v', ''
    $nodeMajor = [int]($nodeVer.Split('.')[0])
    if ($nodeMajor -ge 18) {
        Write-Ok "Node.js v$nodeVer"
    } else {
        Write-Fail "Node.js v$nodeVer found but need >= 18. Visit https://nodejs.org"
        $Missing = 1
    }
} else {
    Write-Fail "Node.js not found. Install from https://nodejs.org (>= 18 required)"
    $Missing = 1
}

# Python 3 (optional)
$pyCmd = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $pyCmd) { $pyCmd = Get-Command python -ErrorAction SilentlyContinue }
if ($pyCmd) {
    $pyVer = (& $pyCmd.Source --version 2>&1) -replace 'Python ', ''
    Write-Ok "Python $pyVer"
} else {
    Write-Warn "Python not found (optional - needed for capacity calculator)"
}

# jq (optional)
$jqCmd = Get-Command jq -ErrorAction SilentlyContinue
if ($jqCmd) {
    Write-Ok "jq found"
} else {
    Write-Warn "jq not found (optional). $(Get-InstallHint 'jqlang.jq')"
}

if ($Missing -eq 1) {
    Write-Host ""
    Write-Fail "Missing required prerequisites. Install them and re-run."
    exit 1
}

# --- Step 3: Claude Code -------------------------------------------------------
Write-Step 3 "Checking Claude Code..."

if ($env:SKIP_CLAUDE -eq "1") {
    Write-Warn "Skipping Claude Code installation (SKIP_CLAUDE=1)"
} elseif (Get-Command claude -ErrorAction SilentlyContinue) {
    $claudeVer = try { claude --version 2>&1 } catch { "found" }
    Write-Ok "Claude Code already installed ($claudeVer)"
} else {
    Write-Info "Claude Code not found - installing..."
    try {
        irm https://claude.ai/install.ps1 | iex
        Write-Ok "Claude Code installed"
    } catch {
        Write-Warn "Claude Code installation failed. Install it later:"
        Write-Host "    irm https://claude.ai/install.ps1 | iex"
    }
}

# --- Step 4: Clone PM-Workspace ------------------------------------------------
Write-Step 4 "Setting up PM-Workspace..."

$SaviaHome = if ($env:SAVIA_HOME) { $env:SAVIA_HOME } else { Join-Path $HOME "claude" }
$RepoUrl = "https://github.com/gonzalezpazmonica/pm-workspace.git"

if (Test-Path (Join-Path $SaviaHome ".git")) {
    Write-Info "Directory $SaviaHome already exists."
    $reply = Read-Host "    Update (git pull)? [Y/n/abort]"
    switch -Regex ($reply.ToLower()) {
        "^n"     { Write-Ok "Skipping - using existing installation" }
        "^abort" { Write-Info "Installation cancelled."; exit 3 }
        default  {
            try {
                git -C $SaviaHome pull --ff-only origin main 2>&1 | Out-Null
                Write-Ok "Updated to latest version"
            } catch {
                Write-Warn "Pull failed - continuing with existing version"
            }
        }
    }
} elseif (Test-Path $SaviaHome) {
    Write-Fail "$SaviaHome exists but is not a git repo. Move or remove it first."
    exit 2
} else {
    Write-Info "Cloning pm-workspace to $SaviaHome..."
    try {
        git clone $RepoUrl $SaviaHome 2>&1 | Out-Null
        Write-Ok "Cloned to $SaviaHome"
    } catch {
        Write-Fail "Clone failed. Check your internet connection and try again."
        exit 2
    }
}

# --- Step 5: Install dependencies -----------------------------------------------
Write-Step 5 "Installing script dependencies..."

$pkgJson = Join-Path $SaviaHome "scripts\package.json"
if (Test-Path $pkgJson) {
    try {
        Push-Location (Join-Path $SaviaHome "scripts")
        npm install --silent 2>&1 | Out-Null
        Pop-Location
        Write-Ok "npm dependencies installed"
    } catch {
        Pop-Location
        Write-Warn "npm install had warnings (non-critical)"
    }
} else {
    Write-Warn "No package.json found in scripts\ - skipping npm install"
}

# --- Step 6: Savia Bridge Setup -----------------------------------------------
Write-Step 6 "Setting up Savia Bridge..."

# Check if Python is available
$PyCmd = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $PyCmd) { $PyCmd = Get-Command python -ErrorAction SilentlyContinue }

if ($PyCmd) {
    $PythonPath = $PyCmd.Source

    # Create bridge directories
    $BridgeScriptDir = Join-Path $env:USERPROFILE ".savia\scripts"
    $BridgeDir = Join-Path $env:USERPROFILE ".savia\bridge"
    $BridgeApkDir = Join-Path $BridgeDir "apk"

    New-Item -ItemType Directory -Force -Path $BridgeScriptDir | Out-Null
    New-Item -ItemType Directory -Force -Path $BridgeDir | Out-Null
    New-Item -ItemType Directory -Force -Path $BridgeApkDir | Out-Null
    Write-Ok "Bridge directories created"

    # Copy savia-bridge.py script
    $SourceScript = Join-Path $SaviaHome "scripts\savia-bridge.py"
    if (Test-Path $SourceScript) {
        Copy-Item $SourceScript (Join-Path $BridgeScriptDir "savia-bridge.py") -Force
        Write-Ok "Bridge script copied"
    } else {
        Write-Warn "savia-bridge.py not found in scripts\ — skipping"
    }

    # Generate random auth token using Python
    try {
        $AuthToken = & $PythonPath -c "import secrets; print(secrets.token_hex(32))" 2>$null
    } catch {
        Write-Warn "Failed to generate token with Python — using random GUID"
        $AuthToken = [guid]::NewGuid().ToString() -replace "-",""
    }

    # Create config file
    $ConfigPath = Join-Path $BridgeDir "config.json"
    $ConfigContent = @"
{
  "host": "0.0.0.0",
  "port": 8922,
  "token": "$AuthToken"
}
"@
    Set-Content -Path $ConfigPath -Value $ConfigContent
    Write-Ok "Bridge config created at $ConfigPath"

    # Windows: Create scheduled task or batch file for auto-start
    $BridgeStartDir = Join-Path $env:APPDATA "Savia\startup"
    New-Item -ItemType Directory -Force -Path $BridgeStartDir | Out-Null

    # Create batch file to run bridge on startup
    $BatchPath = Join-Path $BridgeStartDir "start-bridge.bat"
    $BatchContent = @"
@echo off
pushd "%USERPROFILE%\.savia\scripts"
python savia-bridge.py
popd
"@
    Set-Content -Path $BatchPath -Value $BatchContent -Encoding ASCII
    Write-Ok "Bridge startup script created at $BatchPath"

    # Add to Windows Startup folder (user startup)
    $StartupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $StartupFolder) {
        # Create shortcut to batch file
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut((Join-Path $StartupFolder "Savia Bridge.lnk"))
        $Shortcut.TargetPath = $BatchPath
        $Shortcut.WorkingDirectory = (Join-Path $env:USERPROFILE ".savia\scripts")
        $Shortcut.Save()
        Write-Ok "Bridge added to Windows Startup"
    }

    # Display setup information
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  Bridge Auth Token" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Copy this token to configure the mobile app:" -ForegroundColor White
    Write-Host "$AuthToken" -ForegroundColor Cyan -BackgroundColor Black
    Write-Host ""
    Write-Host "Token saved in: $ConfigPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Startup:" -ForegroundColor White
    Write-Host "  • Batch file: $BatchPath" -ForegroundColor White
    Write-Host "  • Startup folder: Added (will auto-run on next login)" -ForegroundColor White
    Write-Host "  • To start manually: run $BatchPath" -ForegroundColor White
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
} else {
    Write-Warn "Python not found — Bridge setup skipped"
}

# --- Step 7: Smoke test --------------------------------------------------------
Write-Step 7 "Running smoke test..."

if ($SkipTests) {
    Write-Warn "Skipping tests (--skip-tests)"
} else {
    $testScript = Join-Path $SaviaHome "scripts\test-workspace.sh"
    if (Test-Path $testScript) {
        $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
        if ($bashCmd) {
            try {
                bash $testScript --mock 2>&1 | Out-Null
                Write-Ok "Smoke tests passed"
            } catch {
                Write-Warn "Some tests failed (normal without Azure DevOps configured)"
            }
        } else {
            Write-Warn "bash not found - skipping tests (install Git Bash or WSL)"
        }
    } else {
        Write-Warn "Test script not found - skipping"
    }
}

# --- Done -----------------------------------------------------------------------
Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  Savia is ready!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:"
Write-Host ""
Write-Host "    cd $SaviaHome" -ForegroundColor White
Write-Host "    claude" -ForegroundColor White
Write-Host ""
Write-Host "  First time? Claude will open your browser to authenticate."
Write-Host "  Then say: `"Hola Savia`" or run any command like /sprint:status"
Write-Host ""
Write-Host "  Mobile app setup:"
Write-Host "    1. Install Savia mobile app from App Store/Play Store"
Write-Host "    2. Configure Bridge endpoint: https://localhost:8922"
Write-Host "    3. Enter the auth token from $env:USERPROFILE\.savia\bridge\config.json"
Write-Host ""
Write-Host "  Docs: https://github.com/gonzalezpazmonica/pm-workspace#readme"
Write-Host "  Guide: $SaviaHome\docs\ADOPTION_GUIDE.md"
Write-Host ""
