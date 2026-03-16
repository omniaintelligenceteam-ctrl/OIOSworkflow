# Uninstall OIOS OpenClaw Skills
# Removes custom skills from ~/.openclaw/skills/

$ErrorActionPreference = "Stop"

$TargetDir = Join-Path $env:USERPROFILE ".openclaw\skills"

$Skills = @(
    "agentic-os-bridge",
    "action-executor",
    "daily-briefing",
    "approval-gate"
)

Write-Host "OIOS OpenClaw Skills Uninstaller"
Write-Host "================================="
Write-Host ""

foreach ($skill in $Skills) {
    $dst = Join-Path $TargetDir $skill
    if (Test-Path $dst) {
        Remove-Item $dst -Recurse -Force
        Write-Host "  REMOVED  $skill"
    } else {
        Write-Host "  SKIP     $skill (not found)"
    }
}

Write-Host ""
Write-Host "Uninstalled OIOS skills."
Write-Host "Restart OpenClaw for changes to take effect."
