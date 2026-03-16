# Install OIOS OpenClaw Skills
# Copies custom skills to ~/.openclaw/skills/ for OpenClaw to discover.

$ErrorActionPreference = "Stop"

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetDir = Join-Path $env:USERPROFILE ".openclaw\skills"

$Skills = @(
    "agentic-os-bridge",
    "action-executor",
    "daily-briefing",
    "approval-gate"
)

Write-Host "OIOS OpenClaw Skills Installer"
Write-Host "==============================="
Write-Host ""

# Ensure target directory exists
if (!(Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Host "Created: $TargetDir"
}

foreach ($skill in $Skills) {
    $src = Join-Path $SourceDir $skill
    $dst = Join-Path $TargetDir $skill

    if (!(Test-Path $src)) {
        Write-Host "  SKIP  $skill (source not found)"
        continue
    }

    # Remove existing version
    if (Test-Path $dst) {
        Remove-Item $dst -Recurse -Force
    }

    # Copy skill
    Copy-Item $src $dst -Recurse
    Write-Host "  OK    $skill -> $dst"
}

Write-Host ""
Write-Host "Installed $($Skills.Count) skills to $TargetDir"
Write-Host ""
Write-Host "Restart OpenClaw for changes to take effect."
Write-Host "To uninstall: powershell $(Join-Path $SourceDir 'uninstall.ps1')"
