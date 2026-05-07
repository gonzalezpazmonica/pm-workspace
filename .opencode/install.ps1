# install.ps1 — OpenCode installer wrapper (redirects to main installer)
# Usage: irm https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/.opencode/install.ps1 | iex
#
# DEPRECATED: The main install.ps1 is now OpenCode-first.
# This wrapper exists for backward compatibility with existing docs/links.
# It delegates to the root install.ps1.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootInstaller = Join-Path $ScriptDir "..\install.ps1"

if (Test-Path $RootInstaller) {
    & $RootInstaller @args
} else {
    Write-Host "ERROR: root installer not found at $RootInstaller" -ForegroundColor Red
    Write-Host "Download it from: https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.ps1"
    exit 1
}
